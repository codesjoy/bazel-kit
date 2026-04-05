def _sh_quote(value):
    return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

def _bat_quote(value):
    return "\"" + value.replace("\"", "\"\"") + "\""

def _tool_file(dep, name):
    files = dep[DefaultInfo].files.to_list()
    if len(files) != 1:
        fail("expected a single file for tool %s, got %d" % (name, len(files)))
    return files[0]

def _runfiles_path(file, is_windows):
    path = file.path
    if path.startswith("external/"):
        runfiles_path = path[len("external/"):]
    else:
        runfiles_path = "_main/" + file.short_path
    return runfiles_path.replace("/", "\\") if is_windows else runfiles_path

def _render_shell(helper, args):
    return "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "launcher_dir=\"$(cd \"$(dirname \"$0\")\" && pwd)\"",
        "runfiles_dir=\"${RUNFILES_DIR:-${launcher_dir}/$(basename \"$0\").runfiles}\"",
        "export RUNFILES_DIR=\"${runfiles_dir}\"",
        "workspace=\"${BUILD_WORKSPACE_DIRECTORY:-$(pwd)}\"",
        "export BUILD_WORKSPACE_DIRECTORY=\"${workspace}\"",
        "exec %s %s \"$@\"" % (_sh_quote("${RUNFILES_DIR}/" + helper), " ".join([_sh_quote(arg) for arg in args])),
    ]) + "\n"

def _render_batch(helper, args):
    return "\r\n".join([
        "@echo off",
        "setlocal EnableExtensions EnableDelayedExpansion",
        "if \"%RUNFILES_DIR%\"==\"\" set \"RUNFILES_DIR=%~dpn0.runfiles\\\"",
        "if \"%BUILD_WORKSPACE_DIRECTORY%\"==\"\" (",
        "  set \"BUILD_WORKSPACE_DIRECTORY=%CD%\"",
        ")",
        "\"%RUNFILES_DIR%%%s\" %s %%*" % (helper, " ".join([_bat_quote(arg) for arg in args])),
        "exit /b %ERRORLEVEL%",
    ]) + "\r\n"

def _impl(ctx):
    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    helper_file = _tool_file(ctx.attr._runner, "runner")
    tool_file = _tool_file(ctx.attr.tool_migrate, "migrate")
    args = [
        "migrate",
        "--kind",
        ctx.attr.kind,
        "--tool",
        "${RUNFILES_DIR}/" + _runfiles_path(tool_file, is_windows),
        "--migrations-dir",
        ctx.attr.migrations_dir,
        "--table",
        ctx.attr.table,
    ]
    if ctx.attr.dsn:
        args.extend(["--dsn", ctx.attr.dsn])
    if ctx.attr.dsn_env:
        args.extend(["--dsn-env", ctx.attr.dsn_env])
    if ctx.attr.kind == "down":
        args.extend(["--down-steps", str(ctx.attr.down_steps)])
    if ctx.attr.kind == "force":
        args.extend(["--force-version", ctx.attr.force_version])

    launcher = ctx.actions.declare_file(ctx.label.name + (".bat" if is_windows else ".sh"))
    content = _render_batch(_runfiles_path(helper_file, is_windows), args) if is_windows else _render_shell(_runfiles_path(helper_file, is_windows), args)
    ctx.actions.write(output = launcher, content = content, is_executable = not is_windows)
    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = [helper_file, tool_file]),
    )]

migrate_runner = rule(
    implementation = _impl,
    executable = True,
    attrs = {
        "kind": attr.string(mandatory = True, values = ["up", "down", "version", "force"]),
        "dsn": attr.string(),
        "dsn_env": attr.string(),
        "migrations_dir": attr.string(mandatory = True),
        "table": attr.string(default = "schema_migrations"),
        "down_steps": attr.int(default = 1),
        "force_version": attr.string(),
        "tool_migrate": attr.label(cfg = "exec", default = "@migrate_tool_migrate//:tool"),
        "_runner": attr.label(cfg = "exec", default = "//tools/source_runner:runner"),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
)
