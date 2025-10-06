import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../config/models/architecture_kit_config.dart';
import '../utils/layer_resolver.dart';

class EnforceFileAndFolderLocation extends DartLintRule {
  static const _code = LintCode(
    name: 'enforce_file_and_folder_location',
    problemMessage: 'A {0} should be located in one of the following directories: {1}.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  final CleanArchitectureConfig config;
  final LayerResolver layerResolver;

  EnforceFileAndFolderLocation({required this.config, required this.layerResolver})
    : super(code: _code);

  @override
  void run(CustomLintResolver resolver, DiagnosticReporter reporter, CustomLintContext context) {
    final path = resolver.source.fullName;
    final pathSegments = path.replaceAll('\\', '/').split('/');

    context.registry.addClassDeclaration((node) {
      final className = node.name.lexeme;
      final layerConfig = config.layers;

      List<String>? expectedDirs;
      String? classType;

      if (_matches(className, config.naming.repositoryInterface)) {
        expectedDirs = layerConfig.domainRepositoriesPaths;
        classType = 'Repository Interface';
      } else if (_matches(className, config.naming.useCase)) {
        expectedDirs = layerConfig.domainUseCasesPaths;
        classType = 'UseCase';
      } // Add more checks...

      if (classType != null && expectedDirs != null && expectedDirs.isNotEmpty) {
        if (!expectedDirs.any(pathSegments.contains)) {
          reporter.atToken(node.name, _code, arguments: [classType, expectedDirs.join(', ')]);
        }
      }
    });
  }

  bool _matches(String name, String template) {
    final pattern = template.replaceAll('{{name}}', '([A-Z][a-zA-Z0-9]+)');
    return RegExp('^$pattern\$').hasMatch(name);
  }
}
