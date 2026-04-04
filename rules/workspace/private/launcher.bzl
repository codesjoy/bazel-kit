def _module_dir(path):
    suffix = "/go.mod"
    if path.endswith(suffix):
        return path[:-len(suffix)]
    return path

def _short_paths(files):
    return sorted([f.short_path for f in files])

def _sh_quote(value):
    return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

def _bat_quote(value):
    return "\"" + value.replace("\"", "\"\"") + "\""

def _render_shell(modules, go_work, gazelle_target, run_bazel_mod_tidy):
    lines = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
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
        "require_tool \"bazel\"",
        "require_tool \"go\"",
        "discover_go_modules() {",
        "  find . -type f -name 'go.mod' \\",
        "    -not -path './vendor/*' \\",
        "    -not -path './_output/*' \\",
        "    -not -path './.tmp/*' \\",
        "    -not -path './.git/*' \\",
        "    -not -path './bazel-*/*' | sed 's|^\\./||' | LC_ALL=C sort | while IFS= read -r path; do dirname \"${path}\"; done",
        "}",
    ]
    if modules:
        lines.append("modules=(")
        for module in modules:
            lines.append("  %s" % _sh_quote(module))
        lines.append(")")
    else:
        lines.append("mapfile -t modules < <(discover_go_modules)")
    lines.extend([
        "set +e",
        "goversion=\"$(go env GOVERSION 2>/dev/null)\"",
        "status=$?",
        "set -e",
        "if [[ ${status} -ne 0 || -z \"${goversion}\" ]]; then",
        "  goversion=\"$(go version | awk '{print $3}')\"",
        "fi",
        "goversion=\"${goversion#go}\"",
        "info \"Writing go.work for ${#modules[@]} module(s)\"",
        "{",
        "  printf 'go %s\\n\\n' \"${goversion}\"",
        "  printf 'use (\\n'",
        "  for module in \"${modules[@]}\"; do",
        "    printf '    ./%s\\n' \"${module}\"",
        "  done",
        "  printf ')\\n'",
        "} > %s" % _sh_quote(go_work),
        "success \"go.work synced\"",
    ])
    if run_bazel_mod_tidy:
        lines.extend([
            "info \"Tidying Bazel module dependencies\"",
            "bazel mod tidy",
        ])
    if gazelle_target:
        lines.extend([
            "info \"Running %s\"" % gazelle_target,
            "bazel run %s" % _sh_quote(gazelle_target),
        ])
    lines.append("success \"Workspace sync complete\"")
    return "\n".join(lines) + "\n"

