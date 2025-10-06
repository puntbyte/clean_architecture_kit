import 'dart:io';
import 'package:clean_architecture_kit/src/utils/string_utils.dart';
import 'package:path/path.dart' as p;

import '../config/models/architecture_kit_config.dart';
import 'naming_utils.dart';

/// Finds the project root directory by searching upwards for a `pubspec.yaml` file.
String? findProjectRoot(String fileAbsolutePath) {
  var dir = Directory(p.dirname(fileAbsolutePath));
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) return dir.path;
    if (p.equals(dir.parent.path, dir.path)) break; // Reached filesystem root
    dir = dir.parent;
  }
  return null;
}

/// Determines the absolute path of the `usecases` directory for a given repository file.
String? getUseCasesDirectoryPath(String repoPath, CleanArchitectureConfig config) {
  final projectRoot = findProjectRoot(repoPath);
  if (projectRoot == null) return null;

  final normalized = p.normalize(repoPath);
  final libIndex = normalized.indexOf(p.join('lib', ''));
  if (libIndex == -1) return null;
  final insideLib = normalized.substring(libIndex + 4);

  final layerCfg = config.layers;

  if (layerCfg.projectStructure == 'feature_first') {
    final segments = p.split(insideLib);
    if (segments.length < 4 || segments[0] != layerCfg.featuresRootPath) return null;
    final featureName = segments[1];
    return p.join(
      projectRoot,
      'lib',
      layerCfg.featuresRootPath,
      featureName,
      'domain',
      layerCfg.domainUseCasesPaths.first,
    );
  } else {
    return p.join(projectRoot, 'lib', 'domain', layerCfg.domainUseCasesPaths.first);
  }
}

/// Determines the absolute path for a new use case file.
String? getUseCaseFilePath({
  required String methodName,
  required String repoPath,
  required CleanArchitectureConfig config,
}) {
  final useCaseDir = getUseCasesDirectoryPath(repoPath, config);
  if (useCaseDir == null) return null;

  final useCaseClassName = getExpectedUseCaseClassName(methodName, config);
  final useCaseFileName = '${toSnakeCase(useCaseClassName)}.dart';
  return p.join(useCaseDir, useCaseFileName);
}

bool isPathInEntityDirectory(String path, CleanArchitectureConfig config) {
  final layerConfig = config.layers;
  // Ensure the user has actually defined entity directories.
  if (layerConfig.domainRepositoriesPaths.isEmpty) return false;

  final normalizedPath = p.normalize(path);
  final segments = normalizedPath.split(p.separator);

  // A heuristic: check if the path contains a directory named 'domain'
  // followed by one of the configured entity directory names.
  final domainDirName = layerConfig.projectStructure == 'layer_first'
      ? layerConfig.domainPath
      : 'domain';

  final domainIndex = segments.lastIndexOf(domainDirName);
  if (domainIndex == -1) return false;

  // Check if any of the configured entity directories appear after the domain directory.
  for (final entityDir in layerConfig.domainRepositoriesPaths) {
    final entityIndex = segments.lastIndexOf(entityDir);
    if (entityIndex > domainIndex) {
      return true;
    }
  }

  return false;
}
