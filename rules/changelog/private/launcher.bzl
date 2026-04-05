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

def _toggle(value):
    return "1" if value else "0"

def _impl(ctx):
    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    helper_file = _tool_file(ctx.attr._runner, "runner")
    tool_file = _tool_file(ctx.attr.tool_git_chglog, "git-chglog")
    args = [
        "changelog",
        "--kind",
        ctx.attr.kind,
        "--tool",
        "${RUNFILES_DIR}/" + _runfiles_path(tool_file, is_windows),
        "--changelog-file",
        ctx.attr.changelog_file,
        "--config",
        ctx.attr.config,
        "--template",
        ctx.attr.template,
        "--next-tag",
        ctx.attr.next_tag,
        "--sort",
        ctx.attr.sort,
        "--profile",
        ctx.attr.profile,
        "--state-file",
        ctx.attr.state_file,
        "--archive-dir",
        ctx.attr.archive_dir,
    ]
    if ctx.attr.query:
        args.extend(["--query", ctx.attr.query])
    if ctx.attr.from_ref:
        args.extend(["--from-ref", ctx.attr.from_ref])
    if ctx.attr.to_ref:
        args.extend(["--to-ref", ctx.attr.to_ref])
    for path_filter in ctx.attr.path_filters:
        args.extend(["--path-filter", path_filter])
    if ctx.attr.cadence != "monthly":
        args.extend(["--cadence", ctx.attr.cadence])
    if not ctx.attr.use_baseline:
        args.extend(["--use-baseline", _toggle(ctx.attr.use_baseline)])
    if not ctx.attr.archive_enable:
        args.extend(["--archive-enable", _toggle(ctx.attr.archive_enable)])
    if ctx.attr.now:
        args.extend(["--now", ctx.attr.now])
    if ctx.attr.strict_state:
        args.extend(["--strict-state", "true"])

    launcher = ctx.actions.declare_file(ctx.label.name + (".bat" if is_windows else ".sh"))
    content = _render_batch(_runfiles_path(helper_file, is_windows), args) if is_windows else _render_shell(_runfiles_path(helper_file, is_windows), args)
    ctx.actions.write(output = launcher, content = content, is_executable = not is_windows)
    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = [helper_file, tool_file]),
    )]

changelog_runner = rule(
    implementation = _impl,
    executable = True,
    attrs = {
        "kind": attr.string(mandatory = True, values = ["init", "generate", "preview", "verify", "state_print", "state_reset"]),
        "changelog_file": attr.string(default = "CHANGELOG.md"),
        "config": attr.string(default = ".chglog/config.yml"),
        "template": attr.string(default = ".chglog/CHANGELOG.tpl.md"),
        "query": attr.string(),
        "from_ref": attr.string(),
        "to_ref": attr.string(),
        "next_tag": attr.string(default = "unreleased"),
        "path_filters": attr.string_list(),
        "sort": attr.string(default = "date"),
        "profile": attr.string(default = "balanced"),
        "cadence": attr.string(default = "monthly"),
        "use_baseline": attr.bool(default = True),
        "archive_enable": attr.bool(default = True),
        "state_file": attr.string(default = ".chglog/state.env"),
        "archive_dir": attr.string(default = ".chglog/archive"),
        "now": attr.string(),
        "strict_state": attr.bool(default = False),
        "tool_git_chglog": attr.label(cfg = "exec", default = "@changelog_tool_git_chglog//:tool"),
        "_runner": attr.label(cfg = "exec", default = "//tools/source_runner:runner"),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
)
