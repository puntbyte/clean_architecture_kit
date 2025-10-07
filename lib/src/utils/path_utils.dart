import 'dart:io';
import 'package:clean_architecture_kit/src/utils/string_utils.dart';
import 'package:path/path.dart' as p;

import '../config/models/architecture_kit_config.dart';
import 'naming_utils.dart';

/// In-memory registry of use-case files that were just created by the quick-fix.
/// This prevents repeatedly reporting the same missing-use-case diagnostic
/// while the analysis server is catching up and/or before the file appears on disk.
final Set<String> _recentlyCreatedUseCases = <String>{};

/// Mark a use-case path as created for the current session/analysis run.
void markUseCaseAsCreated(String path) {
  _recentlyCreatedUseCases.add(p.normalize(path));
}

/// Checks if a use case file exists, either because it was just created (in-memory cache)
/// or because it's already on disk.
bool useCaseFileExists(String path) {
  if (_recentlyCreatedUseCases.contains(p.normalize(path))) {
    return true;
  }
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}

/// Optionally clear the in-memory registry (useful for tests).
void clearMarkedUseCases() => _recentlyCreatedUseCases.clear();

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
  final insideLib = normalized.substring(libIndex + 4); // skip 'lib/'

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
  return p.normalize(p.join(useCaseDir, useCaseFileName));
}

bool isPathInEntityDirectory(String path, CleanArchitectureConfig config) {
  final layerConfig = config.layers;
  // Ensure the user has actually defined entity directories.
  if (layerConfig.domainRepositoriesPaths.isEmpty) return false;

  final normalizedPath = p.normalize(path);
  final segments = normalizedPath.split(p.separator);

  final domainDirName = layerConfig.projectStructure == 'layer_first'
      ? layerConfig.domainPath
      : 'domain';

  final domainIndex = segments.lastIndexOf(domainDirName);
  if (domainIndex == -1) return false;

  for (final entityDir in layerConfig.domainRepositoriesPaths) {
    final entityIndex = segments.lastIndexOf(entityDir);
    if (entityIndex > domainIndex) {
      return true;
    }
  }

  return false;
}