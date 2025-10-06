import 'package:clean_architecture_kit/src/config/models/architecture_kit_config.dart';
import 'package:clean_architecture_kit/src/lints/domain_layer_purity.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

// The main config class now directly represents the `clean_architecture` block.
import 'src/lints/data_source_purity.dart';
import 'src/lints/disallow_flutter_imports_in_domain.dart';
import 'src/lints/disallow_flutter_types_in_domain.dart';
import 'src/lints/enforce_abstract_data_source_dependency.dart';
import 'src/lints/enforce_custom_return_type.dart';
import 'src/lints/enforce_file_and_folder_location.dart';
import 'src/lints/enforce_layer_independence.dart';
import 'src/lints/enforce_naming_conventions.dart';
import 'src/lints/enforce_repository_inheritance.dart';
import 'src/lints/enforce_use_case_inheritance.dart';
import 'src/lints/missing_use_case.dart';
import 'src/lints/presentation_layer_purity.dart';
import 'src/lints/repository_implementation_purity.dart';
import 'src/utils/layer_resolver.dart';

/// This is the entry point for the plugin.
PluginBase createPlugin() => _CleanArchitectureKitLinter();

/// The main plugin class for the `clean_architecture_kit` package.
class _CleanArchitectureKitLinter extends PluginBase {
  /// Instance variable to hold the parsed configuration.
  CleanArchitectureConfig? _config;

  /// Performs one-time initialization of the configuration.
  void _initialize(CustomLintConfigs configs) {
    if (_config != null) return;

    // Correctly look for the `clean_architecture` key inside the `custom_lint` rules list.
    final rawConfig = Map<String, dynamic>.from(configs.rules['clean_architecture']?.json ?? {});

    _config = CleanArchitectureConfig.fromMap(rawConfig);
  }

  /// This is the designated initialization method for lints.
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) {
    // Ensure the plugin's configuration is initialized.
    _initialize(configs);

    // If the config object failed to initialize (e.g., key not found), return no lints.
    if (_config == null) return [];

    // Create a single LayerResolver instance to pass to all lints.
    final layerResolver = LayerResolver(_config!);

    // Create and return the list of all lints for Clean Architecture.
    return [
      // Purity Rules
      DomainLayerPurity(config: _config!, layerResolver: layerResolver),
      DataSourcePurity(config: _config!, layerResolver: layerResolver),
      PresentationLayerPurity(config: _config!, layerResolver: layerResolver),
      RepositoryImplementationPurity(config: _config!, layerResolver: layerResolver),
      DisallowFlutterImportsInDomain(config: _config!, layerResolver: layerResolver),
      DisallowFlutterTypesInDomain(config: _config!, layerResolver: layerResolver),

      // Dependency & Structure Rules
      EnforceLayerIndependence(config: _config!, layerResolver: layerResolver),
      EnforceAbstractDataSourceDependency(config: _config!, layerResolver: layerResolver),
      EnforceFileAndFolderLocation(config: _config!, layerResolver: layerResolver),

      // Naming, Type Safety & Inheritance Rules
      EnforceNamingConventions(config: _config!, layerResolver: layerResolver),
      EnforceCustomReturnType(config: _config!, layerResolver: layerResolver),
      EnforceUseCaseInheritance(config: _config!, layerResolver: layerResolver),
      EnforceRepositoryInheritance(config: _config!, layerResolver: layerResolver),

      // Code Generation Rule
      MissingUseCase(config: _config!, layerResolver: layerResolver),
    ];
  }

  @override
  List<Assist> getAssists() => [];
}
