import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
// This is a deliberate import of an internal API from the analyzer package.
// NodeLocator2 is essential for finding the AST node from a diagnostic's location
// and is not part of the public API. This is a common and accepted practice for
// advanced static analysis tools.
// ignore: implementation_imports
import 'package:analyzer/src/dart/ast/utilities.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:code_builder/code_builder.dart' as cb;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_style/dart_style.dart';

import 'package:clean_architecture_kit/src/config/models/architecture_kit_config.dart';
import 'package:clean_architecture_kit/src/utils/naming_utils.dart';
import 'package:clean_architecture_kit/src/utils/path_utils.dart';
import 'package:clean_architecture_kit/src/utils/string_utils.dart';
import 'package:clean_architecture_kit/src/utils/syntax_builder.dart';

/// A "quick fix" that generates a new use case file based on a method
/// signature from a repository interface.
///
/// This fix is associated with the `missing_use_case` lint rule.
class CreateUseCaseFix extends Fix {
  final CleanArchitectureConfig config;
  CreateUseCaseFix({required this.config});

  @override
  List<String> get filesToAnalyze => const ['**.dart'];

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    Diagnostic diagnostic,
    List<Diagnostic> others,
  ) {
    context.addPostRunCallback(() async {
      final resolvedUnit = await resolver.getResolvedUnitResult();
      final locator = NodeLocator2(diagnostic.problemMessage.offset);
      final node = locator.searchWithin(resolvedUnit.unit);
      final methodNode = node?.thisOrAncestorOfType<MethodDeclaration>();
      if (methodNode == null) return;
      final repoNode = methodNode.thisOrAncestorOfType<ClassDeclaration>();
      if (repoNode == null) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Create use case for `${methodNode.name.lexeme}`',
        priority: 90,
      );

      final useCaseFilePath = getUseCaseFilePath(
        methodName: methodNode.name.lexeme,
        repoPath: diagnostic.problemMessage.filePath,
        config: config,
      );
      if (useCaseFilePath == null) return;

      changeBuilder.addDartFileEdit(customPath: useCaseFilePath, (builder) {
        _addImports(builder: builder, method: methodNode, repoNode: repoNode);
        final library = _buildUseCaseLibrary(method: methodNode, repoNode: repoNode);
        final emitter = cb.DartEmitter(useNullSafetySyntax: true);
        final unformattedCode = library.accept(emitter).toString();
        final formattedCode = DartFormatter(
          languageVersion: DartFormatter.latestLanguageVersion,
        ).format(unformattedCode);
        builder.addInsertion(0, (editBuilder) => editBuilder.write(formattedCode));
      });
    });
  }

  void _addImports({
    required DartFileEditBuilder builder,
    required MethodDeclaration method,
    required ClassDeclaration repoNode,
  }) {
    final repoLibrary = repoNode.declaredFragment?.element.library;
    if (repoLibrary != null) builder.importLibrary(repoLibrary.firstFragment.source.uri);

    for (var annotation in config.generation.useCaseAnnotations) {
      if (annotation.importPath.isNotEmpty) builder.importLibrary(Uri.parse(annotation.importPath));
    }

    final unaryPath = config.inheritance.unaryUseCasePath;
    if (unaryPath.isNotEmpty) builder.importLibrary(Uri.parse(unaryPath));
    final nullaryPath = config.inheritance.nullaryUseCasePath;
    if (nullaryPath.isNotEmpty && nullaryPath != unaryPath) {
      builder.importLibrary(Uri.parse(nullaryPath));
    }
    for (var path in config.typeSafety.importPaths) {
      if (path.isNotEmpty) builder.importLibrary(Uri.parse(path));
    }

    for (final param in method.parameters?.parameters ?? []) {
      _importType(param.declaredFragment?.element?.type, builder);
    }

    final returnType = method.returnType?.type;
    if (returnType is InterfaceType && returnType.typeArguments.isNotEmpty) {
      for (final arg in returnType.typeArguments) {
        _importType(arg, builder);
      }
    }
  }

  void _importType(DartType? type, DartFileEditBuilder builder) {
    if (type == null) return;

    // --- THIS IS THE DEFINITIVE FIX ---
    // If the type is generic, we only care about importing its arguments,
    // not the container type itself (like `Future` or `Either`).
    if (type is InterfaceType && type.typeArguments.isNotEmpty) {
      for (final arg in type.typeArguments) {
        // Recurse on the inner types.
        _importType(arg, builder);
      }
    } else {
      // This is a non-generic type. We can safely import it.
      final library = type.element?.library;
      if (library != null && !library.isInSdk) {
        builder.importLibrary(library.firstFragment.source.uri);
      }
    }
    // --- END OF FIX ---
  }

  cb.Library _buildUseCaseLibrary({
    required MethodDeclaration method,
    required ClassDeclaration repoNode,
  }) {
    final elements = <cb.Spec>[];
    final methodName = method.name.lexeme;
    final params = method.parameters?.parameters ?? [];
    final returnType = cb.refer(method.returnType?.toSource() ?? 'void');
    final outputType = cb.refer(_extractOutputType(returnType.symbol!));

    String baseClassName;
    final List<cb.Reference> genericTypes = [outputType];
    final List<cb.Parameter> callParams = [];
    final Map<String, cb.Expression> repoCallArgs = {};
    final List<cb.Expression> repoCallPositionalArgs = [];

    if (params.isEmpty) {
      baseClassName = config.inheritance.nullaryUseCaseName;
    } else {
      baseClassName = config.inheritance.unaryUseCaseName;
      if (params.length == 1) {
        final param = params.first;
        final paramType = cb.refer(param.type?.toSource() ?? 'dynamic');
        final paramName = param.name?.lexeme ?? 'param';
        genericTypes.add(paramType);
        callParams.add(SyntaxBuilder.parameter(name: paramName, type: paramType));
        if (param.isNamed) {
          repoCallArgs[paramName] = cb.refer(paramName);
        } else {
          repoCallPositionalArgs.add(cb.refer(paramName));
        }
      } else {
        final useCaseNamePascal = toPascalCase(methodName);
        final recordName = config.naming.useCaseRecordParameter.replaceAll(
          '{{name}}',
          useCaseNamePascal,
        );
        final recordRef = cb.refer(recordName);
        genericTypes.add(recordRef);
        callParams.add(SyntaxBuilder.parameter(name: 'params', type: recordRef));

        final recordType = cb.RecordType((b) {
          for (final p in params) {
            final element = p.declaredFragment?.element;
            if (element == null) continue;
            b.namedFieldTypes[element.name] = cb.refer(
              element.type.getDisplayString(withNullability: true),
            );
            repoCallArgs[element.name] = cb.refer('params').property(element.name);
          }
        });
        elements.add(
          cb.TypeDef(
            (b) => b
              ..name = recordName
              ..definition = recordType,
          ),
        );
      }
    }

    final implementsType = cb.TypeReference(
      (b) => b
        ..symbol = baseClassName
        ..types.addAll(genericTypes),
    );

    final annotations = config.generation.useCaseAnnotations
        .where((a) => a.annotationText.isNotEmpty)
        .map((a) => cb.CodeExpression(cb.Code(a.annotationText)))
        .toList();

    final useCaseName = getExpectedUseCaseClassName(methodName, config);
    final useCaseClass = SyntaxBuilder.class$(
      name: useCaseName,
      isFinal: true,
      implements: [implementsType],
      annotations: annotations,
      fields: [
        SyntaxBuilder.field(
          name: 'repository',
          modifier: cb.FieldModifier.final$,
          type: cb.refer(repoNode.name.lexeme),
          annotations: [cb.refer('override')],
        ),
      ],
      constructors: [
        SyntaxBuilder.constructor(
          constant: true,
          requiredParameters: [SyntaxBuilder.parameter(name: 'repository', toThis: true)],
        ),
      ],
      methods: [
        SyntaxBuilder.method(
          name: 'call',
          isLambda: true,
          returns: returnType,
          requiredParameters: callParams,
          annotations: [cb.refer('override')],
          body: cb
              .refer('repository')
              .property(methodName)
              .call(repoCallPositionalArgs, repoCallArgs)
              .code,
        ),
      ],
    );

    elements.add(useCaseClass);
    return SyntaxBuilder.library(elements: elements);
  }

  String _extractOutputType(String returnTypeSource) {
    final regex = RegExp(r'<.*,\s*([^>]+)>|<([^>]+)>');
    final match = regex.firstMatch(returnTypeSource);
    if (match != null) return match.group(2)?.trim() ?? match.group(1)?.trim() ?? 'void';
    return 'void';
  }
}
