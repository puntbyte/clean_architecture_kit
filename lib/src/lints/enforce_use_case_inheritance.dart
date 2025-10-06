import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../config/models/architecture_kit_config.dart';
import '../utils/layer_resolver.dart';

class EnforceUseCaseInheritance extends DartLintRule {
  static const _code = LintCode(
    name: 'enforce_use_case_inheritance',
    problemMessage: 'UseCases must extend or implement one of the configured base classes: {0}.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  final CleanArchitectureConfig config;
  final LayerResolver layerResolver;

  EnforceUseCaseInheritance({required this.config, required this.layerResolver})
    : super(code: _code);

  @override
  void run(CustomLintResolver resolver, DiagnosticReporter reporter, CustomLintContext context) {
    final subLayer = layerResolver.getSubLayer(resolver.source.fullName);
    if (subLayer != ArchSubLayer.useCase) return;

    final inheritanceConfig = config.inheritance;
    final validBaseNames = {
      inheritanceConfig.unaryUseCaseName,
      inheritanceConfig.nullaryUseCaseName,
    }..removeWhere((name) => name.isEmpty);

    if (validBaseNames.isEmpty) return;

    context.registry.addClassDeclaration((node) {
      if (node.abstractKeyword != null) return;

      bool hasCorrectSuperclass = false;

      final extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final superclassName = extendsClause.superclass.name.lexeme;
        if (validBaseNames.contains(superclassName)) {
          hasCorrectSuperclass = true;
        }
      }

      if (!hasCorrectSuperclass) {
        final implementsClause = node.implementsClause;
        if (implementsClause != null) {
          for (final interface in implementsClause.interfaces) {
            final interfaceName = interface.name.lexeme;
            if (validBaseNames.contains(interfaceName)) {
              hasCorrectSuperclass = true;
              break;
            }
          }
        }
      }

      if (!hasCorrectSuperclass) {
        reporter.atToken(node.name, _code, arguments: [validBaseNames.join(', ')]);
      }
    });
  }
}
