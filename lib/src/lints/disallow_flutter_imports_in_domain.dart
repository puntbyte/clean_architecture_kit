import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'package:clean_architecture_kit/src/config/models/architecture_kit_config.dart';
import 'package:clean_architecture_kit/src/utils/layer_resolver.dart';

/// A lint rule that flags any direct import of a Flutter package
/// inside a file belonging to the domain layer.
class DisallowFlutterImportsInDomain extends DartLintRule {
  static const _code = LintCode(
    name: 'disallow_flutter_imports_in_domain',
    problemMessage: 'Do not import Flutter packages in the domain layer.',
    correctionMessage: 'The domain layer must be platform-independent. Remove this import.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  final CleanArchitectureConfig config;
  final LayerResolver layerResolver;

  DisallowFlutterImportsInDomain({required this.config, required this.layerResolver})
    : super(code: _code);

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    // Determine the layer of the current file.
    final layer = layerResolver.getLayer(resolver.source.fullName);
    // Only run this lint on files within the domain layer.
    if (layer != ArchLayer.domain) return;

    // Register a visitor to inspect every import directive in the file.
    context.registry.addImportDirective((node) {
      final importUri = node.uri.stringValue;
      if (importUri != null && importUri.startsWith('package:flutter/')) {
        // If the import URI starts with 'package:flutter/', report an error.
        reporter.atNode(node, _code);
      }
    });
  }
}