def _render_batch(modules, go_work, gazelle_target, run_bazel_mod_tidy):
    lines = [
        "@echo off",
        "setlocal EnableExtensions EnableDelayedExpansion",
        "if \"%BUILD_WORKSPACE_DIRECTORY%\"==\"\" (",
        "  set \"WORKSPACE=%CD%\"",
        ") else (",
        "  set \"WORKSPACE=%BUILD_WORKSPACE_DIRECTORY%\"",
        ")",
        "cd /d \"%WORKSPACE%\"",
        "goto :main",
        "",
        ":require_tool",
        "where %~1 >NUL 2>&1",
        "if errorlevel 1 (",
        "  echo ERROR required tool '%~1' not found in PATH 1>&2",
        "  exit /b 1",
        ")",
        "exit /b 0",
        "",
        ":main",
        "call :require_tool bazel || exit /b 1",
        "call :require_tool go || exit /b 1",
    ]
    if modules:
        module_lines = ["'go !GOVERSION!'", "''", "'use ('"]
        for module in modules:
            module_lines.append("'    ./%s'" % module)
        module_lines.append("')'")
    else:
        module_lines = None
    lines.extend([
        "for /f %%I in ('go env GOVERSION 2^>NUL') do set \"GOVERSION=%%I\"",
        "if not defined GOVERSION for /f \"tokens=3\" %%I in ('go version') do set \"GOVERSION=%%I\"",
        "if not defined GOVERSION (",
        "  echo ERROR unable to determine Go version 1>&2",
        "  exit /b 1",
        ")",
        "set \"GOVERSION=!GOVERSION:~2!\"",
        "echo INFO  Writing go.work 1>&2",
    ])
    if module_lines:
        lines.append("powershell -NoProfile -Command \"$lines = @(%s); [System.IO.File]::WriteAllText((Join-Path $env:WORKSPACE %s), (($lines -join \\\"`n\\\") + \\\"`n\\\"), (New-Object System.Text.UTF8Encoding($false)))\"" % (", ".join(module_lines), _bat_quote(go_work)))
    else:
        lines.append("powershell -NoProfile -Command \"$ErrorActionPreference='Stop'; $modules = Get-ChildItem -Path $env:WORKSPACE -Recurse -File -Filter go.mod | Where-Object { $_.FullName -notmatch '\\\\(vendor|_output|\\.tmp|\\.git|bazel-[^\\\\]+)\\\\' } | ForEach-Object { $_.Directory.FullName.Substring($env:WORKSPACE.Length + 1).Replace('\\\\', '/') } | Sort-Object; $lines = @('go ' + $env:GOVERSION, '', 'use (') + ($modules | ForEach-Object { '    ./' + $_ }) + @(')'); [System.IO.File]::WriteAllText((Join-Path $env:WORKSPACE %s), (($lines -join \\\"`n\\\") + \\\"`n\\\"), (New-Object System.Text.UTF8Encoding($false)))\"" % _bat_quote(go_work))
    lines.extend([
        "if errorlevel 1 exit /b 1",
        "echo SUCCESS go.work synced 1>&2",
    ])
    if run_bazel_mod_tidy:
        lines.extend([
            "echo INFO  Tidying Bazel module dependencies 1>&2",
            "bazel mod tidy",
            "if errorlevel 1 exit /b 1",
        ])
    if gazelle_target:
        lines.extend([
            "echo INFO  Running %s 1>&2" % gazelle_target,
            "bazel run %s" % gazelle_target,
            "if errorlevel 1 exit /b 1",
        ])
    lines.extend([
        "echo SUCCESS Workspace sync complete 1>&2",
        "exit /b 0",
    ])
    return "\r\n".join(lines) + "\r\n"

def _impl(ctx):
    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    modules = sorted([_module_dir(path) for path in _short_paths(ctx.files.modules)])
    go_work = ctx.file.go_work.short_path if ctx.file.go_work else "go.work"
    gazelle_target = str(ctx.attr.gazelle_target.label) if ctx.attr.gazelle_target else None

    launcher = ctx.actions.declare_file(ctx.label.name + (".bat" if is_windows else ".sh"))
    content = _render_batch(modules, go_work, gazelle_target, ctx.attr.run_bazel_mod_tidy) if is_windows else _render_shell(modules, go_work, gazelle_target, ctx.attr.run_bazel_mod_tidy)
    ctx.actions.write(
        output = launcher,
        content = content,
        is_executable = not is_windows,
    )

    inputs = []
    inputs.extend(ctx.files.modules)
    if ctx.file.go_work:
        inputs.append(ctx.file.go_work)
    if ctx.attr.gazelle_target:
        inputs.extend(ctx.attr.gazelle_target[DefaultInfo].default_runfiles.files.to_list())
        inputs.extend(ctx.attr.gazelle_target[DefaultInfo].files.to_list())

    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = inputs),
    )]

workspace_sync_runner = rule(
    implementation = _impl,
    executable = True,
    attrs = {
        "modules": attr.label_list(allow_files = ["go.mod"]),
        "go_work": attr.label(allow_single_file = True),
        "gazelle_target": attr.label(executable = True, cfg = "exec"),
        "run_bazel_mod_tidy": attr.bool(default = True),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
)

