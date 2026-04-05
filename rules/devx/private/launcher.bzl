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
    args = [
        "devx",
        "--kind",
        ctx.attr.kind,
    ]
    for target in ctx.attr.run_targets:
        args.extend(["--run-target", target])
    for target in ctx.attr.test_targets:
        args.extend(["--test-target", target])
    for target in ctx.attr.coverage_targets:
        args.extend(["--coverage-target", target])
    if ctx.attr.coverage_threshold:
        args.extend(["--coverage-threshold", str(ctx.attr.coverage_threshold)])
    if ctx.attr.coverage_output_dir:
        args.extend(["--coverage-output-dir", ctx.attr.coverage_output_dir])
    for arg in ctx.attr.bazel_args:
        args.extend(["--bazel-arg", arg])
    for command in ctx.attr.required_commands:
        args.extend(["--required-command", command])
    for target in ctx.attr.verify_run_targets:
        args.extend(["--verify-run-target", target])
    for target in ctx.attr.verify_test_targets:
        args.extend(["--verify-test-target", target])
    if not ctx.attr.require_git_repo:
        args.extend(["--require-git-repo", "false"])

    launcher = ctx.actions.declare_file(ctx.label.name + (".bat" if is_windows else ".sh"))
    content = _render_batch(_runfiles_path(helper_file, is_windows), args) if is_windows else _render_shell(_runfiles_path(helper_file, is_windows), args)
    ctx.actions.write(output = launcher, content = content, is_executable = not is_windows)
    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = [helper_file]),
    )]

devx_runner = rule(
    implementation = _impl,
    executable = True,
    attrs = {
        "kind": attr.string(
            mandatory = True,
            values = [
                "workflow",
                "doctor",
                "hooks_install",
                "hooks_verify",
                "hooks_run",
                "hooks_run_all",
                "hooks_clean",
            ],
        ),
        "run_targets": attr.string_list(),
        "test_targets": attr.string_list(),
        "coverage_targets": attr.string_list(),
        "coverage_threshold": attr.int(),
        "coverage_output_dir": attr.string(default = "_output/coverage"),
        "bazel_args": attr.string_list(),
        "required_commands": attr.string_list(),
        "verify_run_targets": attr.string_list(),
        "verify_test_targets": attr.string_list(),
        "require_git_repo": attr.bool(default = True),
        "_runner": attr.label(cfg = "exec", default = "//tools/source_runner:runner"),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
)
