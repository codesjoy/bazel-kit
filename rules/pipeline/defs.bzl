load("//rules/pipeline/private:launcher.bzl", _pipeline_catalog = "pipeline_catalog", _pipeline_helm_render = "pipeline_helm_render", _pipeline_plan = "pipeline_plan", _pipeline_service_rule = "pipeline_service_rule")

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
        preview_mode = preview_mode,
        render_target = normalized_render_target,
        runtime_deps = runtime_deps,
        service_name = service_name if service_name else "",
        unit_targets = normalized_unit_targets,
        workload_kind = workload_kind,
        **kwargs
    )

pipeline_catalog = _pipeline_catalog
pipeline_plan = _pipeline_plan
pipeline_helm_render = _pipeline_helm_render
