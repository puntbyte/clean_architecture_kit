import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:clean_architecture_kit/src/config/models/architecture_kit_config.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'package:clean_architecture_kit/src/utils/layer_resolver.dart';
import 'package:clean_architecture_kit/src/utils/naming_utils.dart';

/// A lint rule to enforce that the Domain layer remains pure and independent.
///
/// It checks for several types of violations:
/// - Importing Flutter packages.
/// - Importing from the Data or Presentation layers.
/// - Using data Models in method/function signatures.
class DomainLayerPurity extends DartLintRule {
  static const _code = LintCode(
    name: 'domain_layer_purity',
    problemMessage: 'Domain layer purity violation.', // Generic message for the rule code.
    correctionMessage:
        'The Domain layer must be pure and not depend on outer layers or implementation details.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  final CleanArchitectureConfig config;
  final LayerResolver layerResolver;

  DomainLayerPurity({required this.config, required this.layerResolver}) : super(code: _code);

  @override
  void run(CustomLintResolver resolver, DiagnosticReporter reporter, CustomLintContext context) {
    // Only run this lint on files within the domain layer.
    final layer = layerResolver.getLayer(resolver.source.fullName);
    if (layer != ArchLayer.domain) return;

    // --- Check 1: Validate all import statements ---
    context.registry.addImportDirective((node) {
      final importUri = node.uri.stringValue;
      if (importUri == null) return;

      if (importUri.startsWith('package:flutter/')) {
        reporter.reportError(
          Diagnostic.forValues(
            source: resolver.source,
            offset: node.offset,
            length: node.length,
            diagnosticCode: _code,
            message: 'Domain layer cannot import Flutter packages.',
          ),
        );
        return;
      }

      final importPath = node.libraryImport?.importedLibrary?.firstFragment.source.fullName;
      if (importPath == null) return;
      final importedLayer = layerResolver.getLayer(importPath);

      if (importedLayer == ArchLayer.data || importedLayer == ArchLayer.presentation) {
        reporter.reportError(
          Diagnostic.forValues(
            source: resolver.source,
            offset: node.offset,
            length: node.length,
            diagnosticCode: _code,
            message: 'Domain layer cannot import from the ${importedLayer.name} layer.',
          ),
        );
      }
    });

    // --- Check 2: Validate types in method and function signatures ---
    context.registry.addMethodDeclaration((node) {
      _checkTypeRecursively(node.returnType, resolver, reporter);
      node.parameters?.parameters.forEach(
        (param) => _checkTypeRecursively(_getParameterTypeNode(param), resolver, reporter),
      );
    });

    context.registry.addFunctionDeclaration((node) {
      _checkTypeRecursively(node.returnType, resolver, reporter);
      node.functionExpression.parameters?.parameters.forEach(
        (param) => _checkTypeRecursively(_getParameterTypeNode(param), resolver, reporter),
      );
    });
  }

  /// A robust, recursive helper that traverses a type annotation to find Models.
  void _checkTypeRecursively(
    TypeAnnotation? typeNode,
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
  ) {
    if (typeNode == null) return;

    // Case 1: The type is a simple named type (e.g., `UserModel` or `FutureEither`).
    if (typeNode is NamedType) {
      final typeName = typeNode.name.lexeme;

      // Check if this specific name matches the model convention.
      if (validateName(name: typeName, template: config.naming.model)) {
        reporter.reportError(
          Diagnostic.forValues(
            source: resolver.source,
            offset: typeNode.offset,
            length: typeNode.length,
            diagnosticCode: _code,
            message:
                'Do not use Model `$typeName` in a domain layer signature. Use a pure Entity instead.',
          ),
        );
      }

      // After checking the main type, recurse on its generic arguments.
      typeNode.typeArguments?.arguments.forEach((arg) {
        _checkTypeRecursively(arg, resolver, reporter);
      });
    }
    // Case 2: Handle generic function types.
    else if (typeNode is GenericFunctionType) {
      _checkTypeRecursively(typeNode.returnType, resolver, reporter);
      for (var param in typeNode.parameters.parameters) {
        _checkTypeRecursively(_getParameterTypeNode(param), resolver, reporter);
      }
    }
  }

  /// A robust helper to get the `TypeAnnotation` AST node from any kind of `FormalParameter`.
  TypeAnnotation? _getParameterTypeNode(FormalParameter parameter) {
    if (parameter is SimpleFormalParameter) return parameter.type;
    if (parameter is FieldFormalParameter) return parameter.type;
    if (parameter is SuperFormalParameter) return parameter.type;
    if (parameter is DefaultFormalParameter) {
      return _getParameterTypeNode(parameter.parameter);
    }
    return null;
  }
}
