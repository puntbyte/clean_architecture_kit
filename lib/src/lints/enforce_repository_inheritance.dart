import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../config/models/architecture_kit_config.dart';
import '../utils/layer_resolver.dart';

class EnforceRepositoryInheritance extends DartLintRule {
  static const _code = LintCode(
    name: 'enforce_repository_inheritance',
    problemMessage:
        'Repository interfaces must extend or implement the base repository class `{0}`.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  final CleanArchitectureConfig config;
  final LayerResolver layerResolver;

  EnforceRepositoryInheritance({required this.config, required this.layerResolver})
    : super(code: _code);

  @override
  void run(CustomLintResolver resolver, DiagnosticReporter reporter, CustomLintContext context) {
    final subLayer = layerResolver.getSubLayer(resolver.source.fullName);
    if (subLayer != ArchSubLayer.domainRepository) return;

    context.registry.addClassDeclaration((node) {
      // This rule should only apply to abstract classes (interfaces)
      if (node.abstractKeyword == null) return;

      final baseClassName = config.inheritance.repositoryBaseName;
      if (baseClassName.isEmpty) return;

      bool hasCorrectSuperclass = false;

      // Check the 'extends' clause
      final extendsClause = node.extendsClause;
      if (extendsClause != null && extendsClause.superclass.name.lexeme == baseClassName) {
        hasCorrectSuperclass = true;
      }

      // If not found, check the 'implements' clause
      if (!hasCorrectSuperclass) {
        final implementsClause = node.implementsClause;
        if (implementsClause != null) {
          for (final interface in implementsClause.interfaces) {
            if (interface.name.lexeme == baseClassName) {
              hasCorrectSuperclass = true;
              break;
            }
          }
        }
      }

      if (!hasCorrectSuperclass) {
        reporter.atToken(node.name, _code, arguments: [baseClassName]);
      }
    });
  }
}
