import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'package:clean_architecture_kit/src/config/models/architecture_kit_config.dart';
import 'package:clean_architecture_kit/src/utils/layer_resolver.dart';
import 'package:clean_architecture_kit/src/utils/naming_utils.dart';

class PresentationLayerPurity extends DartLintRule {
  static const _code = LintCode(
    name: 'presentation_layer_purity',
    problemMessage: 'Presentation layer purity violation: Do not depend directly on a Repository.',
    correctionMessage:
        'The presentation layer should depend on a specific UseCase, not the entire '
        'repository.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  final CleanArchitectureConfig config;
  final LayerResolver layerResolver;

  PresentationLayerPurity({required this.config, required this.layerResolver}) : super(code: _code);

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    final layer = layerResolver.getLayer(resolver.source.fullName);
    if (layer != ArchLayer.presentation) return;

    context.registry.addConstructorDeclaration((node) {
      for (final parameter in node.parameters.parameters) {
        String? typeName;
        AstNode? reportNode;

        final typeNode = _getParameterTypeNode(parameter);
        if (typeNode != null) {
          typeName = typeNode.toSource();
          reportNode = typeNode;
        } else {
          final element = parameter.declaredFragment?.element;
          final elementType = element?.type;
          if (elementType != null) {
            typeName = elementType.getDisplayString();
            reportNode = parameter;
          } else {
            continue;
          }
        }

        if (typeName.endsWith('?')) typeName = typeName.substring(0, typeName.length - 1);

        if (validateName(name: typeName, template: config.naming.repositoryInterface)) {
          final nameToken = parameter.name;

          if (nameToken != null) {
            reporter.atToken(nameToken, _code);
          } else {
            reporter.atNode(reportNode, _code);
          }
        }
      }
    });
  }

  TypeAnnotation? _getParameterTypeNode(FormalParameter parameter) {
    if (parameter is SimpleFormalParameter) return parameter.type;
    if (parameter is FieldFormalParameter) return parameter.type;
    if (parameter is SuperFormalParameter) return parameter.type;
    if (parameter is DefaultFormalParameter) return _getParameterTypeNode(parameter.parameter);

    return null;
  }
}
