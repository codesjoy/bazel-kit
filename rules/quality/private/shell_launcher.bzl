def _short_paths(files):
    return sorted([f.short_path for f in files])

def _windows_paths(paths):
    return [path.replace("/", "\\") for path in paths]

def _sh_quote(value):
    return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

def _bat_quote(value):
    return "\"" + value.replace("\"", "\"\"") + "\""

def _tool_file(dep, name):
    files = dep[DefaultInfo].files.to_list()
    if len(files) != 1:
        fail("expected a single file for tool %s, got %d" % (name, len(files)))
    return files[0]

def _tool_path(file, is_windows):
    path = file.path
    return path.replace("/", "\\") if is_windows else path

def _tool_runfiles_path(file, is_windows):
    path = file.path
    if path.startswith("external/"):
        runfiles_path = path[len("external/"):]
    else:
        runfiles_path = "_main/" + file.short_path
    return runfiles_path.replace("/", "\\") if is_windows else runfiles_path

def _render_shell(scripts, tools):
    lines = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "launcher_dir=\"$(cd \"$(dirname \"$0\")\" && pwd)\"",
        "runfiles_dir=\"${RUNFILES_DIR:-${launcher_dir}/$(basename \"$0\").runfiles}\"",
        "RUNFILES_DIR=\"${runfiles_dir}\"",
        "workspace=\"${BUILD_WORKSPACE_DIRECTORY:-$(pwd)}\"",
        "cd \"${workspace}\"",
        "info() { printf 'INFO  %s\\n' \"$*\" >&2; }",
        "warn() { printf 'WARN  %s\\n' \"$*\" >&2; }",
        "success() { printf 'SUCCESS %s\\n' \"$*\" >&2; }",
        "SHFMT=%s" % _sh_quote("${RUNFILES_DIR}/" + tools["shfmt"]),
        "SHELLCHECK=%s" % _sh_quote("${RUNFILES_DIR}/" + tools["shellcheck"]),
    ]
    if not scripts:
        lines.extend([
            "warn \"No shell scripts found to lint\"",
            "exit 0",
        ])
    else:
        args = " ".join([_sh_quote(path) for path in scripts])
        lines.extend([
            "info \"Linting shell scripts\"",
            "\"${SHFMT}\" -d %s" % args,
            "\"${SHELLCHECK}\" -x %s" % args,
            "success \"Shell scripts linted successfully\"",
        ])
    return "\n".join(lines) + "\n"

def _render_batch(scripts, tools):
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
        "set \"SHFMT=%RUNFILES_DIR%%%s\"" % tools["shfmt"],
        "set \"SHELLCHECK=%RUNFILES_DIR%%%s\"" % tools["shellcheck"],
    ]
    if not scripts:
        lines.extend([
            "echo WARN  No shell scripts found to lint 1>&2",
            "exit /b 0",
        ])
    else:
        args = " ".join([_bat_quote("%WORKSPACE%\\" + path) for path in _windows_paths(scripts)])
        lines.extend([
            "echo INFO  Linting shell scripts 1>&2",
            "\"!SHFMT!\" -d %s" % args,
            "if errorlevel 1 exit /b 1",
            "call \"!SHELLCHECK!\" -x %s" % args,
            "if errorlevel 1 exit /b 1",
            "echo SUCCESS Shell scripts linted successfully 1>&2",
            "exit /b 0",
        ])
    return "\r\n".join(lines) + "\r\n"

def _impl(ctx):
    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    scripts = _short_paths(ctx.files.scripts)
    tool_files = [
        _tool_file(ctx.attr.tool_shfmt, "shfmt"),
        _tool_file(ctx.attr.tool_shellcheck, "shellcheck"),
    ]
    tools = {
        "shfmt": _tool_runfiles_path(tool_files[0], is_windows),
        "shellcheck": _tool_runfiles_path(tool_files[1], is_windows),
    }
    launcher = ctx.actions.declare_file(ctx.label.name + (".bat" if is_windows else ".sh"))
    content = _render_batch(scripts, tools) if is_windows else _render_shell(scripts, tools)
    ctx.actions.write(
        output = launcher,
        content = content,
        is_executable = not is_windows,
    )
    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = ctx.files.scripts + tool_files),
    )]

quality_shell_runner = rule(
    implementation = _impl,
    executable = True,
    attrs = {
        "scripts": attr.label_list(allow_files = True, mandatory = True),
        "tool_shfmt": attr.label(cfg = "exec", default = "@quality_tool_shfmt//:tool"),
        "tool_shellcheck": attr.label(cfg = "exec", default = "@quality_tool_shellcheck//:tool"),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
)
