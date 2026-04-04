def _dir_of(path):
    index = path.rfind("/")
    if index == -1:
        return "."
    return path[:index]

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

def _tool_runfiles_path(file, is_windows):
    path = file.path
    if path.startswith("external/"):
        runfiles_path = path[len("external/"):]
    else:
        runfiles_path = "_main/" + file.short_path
    return runfiles_path.replace("/", "\\") if is_windows else runfiles_path

def _default_against(remote, branch, input_path):
    against = ".git#branch=%s,ref=refs/remotes/%s/%s" % (branch, remote, branch)
    if input_path != ".":
        against += ",subdir=%s" % input_path
    return against

def _render_shell(kind, input_path, files, template, against, against_git_remote, against_git_branch, tools):
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
        "require_tool() {",
        "  if ! command -v \"$1\" >/dev/null 2>&1; then",
        "    printf \"ERROR required tool '%s' not found in PATH\\n\" \"$1\" >&2",
        "    exit 1",
        "  fi",
        "}",
        "BUF=%s" % _sh_quote("${RUNFILES_DIR}/" + tools["buf"]),
        "INPUT_PATH=%s" % _sh_quote(input_path),
    ]

    if kind == "format":
        if files:
            for path in files:
                lines.extend([
                    "info \"Formatting %s\"" % path,
                    "\"${BUF}\" format %s -w" % _sh_quote(path),
                ])
        else:
            lines.extend([
                "info \"Formatting ${INPUT_PATH}\"",
                "\"${BUF}\" format \"${INPUT_PATH}\" -w",
            ])
        lines.append("success \"Buf format complete\"")
    elif kind == "format_check":
        if files:
            for path in files:
                lines.extend([
                    "info \"Checking format for %s\"" % path,
                    "\"${BUF}\" format %s -d --exit-code" % _sh_quote(path),
                ])
        else:
            lines.extend([
                "info \"Checking format for ${INPUT_PATH}\"",
                "\"${BUF}\" format \"${INPUT_PATH}\" -d --exit-code",
            ])
        lines.append("success \"Buf formatting checks passed\"")
    elif kind == "lint":
        lines.extend([
            "info \"Linting ${INPUT_PATH}\"",
            "\"${BUF}\" lint \"${INPUT_PATH}\"",
            "success \"Buf lint passed\"",
        ])
    elif kind == "breaking":
        if against:
            lines.append("AGAINST=%s" % _sh_quote(against))
        else:
            lines.extend([
                "require_tool \"git\"",
                "AGAINST=%s" % _sh_quote(_default_against(against_git_remote, against_git_branch, input_path)),
            ])
        lines.extend([
            "info \"Checking breaking changes for ${INPUT_PATH}\"",
            "\"${BUF}\" breaking \"${INPUT_PATH}\" --against \"${AGAINST}\"",
            "success \"Buf breaking check passed\"",
        ])
    elif kind == "generate":
        lines.extend([
            "TEMPLATE=%s" % _sh_quote(template),
            "info \"Generating code for ${INPUT_PATH}\"",
            "\"${BUF}\" generate \"${INPUT_PATH}\" --template \"${TEMPLATE}\"",
            "success \"Buf generate complete\"",
        ])
    elif kind == "dep_update":
        lines.extend([
            "info \"Updating Buf dependencies for ${INPUT_PATH}\"",
            "\"${BUF}\" dep update \"${INPUT_PATH}\"",
            "success \"Buf dependency update complete\"",
        ])
    else:
        fail("unsupported kind: %s" % kind)

    return "\n".join(lines) + "\n"

