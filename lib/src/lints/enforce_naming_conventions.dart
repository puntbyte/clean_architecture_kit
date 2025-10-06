import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../config/models/architecture_kit_config.dart';
import '../utils/layer_resolver.dart';
import '../utils/naming_utils.dart';

class EnforceNamingConventions extends DartLintRule {
  static const _code = LintCode(
    name: 'enforce_naming_conventions',
    problemMessage: 'The class name `{0}` does not match the configured format: `{1}`.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  final CleanArchitectureConfig config;
  final LayerResolver layerResolver;

  EnforceNamingConventions({required this.config, required this.layerResolver})
    : super(code: _code);

  @override
  void run(CustomLintResolver resolver, DiagnosticReporter reporter, CustomLintContext context) {
    final subLayer = layerResolver.getSubLayer(resolver.source.fullName);
    if (subLayer == ArchSubLayer.unknown) return;

    context.registry.addClassDeclaration((node) {
      final isAbstract = node.abstractKeyword != null;
      final template = _getTemplate(subLayer, isAbstract);
      if (template == null || template.isEmpty) return;

      final className = node.name.lexeme;
      if (!validateName(name: className, template: template)) {
        reporter.atToken(node.name, _code, arguments: [className, template]);
      }
    });
  }

  /// Selects the correct naming convention template based on the file's sub-layer
  /// and whether the class itself is abstract or concrete.
  String? _getTemplate(ArchSubLayer subLayer, bool isAbstract) {
    switch (subLayer) {
      case ArchSubLayer.domainRepository:
        return isAbstract ? config.naming.repositoryInterface : null;
      case ArchSubLayer.dataRepository:
        return isAbstract ? null : config.naming.repositoryImplementation;
      case ArchSubLayer.dataSource:
        return isAbstract
            ? config.naming.dataSourceInterface
            : config.naming.dataSourceImplementation;
      case ArchSubLayer.useCase:
        return isAbstract ? null : config.naming.useCase;
      default:
        return null;
    }
  }
}
