def _short_paths(files):
    return sorted([f.short_path for f in files])

def _project_relative_paths(project_dir, files):
    short_paths = _short_paths(files)
    if project_dir in ["", "."]:
        return short_paths

    prefix = project_dir + "/"
    relative_paths = []
    for path in short_paths:
        if not path.startswith(prefix):
            fail("web quality path %s must be under project_dir %s" % (path, project_dir))
        relative_paths.append(path[len(prefix):])
    return relative_paths

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

def _command_args(kind, paths):
    if kind == "fmt":
        return "\"${BIOME}\" format --write --no-errors-on-unmatched %s" % paths
    if kind == "fmt_check":
        return "\"${BIOME}\" format --no-errors-on-unmatched %s" % paths
    if kind == "lint":
        return "\"${BIOME}\" lint --error-on-warnings --no-errors-on-unmatched %s" % paths
    fail("unsupported kind: %s" % kind)

def _render_shell(kind, project_dir, paths, tool):
    lines = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "launcher_dir=\"$(cd \"$(dirname \"$0\")\" && pwd)\"",
        "runfiles_dir=\"${RUNFILES_DIR:-${launcher_dir}/$(basename \"$0\").runfiles}\"",
        "RUNFILES_DIR=\"${runfiles_dir}\"",
        "workspace=\"${BUILD_WORKSPACE_DIRECTORY:-$(pwd)}\"",
        "PROJECT_DIR=%s" % _sh_quote(project_dir),
        "PROJECT_PATH=\"${workspace}\"",
        "if [[ \"${PROJECT_DIR}\" != \".\" ]]; then",
        "  PROJECT_PATH=\"${workspace}/${PROJECT_DIR}\"",
        "fi",
        "info() { printf 'INFO  %s\\n' \"$*\" >&2; }",
        "warn() { printf 'WARN  %s\\n' \"$*\" >&2; }",
        "success() { printf 'SUCCESS %s\\n' \"$*\" >&2; }",
        "BIOME=%s" % _sh_quote("${RUNFILES_DIR}/" + tool),
        "if [[ ! -d \"${PROJECT_PATH}\" ]]; then",
        "  printf 'ERROR project_dir %s does not exist\\n' \"${PROJECT_DIR}\" >&2",
        "  exit 1",
        "fi",
        "cd \"${PROJECT_PATH}\"",
        "discover_web_files() {",
        "  find . -type f \\(",
        "    -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' -o \\",
        "    -name '*.json' -o -name '*.jsonc' -o -name '*.css' -o -name '*.html'",
        "  \\) \\",
        "    -not -path './node_modules/*' \\",
        "    -not -path './dist/*' \\",
        "    -not -path './coverage/*' \\",
        "    -not -path './.git/*' \\",
        "    -not -path './.pnpm-store/*' \\",
        "    -not -path './bazel-*/*' | sed 's|^\\./||' | LC_ALL=C sort",
        "}",
    ]
    if paths:
        lines.append("paths=(")
        for path in paths:
            lines.append("  %s" % _sh_quote(path))
        lines.append(")")
    else:
        lines.append("mapfile -t paths < <(discover_web_files)")
    lines.extend([
        "if [[ ${#paths[@]} -eq 0 ]]; then",
        "  warn \"No web files found to process\"",
        "  exit 0",
        "fi",
    ])
    if kind == "fmt":
        lines.append("info \"Formatting web files in ${PROJECT_DIR}\"")
    elif kind == "fmt_check":
        lines.append("info \"Checking web formatting in ${PROJECT_DIR}\"")
    else:
        lines.append("info \"Linting web files in ${PROJECT_DIR}\"")
    lines.append(_command_args(kind, "\"${paths[@]}\""))
    if kind == "fmt":
        lines.append("success \"Web formatting complete\"")
    elif kind == "fmt_check":
        lines.append("success \"Web formatting checks passed\"")
    else:
        lines.append("success \"Web lint passed\"")
    return "\n".join(lines) + "\n"