def _render_batch(kind, input_path, files, template, against, against_git_remote, against_git_branch, tools):
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
        "set \"BUF=%RUNFILES_DIR%%%s\"" % tools["buf"],
        "set \"INPUT_PATH=%s\"" % input_path,
    ]

    if kind == "format":
        if files:
            for path in _windows_paths(files):
                lines.extend([
                    "echo INFO  Formatting %s 1>&2" % path,
                    "\"!BUF!\" format %s -w" % _bat_quote(path),
                    "if errorlevel 1 exit /b 1",
                ])
        else:
            lines.extend([
                "echo INFO  Formatting !INPUT_PATH! 1>&2",
                "\"!BUF!\" format \"!INPUT_PATH!\" -w",
                "if errorlevel 1 exit /b 1",
            ])
        lines.append("echo SUCCESS Buf format complete 1>&2")
    elif kind == "format_check":
        if files:
            for path in _windows_paths(files):
                lines.extend([
                    "echo INFO  Checking format for %s 1>&2" % path,
                    "\"!BUF!\" format %s -d --exit-code" % _bat_quote(path),
                    "if errorlevel 1 exit /b 1",
                ])
        else:
            lines.extend([
                "echo INFO  Checking format for !INPUT_PATH! 1>&2",
                "\"!BUF!\" format \"!INPUT_PATH!\" -d --exit-code",
                "if errorlevel 1 exit /b 1",
            ])
        lines.append("echo SUCCESS Buf formatting checks passed 1>&2")
    elif kind == "lint":
        lines.extend([
            "echo INFO  Linting !INPUT_PATH! 1>&2",
            "\"!BUF!\" lint \"!INPUT_PATH!\"",
            "if errorlevel 1 exit /b 1",
            "echo SUCCESS Buf lint passed 1>&2",
        ])
    elif kind == "breaking":
        if against:
            lines.append("set \"AGAINST=%s\"" % against)
        else:
            default_against = _default_against(against_git_remote, against_git_branch, input_path)
            lines.extend([
                "where git >NUL 2>&1",
                "if errorlevel 1 (",
                "  echo ERROR required tool 'git' not found in PATH 1>&2",
                "  exit /b 1",
                ")",
                "set \"AGAINST=%s\"" % default_against,
            ])
        lines.extend([
            "echo INFO  Checking breaking changes for !INPUT_PATH! 1>&2",
            "\"!BUF!\" breaking \"!INPUT_PATH!\" --against \"!AGAINST!\"",
            "if errorlevel 1 exit /b 1",
            "echo SUCCESS Buf breaking check passed 1>&2",
        ])
    elif kind == "generate":
        lines.extend([
            "set \"TEMPLATE=%s\"" % template,
            "echo INFO  Generating code for !INPUT_PATH! 1>&2",
            "\"!BUF!\" generate \"!INPUT_PATH!\" --template \"!TEMPLATE!\"",
            "if errorlevel 1 exit /b 1",
            "echo SUCCESS Buf generate complete 1>&2",
        ])
    elif kind == "dep_update":
        lines.extend([
            "echo INFO  Updating Buf dependencies for !INPUT_PATH! 1>&2",
            "\"!BUF!\" dep update \"!INPUT_PATH!\"",
            "if errorlevel 1 exit /b 1",
            "echo SUCCESS Buf dependency update complete 1>&2",
        ])
    else:
        fail("unsupported kind: %s" % kind)

    lines.extend([
        "exit /b 0",
    ])
    return "\r\n".join(lines) + "\r\n"

def _impl(ctx):
    kind = ctx.attr.kind
    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    config_path = ctx.file.config.short_path
    input_path = _dir_of(config_path)
    files = _short_paths(ctx.files.files)
    template = ctx.file.template.short_path if ctx.file.template else ""

    tool_file = _tool_file(ctx.attr.tool_buf, "buf")
    tools = {
        "buf": _tool_runfiles_path(tool_file, is_windows),
    }

    launcher = ctx.actions.declare_file(ctx.label.name + (".bat" if is_windows else ".sh"))
    content = _render_batch(
        kind,
        input_path,
        files,
        template,
        ctx.attr.against,
        ctx.attr.against_git_remote,
        ctx.attr.against_git_branch,
        tools,
    ) if is_windows else _render_shell(
        kind,
        input_path,
        files,
        template,
        ctx.attr.against,
        ctx.attr.against_git_remote,
        ctx.attr.against_git_branch,
        tools,
    )
    ctx.actions.write(
        output = launcher,
        content = content,
        is_executable = not is_windows,
    )

    inputs = [ctx.file.config, tool_file]
    inputs.extend(ctx.files.files)
    if ctx.file.template:
        inputs.append(ctx.file.template)

    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = inputs),
    )]

protobuf_buf_runner = rule(
    implementation = _impl,
    executable = True,
    attrs = {
        "kind": attr.string(
            mandatory = True,
            values = ["format", "format_check", "lint", "breaking", "generate", "dep_update"],
        ),
        "config": attr.label(allow_single_file = True, mandatory = True),
        "files": attr.label_list(allow_files = [".proto"]),
        "template": attr.label(allow_single_file = True),
        "against": attr.string(),
        "against_git_remote": attr.string(default = "origin"),
        "against_git_branch": attr.string(default = "main"),
        "tool_buf": attr.label(cfg = "exec", default = "@protobuf_tool_buf//:tool"),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
)
