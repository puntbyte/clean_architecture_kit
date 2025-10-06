// Helper functions (_getMap, _getList) remain the same.
Map<String, dynamic> _getMap(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<String> _getList(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is List) return value.whereType<String>().toList();
  return [];
}

class LayerConfig {
  final String projectStructure;
  final String featuresRootPath;
  final String domainPath;
  final String dataPath;
  final String presentationPath;
  final List<String> domainEntitiesPaths;
  final List<String> domainRepositoriesPaths;
  final List<String> domainUseCasesPaths;
  final List<String> dataRepositoriesPaths;
  final List<String> dataDataSourcesPaths;
  final List<String> presentationManagerPaths;

  const LayerConfig({
    required this.projectStructure,
    required this.featuresRootPath,
    required this.domainPath,
    required this.dataPath,
    required this.presentationPath,
    required this.domainEntitiesPaths,
    required this.domainRepositoriesPaths,
    required this.domainUseCasesPaths,
    required this.dataRepositoriesPaths,
    required this.dataDataSourcesPaths,
    required this.presentationManagerPaths,
  });

  static String _sanitize(String path) {
    if (path.startsWith('lib/')) path = path.substring(4);
    if (path.startsWith('/')) path = path.substring(1);
    return path;
  }

  factory LayerConfig.fromMap(Map<String, dynamic> map) {
    final layerFirst = _getMap(map, 'layer_first_paths');
    final featureFirst = _getMap(map, 'feature_first_paths');
    final layerDefinitions = _getMap(map, 'layer_definitions');

    final domainDefinitions = _getMap(layerDefinitions, 'domain');
    final dataDefinitions = _getMap(layerDefinitions, 'data');
    final presentationDefinitions = _getMap(layerDefinitions, 'presentation');

    return LayerConfig(
      projectStructure: map['project_structure'] as String? ?? 'feature_first',
      featuresRootPath: _sanitize(featureFirst['features_root'] as String? ?? 'features'),
      domainPath: _sanitize(layerFirst['domain'] as String? ?? 'domain'),
      dataPath: _sanitize(layerFirst['data'] as String? ?? 'data'),
      presentationPath: _sanitize(layerFirst['presentation'] as String? ?? 'presentation'),
      domainEntitiesPaths: _getList(domainDefinitions, 'entities'),
      domainRepositoriesPaths: _getList(domainDefinitions, 'repositories'),
      domainUseCasesPaths: _getList(domainDefinitions, 'use_cases'),
      dataRepositoriesPaths: _getList(dataDefinitions, 'repositories'),
      dataDataSourcesPaths: _getList(dataDefinitions, 'data_sources'),
      presentationManagerPaths: _getList(presentationDefinitions, 'managers'),
    );
  }
}
