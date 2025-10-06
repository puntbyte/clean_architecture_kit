class InheritanceConfig {
  final String repositoryBasePath;
  final String repositoryBaseName;
  final String unaryUseCasePath;
  final String unaryUseCaseName;
  final String nullaryUseCasePath;
  final String nullaryUseCaseName;

  const InheritanceConfig({
    required this.repositoryBasePath,
    required this.repositoryBaseName,
    required this.unaryUseCasePath,
    required this.unaryUseCaseName,
    required this.nullaryUseCasePath,
    required this.nullaryUseCaseName,
  });

  factory InheritanceConfig.fromMap(Map<String, dynamic> map) {
    return InheritanceConfig(
      repositoryBasePath: map['repository_base_path'] as String? ?? '',
      repositoryBaseName: map['repository_base_name'] as String? ?? 'Repository',
      unaryUseCasePath: map['unary_use_case_path'] as String? ?? '',
      unaryUseCaseName: map['unary_use_case_name'] as String? ?? 'UnaryUsecase',
      nullaryUseCasePath: map['nullary_use_case_path'] as String? ?? '',
      nullaryUseCaseName: map['nullary_use_case_name'] as String? ?? 'NullaryUsecase',
    );
  }
}
