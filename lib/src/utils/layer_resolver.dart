import 'package:clean_architecture_kit/src/config/models/architecture_kit_config.dart';

enum ArchLayer { domain, data, presentation, unknown }

enum ArchSubLayer {
  entity,
  domainRepository,
  useCase,
  dataRepository,
  dataSource,
  model,
  presentationManager,
  unknown,
}

class LayerResolver {
  final CleanArchitectureConfig _config;

  LayerResolver(this._config);

  List<String>? _getRelativePathSegments(String absolutePath) {
    final normalized = absolutePath.replaceAll('\\', '/');
    final libIndex = normalized.indexOf('/lib/');
    if (libIndex == -1) return null;
    final pathInsideLib = normalized.substring(libIndex + 5);
    return pathInsideLib.split('/');
  }

  ArchLayer getLayer(String path) {
    final segments = _getRelativePathSegments(path);
    if (segments == null) return ArchLayer.unknown;

    // Use a null check for safety, although the entry point should prevent this.
    final layerConfig = _config.layers;

    if (layerConfig.projectStructure == 'layer_first') {
      if (segments.isEmpty) return ArchLayer.unknown;
      if (segments.first == layerConfig.domainPath) return ArchLayer.domain;
      if (segments.first == layerConfig.dataPath) return ArchLayer.data;
      if (segments.first == layerConfig.presentationPath) return ArchLayer.presentation;
    } else {
      // feature-first
      if (segments.length < 3) return ArchLayer.unknown;
      if (segments.first != layerConfig.featuresRootPath) return ArchLayer.unknown;

      final layerName = segments[2];
      if (layerName == 'domain') return ArchLayer.domain;
      if (layerName == 'data') return ArchLayer.data;
      if (layerName == 'presentation') return ArchLayer.presentation;
    }
    return ArchLayer.unknown;
  }

  ArchSubLayer getSubLayer(String path) {
    final segments = _getRelativePathSegments(path);
    if (segments == null) return ArchSubLayer.unknown;

    final layerConfig = _config.layers;
    final layer = getLayer(path);

    // --- THIS IS THE DEFINITIVE FIX ---
    // Each check now uses the correct property from the LayerConfig model.
    if (layer == ArchLayer.domain) {
      if (layerConfig.domainEntitiesPaths.any(segments.contains)) return ArchSubLayer.entity;
      if (layerConfig.domainRepositoriesPaths.any(segments.contains)) {
        return ArchSubLayer.domainRepository;
      }
      if (layerConfig.domainUseCasesPaths.any(segments.contains)) return ArchSubLayer.useCase;
    } else if (layer == ArchLayer.data) {
      if (layerConfig.dataRepositoriesPaths.any(segments.contains)) {
        return ArchSubLayer.dataRepository;
      }
      if (layerConfig.dataDataSourcesPaths.any(segments.contains)) return ArchSubLayer.dataSource;
    } else if (layer == ArchLayer.presentation) {
      if (layerConfig.presentationManagerPaths.any(segments.contains)) {
        return ArchSubLayer.presentationManager;
      }
    }
    // --- END OF FIX ---

    return ArchSubLayer.unknown;
  }
}
