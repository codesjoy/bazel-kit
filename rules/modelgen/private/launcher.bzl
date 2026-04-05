def _sh_quote(value):
    return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

def _bat_quote(value):
    return "\"" + value.replace("\"", "\"\"") + "\""

def _tool_file(dep, name):
    files = dep[DefaultInfo].files.to_list()
    if len(files) != 1:
        fail("expected a single file for tool %s, got %d" % (name, len(files)))
    return files[0]

def _tool_runfiles_path(file, is_windows):
    path = file.path
    if path.startswith("external/"):
        runfiles_path = path[len("external/"):]
    else:
        runfiles_path = "_main/" + file.short_path
    return runfiles_path.replace("/", "\\") if is_windows else runfiles_path

def _render_shell(dsn, dsn_env, out_dir, schema, tables, override, gen_aipsql, timestamp_mode, dry_run, force, package_name, tools):
    lines = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "launcher_dir=\"$(cd \"$(dirname \"$0\")\" && pwd)\"",
        "runfiles_dir=\"${RUNFILES_DIR:-${launcher_dir}/$(basename \"$0\").runfiles}\"",
        "RUNFILES_DIR=\"${runfiles_dir}\"",
        "workspace=\"${BUILD_WORKSPACE_DIRECTORY:-$(pwd)}\"",
        "cd \"${workspace}\"",
        "info() { printf 'INFO  %s\\n' \"$*\" >&2; }",
        "error() { printf 'ERROR %s\\n' \"$*\" >&2; }",
        "success() { printf 'SUCCESS %s\\n' \"$*\" >&2; }",
        "MODELGEN=%s" % _sh_quote("${RUNFILES_DIR}/" + tools["modelgen"]),
        "args=()",
        "dsn_value=%s" % _sh_quote(dsn),
        "if [[ -z \"${dsn_value}\" ]]; then",
        "  error \"Modelgen DSN is not set\"",
        "  exit 1",
        "fi",
        "args+=(--dsn \"${dsn_value}\")",
        "args+=(--out-dir %s)" % _sh_quote(out_dir),
        "args+=(--gen-aipsql %s)" % _sh_quote("true" if gen_aipsql else "false"),
        "args+=(--timestamp-mode %s)" % _sh_quote(timestamp_mode),
    ]
    if dsn_env:
        lines.insert(14, "if [[ -z \"${dsn_value}\" ]]; then dsn_value=\"${%s:-}\"; fi" % dsn_env)
    if schema:
        lines.append("args+=(--schema %s)" % _sh_quote(schema))
    if tables:
        lines.append("args+=(--tables %s)" % _sh_quote(",".join(tables)))
    if override:
        lines.append("args+=(--override %s)" % _sh_quote(override))
    if package_name:
        lines.append("args+=(--package %s)" % _sh_quote(package_name))
    if dry_run:
        lines.append("args+=(--dry-run)")
    if force:
        lines.append("args+=(--force)")
    lines.extend([
        "info \"Running codesjoy-modelgen\"",
        "\"${MODELGEN}\" \"${args[@]}\"",
        "success \"codesjoy-modelgen complete\"",
    ])
    return "\n".join(lines) + "\n"

def _render_batch(dsn, dsn_env, out_dir, schema, tables, override, gen_aipsql, timestamp_mode, dry_run, force, package_name, tools):
    lines = [
        "@echo off",
        "setlocal EnableExtensions EnableDelayedExpansion",
        "if \"%RUNFILES_DIR%\"==\"\" set \"RUNFILES_DIR=%~dpn0.runfiles\\\"",
        "if \"%BUILD_WORKSPACE_DIRECTORY%\"==\"\" (",
        "  set \"WORKSPACE=%CD%\"",
        ") else (",
        "  set \"WORKSPACE=%BUILD_WORKSPACE_DIRECTORY%\"",
        ")",
        "cd /d \"%WORKSPACE%\"",
        "set \"MODELGEN=%RUNFILES_DIR%%%s\"" % tools["modelgen"],
        "set \"DSN=%s\"" % dsn.replace("\"", "\"\""),
    ]
    if dsn_env:
        lines.extend([
            "if \"%DSN%\"==\"\" set \"DSN=%%%s%%\"" % dsn_env,
        ])
    lines.extend([
        "if \"%DSN%\"==\"\" (",
        "  echo ERROR Modelgen DSN is not set 1>&2",
        "  exit /b 1",
        ")",
        "echo INFO  Running codesjoy-modelgen 1>&2",
        "\"!MODELGEN!\" --dsn \"%DSN%\" --out-dir %s --gen-aipsql %s --timestamp-mode %s" % (
            _bat_quote(out_dir),
            _bat_quote("true" if gen_aipsql else "false"),
            _bat_quote(timestamp_mode),
        ),
    ])
    if schema:
        lines[-1] += " --schema %s" % _bat_quote(schema)
    if tables:
        lines[-1] += " --tables %s" % _bat_quote(",".join(tables))
    if override:
        lines[-1] += " --override %s" % _bat_quote(override)
    if package_name:
        lines[-1] += " --package %s" % _bat_quote(package_name)
    if dry_run:
        lines[-1] += " --dry-run"
    if force:
        lines[-1] += " --force"
    lines.extend([
        "if errorlevel 1 exit /b 1",
        "echo SUCCESS codesjoy-modelgen complete 1>&2",
        "exit /b 0",
    ])
    return "\r\n".join(lines) + "\r\n"

def _impl(ctx):
    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    override = ctx.file.override.short_path if ctx.file.override else ""
    tool_file = _tool_file(ctx.attr.tool_modelgen, "codesjoy-modelgen")
    tools = {
        "modelgen": _tool_runfiles_path(tool_file, is_windows),
    }
    launcher = ctx.actions.declare_file(ctx.label.name + (".bat" if is_windows else ".sh"))
    content = _render_batch(
        ctx.attr.dsn,
        ctx.attr.dsn_env,
        ctx.attr.out_dir,
        ctx.attr.schema,
        ctx.attr.tables,
        override,
        ctx.attr.gen_aipsql,
        ctx.attr.timestamp_mode,
        ctx.attr.dry_run,
        ctx.attr.force,
        ctx.attr.package_name,
        tools,
    ) if is_windows else _render_shell(
        ctx.attr.dsn,
        ctx.attr.dsn_env,
        ctx.attr.out_dir,
        ctx.attr.schema,
        ctx.attr.tables,
        override,
        ctx.attr.gen_aipsql,
        ctx.attr.timestamp_mode,
        ctx.attr.dry_run,
        ctx.attr.force,
        ctx.attr.package_name,
        tools,
    )
    ctx.actions.write(output = launcher, content = content, is_executable = not is_windows)

    inputs = [tool_file]
    if ctx.file.override:
        inputs.append(ctx.file.override)

    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = inputs),
    )]

codesjoy_modelgen_runner = rule(
    implementation = _impl,
    executable = True,
    attrs = {
        "dsn": attr.string(),
        "dsn_env": attr.string(),
        "out_dir": attr.string(mandatory = True),
        "schema": attr.string(),
        "tables": attr.string_list(),
        "override": attr.label(allow_single_file = True),
        "gen_aipsql": attr.bool(default = True),
        "timestamp_mode": attr.string(default = "unix_sec"),
        "dry_run": attr.bool(default = False),
        "force": attr.bool(default = False),
        "package_name": attr.string(),
        "tool_modelgen": attr.label(cfg = "exec", default = "@modelgen_tool_codesjoy_modelgen//:tool"),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
)
