import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
// Deliberate import of internal AST locator utility used by many analyzer plugins.
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

      markUseCaseAsCreated(useCaseFilePath);
    });
  }

  void _addImports({
    required DartFileEditBuilder builder,
    required MethodDeclaration method,
    required ClassDeclaration repoNode,
  }) {
    final repoLibrary = repoNode.declaredFragment?.element.library2;
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
      // This logic, inspired by your snippet, is key. It gets the *actual* parameter
      // element, whether it's wrapped in a `DefaultFormalParameter` or not.
      final element = param.declaredElement;
      _importType(element?.type, builder);
    }

    final returnType = method.returnType?.type;
    _importType(returnType, builder);
  }

  // This is the corrected, robust import logic.
  void _importType(DartType? type, DartFileEditBuilder builder) {
    if (type == null) return;

    if (type is RecordType) {
      for (final field in type.positionalFields) {
        _importType(field.type, builder);
      }
      for (final field in type.namedFields) {
        _importType(field.type, builder);
      }
    } else if (type is InterfaceType && type.typeArguments.isNotEmpty) {
      for (final arg in type.typeArguments) {
        _importType(arg, builder);
      }
    }

    final library = type.element3?.library2;
    if (library != null && !library.isInSdk) {
      builder.importLibrary(library.library2.uri);
    }
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
        final element = param.declaredElement!;
        final paramType = cb.refer(element.type.getDisplayString(withNullability: true));
        final paramName = element.name;
        genericTypes.add(paramType);
        callParams.add(SyntaxBuilder.parameter(name: paramName, type: paramType));
        if (element.isNamed) {
          repoCallArgs[paramName] = cb.refer(paramName);
        } else {
          repoCallPositionalArgs.add(cb.refer(paramName));
        }
      } else {
        // THIS IS THE FINAL, CORRECTED LOGIC FOR MULTIPLE PARAMETERS
        final useCaseNamePascal = toPascalCase(methodName);
        final recordName = config.naming.useCaseRecordParameter.replaceAll(
          '{{name}}',
          useCaseNamePascal,
        );
        final recordRef = cb.refer(recordName);
        genericTypes.add(recordRef);
        callParams.add(SyntaxBuilder.parameter(name: 'params', type: recordRef));

        final recordTypeBuilder = cb.RecordTypeBuilder();
        int positionalIndex = 1;

        for (final p in params) {
          // Using `declaredElement` is the reliable way to get parameter info.
          final element = p.declaredElement;
          if (element == null) continue;

          final paramTypeRef = cb.refer(element.type.getDisplayString(withNullability: true));

          // Correctly distinguish between named and positional parameters
          if (element.isNamed) {
            recordTypeBuilder.namedFieldTypes[element.name] = paramTypeRef;
            repoCallArgs[element.name] = cb.refer('params').property(element.name);
          } else {
            recordTypeBuilder.positionalFieldTypes.add(paramTypeRef);
            repoCallPositionalArgs.add(cb.refer('params').property('\$${positionalIndex++}'));
          }
        }

        elements.add(
          cb.TypeDef(
                (b) => b
              ..name = recordName
              ..definition = recordTypeBuilder.build(),
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