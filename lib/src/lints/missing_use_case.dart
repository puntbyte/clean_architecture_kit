import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'package:clean_architecture_kit/src/config/models/architecture_kit_config.dart';
import 'package:clean_architecture_kit/src/fixes/create_use_case_fix.dart';
import 'package:clean_architecture_kit/src/utils/layer_resolver.dart';
// Import the shared, robust utilities
import 'package:clean_architecture_kit/src/utils/path_utils.dart';

class MissingUseCase extends DartLintRule {
  static const _code = LintCode(
    name: 'missing_use_case',
    problemMessage: 'Repository method `{0}` is missing a corresponding UseCase file.',
    correctionMessage: 'Consider creating a UseCase for this business logic.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  final CleanArchitectureConfig config;
  final LayerResolver layerResolver;

  MissingUseCase({required this.config, required this.layerResolver}) : super(code: _code);

  @override
  List<Fix> getFixes() => [CreateUseCaseFix(config: config)];

  @override
  void run(CustomLintResolver resolver, DiagnosticReporter reporter, CustomLintContext context) {
    final subLayer = layerResolver.getSubLayer(resolver.source.fullName);
    if (subLayer != ArchSubLayer.domainRepository) return;

    context.registry.addClassDeclaration((node) {
      if (node.abstractKeyword == null) return;

      for (final member in node.members) {
        if (member is MethodDeclaration && !member.isGetter && !member.isSetter) {
          final methodName = member.name.lexeme;
          if (methodName.isEmpty) continue;

          final expectedFilePath = getUseCaseFilePath(
            methodName: methodName,
            repoPath: resolver.source.fullName,
            config: config,
          );

          if (expectedFilePath != null) {
            final file = File(expectedFilePath);
            if (!file.existsSync()) {
              reporter.atToken(member.name, _code, arguments: [methodName]);
            }
          }
        }
      }
    });
  }
}
