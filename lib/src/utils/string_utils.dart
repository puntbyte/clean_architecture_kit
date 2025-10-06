/// Converts a string from camelCase or snake_case to PascalCase.
String toPascalCase(String input) {
  if (input.isEmpty) return '';
  return input[0].toUpperCase() + input.substring(1);
}

/// Converts a string from PascalCase or camelCase to snake_case.
String toSnakeCase(String input) {
  return input
      .replaceAllMapped(RegExp(r'(?<!^)(?=[A-Z])'), (match) => '_${match.group(0)}')
      .toLowerCase();
}
