import 'package:clean_architecture_kit/src/utils/string_utils.dart';

import '../config/models/architecture_kit_config.dart';

/// Converts a method name into an expected use case class name based on config.
String getExpectedUseCaseClassName(String methodName, CleanArchitectureConfig config) {
  final pascal = toPascalCase(methodName);
  final template = config.naming.useCase;
  return template.replaceAll('{{name}}', pascal);
}

/// Validates a class name against a configured template or regex.
bool validateName({required String name, required String template}) {
  final pattern = template
      .replaceAll('{{name}}', r'([A-Z][a-zA-Z0-9]+)')
      .replaceAllMapped(RegExp(r'\((.*?)\)'), (match) => '(?:${match.group(1)})');
  final regex = RegExp('^$pattern\$');
  return regex.hasMatch(name);
}
