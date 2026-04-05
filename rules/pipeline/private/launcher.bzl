PipelineServiceInfo = provider(
    doc = "Metadata exported by pipeline_service targets.",
    fields = {
        "analysis_targets": "Labels used to participate in Bazel impact analysis.",
        "deploy_environments": "Deployment environments for this service.",
        "image_targets": "Image build or push targets.",
        "integration_targets": "Integration test targets.",
        "label": "The pipeline_service label.",
        "language": "Service language.",
        "lint_targets": "Lint targets.",
        "preview_mode": "Preview environment strategy.",
        "render_target": "Manifest render target.",
        "runtime_deps": "Runtime dependency service names.",
        "service_name": "Stable service name.",
        "unit_targets": "Unit test targets.",
        "workload_kind": "Deployment workload kind.",
    },
)

def _json_escape(value):
    return value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")

def _json_string(value):
    return "\"" + _json_escape(value) + "\""

def _json_list(values):
    return "[" + ", ".join([_json_string(value) for value in values]) + "]"

def _normalize_label_string(value):
    if value.startswith("@@//"):
        return value[2:]
    if value.startswith("@@"):
        return "@" + value[2:]
    return value

def _target_labels(targets):
    return sorted([_normalize_label_string(str(target.label)) for target in targets])

def _sh_quote(value):
    return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

def _bat_quote(value):
    return "\"" + value.replace("\"", "\"\"") + "\""

def _runfiles_path(file, is_windows):
    path = file.path
    if path.startswith("external/"):
        runfiles_path = path[len("external/"):]
    else:
        runfiles_path = "_main/" + file.short_path
    return runfiles_path.replace("/", "\\") if is_windows else runfiles_path

def _tool_file(dep, name):
    files = dep[DefaultInfo].files.to_list()
    if len(files) != 1:
        fail("expected a single file for tool %s, got %d" % (name, len(files)))
    return files[0]

def _tool_named_file(dep, suffix, name):
    files = dep[DefaultInfo].files.to_list()
    if len(files) == 1:
        return files[0]
    for file in files:
        if file.path.endswith("/" + suffix) or file.path.endswith("\\" + suffix) or file.basename == suffix:
            return file
    fail("expected tool %s to expose %s" % (name, suffix))

def _runner_wrapper(helper, script, exports, is_windows):
    args = [
        "python-launch",
        "--script",
        ("${RUNFILES_DIR}/" if not is_windows else "%RUNFILES_DIR%\\") + script,
    ]
    for key, value in sorted(exports.items()):
        args.extend(["--env", key + "=" + value])
    if is_windows:
        return "\r\n".join([
            "@echo off",
            "setlocal EnableExtensions EnableDelayedExpansion",
            "if \"%RUNFILES_DIR%\"==\"\" set \"RUNFILES_DIR=%~dpn0.runfiles\\\"",
            "if \"%BUILD_WORKSPACE_DIRECTORY%\"==\"\" (",
            "  set \"BUILD_WORKSPACE_DIRECTORY=%CD%\"",
            ")",
            "\"%RUNFILES_DIR%%%s\" %s -- %%*" % (helper, " ".join([_bat_quote(arg) for arg in args])),
            "exit /b %ERRORLEVEL%",
        ]) + "\r\n"
    return "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "launcher_dir=\"$(cd \"$(dirname \"$0\")\" && pwd)\"",
        "runfiles_dir=\"${RUNFILES_DIR:-${launcher_dir}/$(basename \"$0\").runfiles}\"",
        "export RUNFILES_DIR=\"${runfiles_dir}\"",
        "workspace=\"${BUILD_WORKSPACE_DIRECTORY:-$(pwd)}\"",
        "export BUILD_WORKSPACE_DIRECTORY=\"${workspace}\"",
        "exec %s %s -- \"$@\"" % (_sh_quote("${RUNFILES_DIR}/" + helper), " ".join([_sh_quote(arg) for arg in args])),
    ]) + "\n"

def _service_impl(ctx):
    service_name = ctx.attr.service_name if ctx.attr.service_name else ctx.label.name
    analysis_targets = _target_labels(ctx.attr.analysis_targets)

    return [
        DefaultInfo(),
        PipelineServiceInfo(
            analysis_targets = analysis_targets,
            deploy_environments = ctx.attr.deploy_environments,
            image_targets = sorted(ctx.attr.image_targets),
            integration_targets = sorted(ctx.attr.integration_targets),
            label = _normalize_label_string(str(ctx.label)),
            language = ctx.attr.language,
            lint_targets = sorted(ctx.attr.lint_targets),
            preview_mode = ctx.attr.preview_mode,
            render_target = _normalize_label_string(ctx.attr.render_target),
            runtime_deps = sorted(ctx.attr.runtime_deps),
            service_name = service_name,
            unit_targets = sorted(ctx.attr.unit_targets),
            workload_kind = ctx.attr.workload_kind,
        ),
    ]

def _service_json(info):
    return """    {{
      "service_name": {service_name},
      "label": {label},
      "language": {language},
      "analysis_targets": {analysis_targets},
      "lint_targets": {lint_targets},
      "unit_targets": {unit_targets},
      "integration_targets": {integration_targets},
      "image_targets": {image_targets},
      "render_target": {render_target},
      "runtime_deps": {runtime_deps},
      "workload_kind": {workload_kind},
      "preview_mode": {preview_mode},
      "deploy_environments": {deploy_environments}
    }}""".format(
        analysis_targets = _json_list(info.analysis_targets),
        deploy_environments = _json_list(info.deploy_environments),
        image_targets = _json_list(info.image_targets),
        integration_targets = _json_list(info.integration_targets),
        label = _json_string(info.label),
        language = _json_string(info.language),
        lint_targets = _json_list(info.lint_targets),
        preview_mode = _json_string(info.preview_mode),
        render_target = _json_string(info.render_target),
        runtime_deps = _json_list(info.runtime_deps),
        service_name = _json_string(info.service_name),
        unit_targets = _json_list(info.unit_targets),
        workload_kind = _json_string(info.workload_kind),
    )

