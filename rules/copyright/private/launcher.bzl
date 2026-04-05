def _short_paths(files):
    return sorted([f.short_path for f in files])

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
    tool_file = _tool_file(ctx.attr.tool_addlicense, "addlicense")
    args = [
        "copyright",
        "--kind",
        ctx.attr.kind,
        "--tool",
        "${RUNFILES_DIR}/" + _runfiles_path(tool_file, is_windows),
        "--boilerplate",
        _short_paths([ctx.file.boilerplate])[0],
    ]
    for root in ctx.attr.roots:
        args.extend(["--root", root])
    for pattern in ctx.attr.patterns:
        args.extend(["--pattern", pattern])
    if ctx.attr.year:
        args.extend(["--year", ctx.attr.year])

    launcher = ctx.actions.declare_file(ctx.label.name + (".bat" if is_windows else ".sh"))
    content = _render_batch(_runfiles_path(helper_file, is_windows), args) if is_windows else _render_shell(_runfiles_path(helper_file, is_windows), args)
    ctx.actions.write(output = launcher, content = content, is_executable = not is_windows)
    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = [helper_file, tool_file, ctx.file.boilerplate]),
    )]

copyright_runner = rule(
    implementation = _impl,
    executable = True,
    attrs = {
        "kind": attr.string(mandatory = True, values = ["add", "verify"]),
        "boilerplate": attr.label(allow_single_file = True, mandatory = True),
        "roots": attr.string_list(default = ["."]),
        "patterns": attr.string_list(default = ["*.go", "*.sh"]),
        "year": attr.string(),
        "tool_addlicense": attr.label(cfg = "exec", default = "@copyright_tool_addlicense//:tool"),
        "_runner": attr.label(cfg = "exec", default = "//tools/source_runner:runner"),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
)