def _render_batch(kind, project_dir, paths, tool):
    project_dir_value = "." if project_dir in ["", "."] else project_dir
    lines = [
        "@echo off",
        "setlocal EnableExtensions EnableDelayedExpansion",
        "if \"%RUNFILES_DIR%\"==\"\" set \"RUNFILES_DIR=%~dpn0.runfiles\\\"",
        "if \"%BUILD_WORKSPACE_DIRECTORY%\"==\"\" (",
        "  set \"WORKSPACE=%CD%\"",
        ") else (",
        "  set \"WORKSPACE=%BUILD_WORKSPACE_DIRECTORY%\"",
        ")",
        "set \"PROJECT_DIR=%s\"" % project_dir_value,
        "set \"PROJECT_PATH=%WORKSPACE%\"",
        "if not \"%PROJECT_DIR%\"==\".\" set \"PROJECT_PATH=%WORKSPACE%\\%PROJECT_DIR%\"",
        "if not exist \"%PROJECT_PATH%\" (",
        "  echo ERROR project_dir %PROJECT_DIR% does not exist 1>&2",
        "  exit /b 1",
        ")",
        "cd /d \"%PROJECT_PATH%\"",
        "set \"BIOME=%RUNFILES_DIR%%%s\"" % tool,
    ]
    if paths:
        quoted_paths = " ".join([_bat_quote(path) for path in _windows_paths(paths)])
        lines.append("set \"WEB_PATHS=%s\"" % quoted_paths)
    else:
        lines.extend([
            "set \"TMPFILE=%TEMP%\\quality_web_paths_%RANDOM%.txt\"",
            "powershell -NoProfile -Command \"$ErrorActionPreference='Stop'; Get-ChildItem -Path $env:PROJECT_PATH -Recurse -File | Where-Object { $_.FullName -notmatch '\\\\(node_modules|dist|coverage|\\.git|\\.pnpm-store|bazel-[^\\\\]+)\\\\' -and @('.js','.jsx','.ts','.tsx','.json','.jsonc','.css','.html') -contains $_.Extension.ToLowerInvariant() } | Sort-Object FullName | ForEach-Object { $_.FullName.Substring($env:PROJECT_PATH.Length + 1).Replace('\\\\', '/') } | Set-Content -Path $env:TMPFILE -Encoding utf8\"",
            "if errorlevel 1 exit /b 1",
            "set \"WEB_PATHS=\"",
            "for /f \"usebackq delims=\" %%F in (\"%TMPFILE%\") do (",
            "  if defined WEB_PATHS (",
            "    set \"WEB_PATHS=!WEB_PATHS! \"%%F\"\"",
            "  ) else (",
            "    set \"WEB_PATHS=\"%%F\"\"",
            "  )",
            ")",
            "del \"%TMPFILE%\" >NUL 2>&1",
        ])
    lines.extend([
        "if not defined WEB_PATHS (",
        "  echo WARN  No web files found to process 1>&2",
        "  exit /b 0",
        ")",
    ])
    if kind == "fmt":
        lines.append("echo INFO  Formatting web files in %PROJECT_DIR% 1>&2")
        lines.append("\"!BIOME!\" format --write --no-errors-on-unmatched !WEB_PATHS!")
        lines.append("if errorlevel 1 exit /b 1")
        lines.append("echo SUCCESS Web formatting complete 1>&2")
    elif kind == "fmt_check":
        lines.append("echo INFO  Checking web formatting in %PROJECT_DIR% 1>&2")
        lines.append("\"!BIOME!\" format --no-errors-on-unmatched !WEB_PATHS!")
        lines.append("if errorlevel 1 exit /b 1")
        lines.append("echo SUCCESS Web formatting checks passed 1>&2")
    else:
        lines.append("echo INFO  Linting web files in %PROJECT_DIR% 1>&2")
        lines.append("\"!BIOME!\" lint --error-on-warnings --no-errors-on-unmatched !WEB_PATHS!")
        lines.append("if errorlevel 1 exit /b 1")
        lines.append("echo SUCCESS Web lint passed 1>&2")
    lines.append("exit /b 0")
    return "\r\n".join(lines) + "\r\n"

def _impl(ctx):
    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    project_dir = ctx.attr.project_dir or "."
    paths = _project_relative_paths(project_dir, ctx.files.paths)

    tool_file = _tool_file(ctx.attr.tool_biome, "biome")
    tool = _tool_runfiles_path(tool_file, is_windows)

    launcher = ctx.actions.declare_file(ctx.label.name + (".bat" if is_windows else ".sh"))
    content = _render_batch(ctx.attr.kind, project_dir, paths, tool) if is_windows else _render_shell(ctx.attr.kind, project_dir, paths, tool)
    ctx.actions.write(
        output = launcher,
        content = content,
        is_executable = not is_windows,
    )

    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = ctx.files.paths + [tool_file]),
    )]

quality_web_runner = rule(
    implementation = _impl,
    executable = True,
    attrs = {
        "kind": attr.string(
            mandatory = True,
            values = ["fmt", "fmt_check", "lint"],
        ),
        "project_dir": attr.string(mandatory = True),
        "paths": attr.label_list(allow_files = True),
        "tool_biome": attr.label(cfg = "exec", default = "@quality_tool_biome//:tool"),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
)