def _catalog_impl(ctx):
    infos = [service[PipelineServiceInfo] for service in ctx.attr.services]
    infos = sorted(infos, key = lambda info: info.service_name)
    repo_config = ctx.file.repo_config.short_path if ctx.file.repo_config else ""

    lines = [
        "{",
        "  \"version\": 1,",
        "  \"repo_config\": %s," % _json_string(repo_config),
        "  \"services\": [",
    ]
    for index, info in enumerate(infos):
        suffix = "," if index < len(infos) - 1 else ""
        lines.append(_service_json(info) + suffix)
    lines.extend([
        "  ]",
        "}",
        "",
    ])

    output = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.write(output = output, content = "\n".join(lines))
    runfiles_files = [output]
    if ctx.file.repo_config:
        runfiles_files.append(ctx.file.repo_config)
    return [DefaultInfo(files = depset([output]), runfiles = ctx.runfiles(files = runfiles_files))]

def _plan_impl(ctx):
    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    helper_file = _tool_file(ctx.attr._runner, "runner")
    main_script = ctx.file._plan_main
    launcher = ctx.actions.declare_file(ctx.label.name + (".bat" if is_windows else ".sh"))
    content = _runner_wrapper(
        helper = _runfiles_path(helper_file, is_windows),
        script = _runfiles_path(main_script, is_windows),
        exports = {
            "PIPELINE_CATALOG": ("${RUNFILES_DIR}/" if not is_windows else "%RUNFILES_DIR%\\") + _runfiles_path(ctx.file.catalog, is_windows),
        },
        is_windows = is_windows,
    )
    ctx.actions.write(output = launcher, content = content, is_executable = not is_windows)

    runfiles_files = [
        helper_file,
        ctx.file.catalog,
        main_script,
    ]
    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = runfiles_files),
    )]

def _render_impl(ctx):
    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    helper_file = _tool_file(ctx.attr._runner, "runner")
    main_script = ctx.file._render_main
    helm_file = _tool_named_file(ctx.attr.tool_helm, "helm.exe" if is_windows else "helm", "helm")
    launcher = ctx.actions.declare_file(ctx.label.name + (".bat" if is_windows else ".sh"))
    content = _runner_wrapper(
        helper = _runfiles_path(helper_file, is_windows),
        script = _runfiles_path(main_script, is_windows),
        exports = {
            "PIPELINE_CHART_DIR": ctx.attr.chart_dir,
            "PIPELINE_HELM": ("${RUNFILES_DIR}/" if not is_windows else "%RUNFILES_DIR%\\") + _runfiles_path(helm_file, is_windows),
            "PIPELINE_RELEASE_NAME": ctx.attr.release_name if ctx.attr.release_name else (ctx.attr.service_name if ctx.attr.service_name else ctx.label.name),
            "PIPELINE_SERVICE_NAME": ctx.attr.service_name if ctx.attr.service_name else ctx.label.name,
        },
        is_windows = is_windows,
    )
    ctx.actions.write(output = launcher, content = content, is_executable = not is_windows)

    runfiles_files = [helper_file, main_script, helm_file]
    runfiles_files.extend(ctx.files.chart_files)
    runfiles_files.extend(ctx.attr.tool_helm[DefaultInfo].files.to_list())
    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = runfiles_files),
    )]

pipeline_service_rule = rule(
    implementation = _service_impl,
    attrs = {
        "service_name": attr.string(),
        "language": attr.string(
            mandatory = True,
            values = ["go", "web", "custom"],
        ),
        "analysis_targets": attr.label_list(),
        "lint_targets": attr.string_list(),
        "unit_targets": attr.string_list(),
        "integration_targets": attr.string_list(),
        "image_targets": attr.string_list(),
        "render_target": attr.string(mandatory = True),
        "runtime_deps": attr.string_list(),
        "workload_kind": attr.string(
            default = "deployment",
            values = ["deployment", "worker"],
        ),
        "preview_mode": attr.string(
            default = "shared_baseline",
            values = ["shared_baseline", "full_isolated"],
        ),
        "deploy_environments": attr.string_list(default = ["dev", "staging", "prod"]),
    },
)

pipeline_catalog = rule(
    implementation = _catalog_impl,
    attrs = {
        "services": attr.label_list(providers = [PipelineServiceInfo], mandatory = True),
        "repo_config": attr.label(allow_single_file = True),
    },
)

pipeline_plan = rule(
    implementation = _plan_impl,
    executable = True,
    attrs = {
        "catalog": attr.label(allow_single_file = True, mandatory = True),
        "_plan_main": attr.label(
            allow_single_file = True,
            default = "//rules/pipeline/private:plan_main.py",
        ),
        "_runner": attr.label(cfg = "exec", default = "//tools/source_runner:runner"),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
)

pipeline_helm_render = rule(
    implementation = _render_impl,
    executable = True,
    attrs = {
        "chart_dir": attr.string(mandatory = True),
        "chart_files": attr.label_list(allow_files = True, mandatory = True),
        "service_name": attr.string(),
        "release_name": attr.string(),
        "tool_helm": attr.label(cfg = "exec", default = "@pipeline_tool_helm//:tool"),
        "_render_main": attr.label(
            allow_single_file = True,
            default = "//rules/pipeline/private:render_main.py",
        ),
        "_runner": attr.label(cfg = "exec", default = "//tools/source_runner:runner"),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
)
