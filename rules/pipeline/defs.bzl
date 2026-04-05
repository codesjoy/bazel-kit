load("//rules/pipeline/private:launcher.bzl", _pipeline_catalog = "pipeline_catalog", _pipeline_component_rule = "pipeline_component_rule", _pipeline_helm_render = "pipeline_helm_render", _pipeline_plan = "pipeline_plan", _pipeline_service_rule = "pipeline_service_rule")

def _normalize_label(value):
    label = str(native.package_relative_label(value))
    if label.startswith("@@//"):
        return label[2:]
    if label.startswith("@@"):
        return "@" + label[2:]
    return label

def pipeline_service(
        name,
        language,
        lint_targets,
        unit_targets,
        image_targets,
        render_target,
        analysis_targets = [],
        deploy_environments = ["dev", "staging", "prod"],
        integration_targets = [],
        owners = [],
        preview_mode = "shared_baseline",
        runtime_deps = [],
        service_name = None,
        workload_kind = "deployment",
        **kwargs):
    if not lint_targets:
        fail("pipeline_service requires lint_targets")
    if not unit_targets:
        fail("pipeline_service requires unit_targets")
    if not image_targets:
        fail("pipeline_service requires image_targets")
    if not render_target:
        fail("pipeline_service requires render_target")

    inferred_analysis_targets = analysis_targets if analysis_targets else (
        lint_targets +
        unit_targets +
        integration_targets +
        image_targets +
        [render_target]
    )
    normalized_lint_targets = [_normalize_label(target) for target in lint_targets]
    normalized_unit_targets = [_normalize_label(target) for target in unit_targets]
    normalized_integration_targets = [_normalize_label(target) for target in integration_targets]
    normalized_image_targets = [_normalize_label(target) for target in image_targets]
    normalized_render_target = _normalize_label(render_target)

    _pipeline_service_rule(
        name = name,
        analysis_targets = inferred_analysis_targets,
        deploy_environments = deploy_environments,
        image_targets = normalized_image_targets,
        integration_targets = normalized_integration_targets,
        language = language,
        lint_targets = normalized_lint_targets,
        owners = owners,
        preview_mode = preview_mode,
        render_target = normalized_render_target,
        runtime_deps = runtime_deps,
        service_name = service_name if service_name else "",
        unit_targets = normalized_unit_targets,
        workload_kind = workload_kind,
        **kwargs
    )

def pipeline_component(
        name,
        analysis_targets = [],
        component_name = None,
        integration_targets = [],
        lint_targets = [],
        owners = [],
        unit_targets = [],
        **kwargs):
    if "deploy_environments" in kwargs:
        fail("pipeline_component does not accept deploy_environments")
    if "image_targets" in kwargs:
        fail("pipeline_component does not accept image_targets")
    if "language" in kwargs:
        fail("pipeline_component does not accept language")
    if "preview_mode" in kwargs:
        fail("pipeline_component does not accept preview_mode")
    if "render_target" in kwargs:
        fail("pipeline_component does not accept render_target")
    if "runtime_deps" in kwargs:
        fail("pipeline_component does not accept runtime_deps")
    if "service_name" in kwargs:
        fail("pipeline_component does not accept service_name")
    if "workload_kind" in kwargs:
        fail("pipeline_component does not accept workload_kind")
    if not (lint_targets or unit_targets or integration_targets):
        fail("pipeline_component requires at least one of lint_targets, unit_targets, or integration_targets")

    inferred_analysis_targets = analysis_targets if analysis_targets else (
        lint_targets +
        unit_targets +
        integration_targets
    )
    normalized_lint_targets = [_normalize_label(target) for target in lint_targets]
    normalized_unit_targets = [_normalize_label(target) for target in unit_targets]
    normalized_integration_targets = [_normalize_label(target) for target in integration_targets]

    _pipeline_component_rule(
        name = name,
        analysis_targets = inferred_analysis_targets,
        component_name = component_name if component_name else "",
        integration_targets = normalized_integration_targets,
        lint_targets = normalized_lint_targets,
        owners = owners,
        unit_targets = normalized_unit_targets,
        **kwargs
    )

def pipeline_catalog(
        name,
        services,
        components = [],
        global_impact_files = [],
        global_impact_prefixes = [],
        **kwargs):
    _pipeline_catalog(
        name = name,
        subjects = services + components,
        global_impact_files = global_impact_files,
        global_impact_prefixes = global_impact_prefixes,
        **kwargs
    )

pipeline_plan = _pipeline_plan
pipeline_helm_render = _pipeline_helm_render
