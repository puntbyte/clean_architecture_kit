import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../config/models/architecture_kit_config.dart';
import '../utils/layer_resolver.dart';

class EnforceCustomReturnType extends DartLintRule {
  static const _code = LintCode(
    name: 'enforce_custom_return_type',
    problemMessage: 'Methods in this layer must return one of the configured types: {0}.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  final CleanArchitectureConfig config;
  final LayerResolver layerResolver;

  EnforceCustomReturnType({required this.config, required this.layerResolver}) : super(code: _code);

  @override
  void run(CustomLintResolver resolver, DiagnosticReporter reporter, CustomLintContext context) {
    final subLayer = layerResolver.getSubLayer(resolver.source.fullName);
    final typeConfig = config.typeSafety;
    if (typeConfig.returnTypeNames.isEmpty) return;

    bool shouldCheck =
        (typeConfig.applyTo.contains('usecases') && subLayer == ArchSubLayer.useCase) ||
        (typeConfig.applyTo.contains('repository_interface') &&
            subLayer == ArchSubLayer.domainRepository);

    if (!shouldCheck) return;

    context.registry.addMethodDeclaration((node) {
      if (node.isGetter || node.isSetter || node.isOperator) return;
      if (node.returnType == null) return;

      final returnTypeName = node.returnType!.toSource().split('<').first;
      if (!typeConfig.returnTypeNames.contains(returnTypeName)) {
        reporter.atNode(
          node.returnType!,
          _code,
          arguments: [typeConfig.returnTypeNames.join(', ')],
        );
      }
    });
  }
}
