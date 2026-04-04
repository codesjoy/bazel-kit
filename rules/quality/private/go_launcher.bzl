def _module_dir(path):
    suffix = "/go.mod"
    if path.endswith(suffix):
        return path[:-len(suffix)]
    return path

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

def _shell_tool_vars(tools):
    return [
        "GOFUMPT=%s" % _sh_quote("${RUNFILES_DIR}/" + tools["gofumpt"]),
        "GOIMPORTS=%s" % _sh_quote("${RUNFILES_DIR}/" + tools["goimports"]),
        "GOLINES=%s" % _sh_quote("${RUNFILES_DIR}/" + tools["golines"]),
        "GOLANGCI_LINT=%s" % _sh_quote("${RUNFILES_DIR}/" + tools["golangci_lint"]),
    ]

def _batch_tool_vars(tools):
    return [
        "set \"GOFUMPT=%RUNFILES_DIR%%%s\"" % tools["gofumpt"],
        "set \"GOIMPORTS=%RUNFILES_DIR%%%s\"" % tools["goimports"],
        "set \"GOLINES=%RUNFILES_DIR%%%s\"" % tools["golines"],
        "set \"GOLANGCI_LINT=%RUNFILES_DIR%%%s\"" % tools["golangci_lint"],
    ]

def _fmt_shell_body(files):
    lines = []
    if files:
        lines.append("files=(")
        for path in files:
            lines.append("  %s" % _sh_quote(path))
        lines.append(")")
    else:
        lines.append("mapfile -t files < <(discover_go_files)")
    lines.extend([
        "if [[ ${#files[@]} -eq 0 ]]; then",
        "  warn \"No Go files found to format\"",
        "  exit 0",
        "fi",
        "info \"Formatting Go files with gofumpt\"",
        "for path in \"${files[@]}\"; do",
        "  \"${GOFUMPT}\" -w \"${path}\"",
        "done",
        "info \"Formatting Go files with goimports\"",
        "for path in \"${files[@]}\"; do",
        "  \"${GOIMPORTS}\" -w -local \"${LOCAL_PREFIX}\" \"${path}\"",
        "done",
        "info \"Formatting Go files with golines\"",
        "for path in \"${files[@]}\"; do",
        "  \"${GOLINES}\" -w --max-len=100 \"${path}\"",
        "done",
        "success \"Formatting complete\"",
    ])
    return lines

def _fmt_check_shell_body(files):
    lines = []
    if files:
        lines.append("files=(")
        for path in files:
            lines.append("  %s" % _sh_quote(path))
        lines.append(")")
    else:
        lines.append("mapfile -t files < <(discover_go_files)")
    lines.extend([
        "if [[ ${#files[@]} -eq 0 ]]; then",
        "  warn \"No Go files found to check\"",
        "  exit 0",
        "fi",
        "failed=0",
        "check_output() {",
        "  local label=\"$1\"",
        "  shift",
        "  local output status",
        "  set +e",
        "  output=\"$($@ 2>&1)\"",
        "  status=$?",
        "  set -e",
        "  if [[ ${status} -ne 0 ]]; then",
        "    printf \"%s\\n\" \"${output}\" >&2",
        "    exit ${status}",
        "  fi",
        "  if [[ -n \"${output}\" ]]; then",
        "    error \"${label}\"",
        "    printf \"%s\\n\" \"${output}\" >&2",
        "    failed=1",
        "  fi",
        "}",
        "for path in \"${files[@]}\"; do",
        "  check_output \"gofumpt would reformat ${path}\" \"${GOFUMPT}\" -l \"${path}\"",
        "done",
        "for path in \"${files[@]}\"; do",
        "  check_output \"goimports would reformat ${path}\" \"${GOIMPORTS}\" -l -local \"${LOCAL_PREFIX}\" \"${path}\"",
        "done",
        "for path in \"${files[@]}\"; do",
        "  check_output \"golines would reformat ${path}\" \"${GOLINES}\" -l --dry-run --max-len=100 \"${path}\"",
        "done",
        "if [[ ${failed} -ne 0 ]]; then",
        "  exit 1",
        "fi",
        "success \"Formatting checks passed\"",
    ])
    return lines

def _lint_shell_body(modules):
    lines = [
        "go_cache=\"${TMPDIR:-/tmp}/go-build\"",
        "lint_cache=\"${TMPDIR:-/tmp}/golangci-lint\"",
        "mkdir -p \"${go_cache}\" \"${lint_cache}\"",
    ]
    if modules:
        lines.append("modules=(")
        for module in modules:
            lines.append("  %s" % _sh_quote(module))
        lines.append(")")
    else:
        lines.append("mapfile -t modules < <(discover_go_modules)")
    lines.extend([
        "if [[ ${#modules[@]} -eq 0 ]]; then",
        "  warn \"No Go modules found to lint\"",
        "else",
        "  for module in \"${modules[@]}\"; do",
        "    info \"Linting ${module}\"",
        "    (",
        "      cd \"${module}\"",
        "      GOWORK=off GOCACHE=\"${go_cache}\" GOLANGCI_LINT_CACHE=\"${lint_cache}\" \"${GOLANGCI_LINT}\" run --config \"${workspace}/${LINT_CONFIG}\" ./...",
        "    )",
        "  done",
        "  success \"Go lint passed\"",
        "fi",
    ])
    return lines

def _render_shell(kind, files, modules, local_prefix, config, tools):
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
        "error() { printf 'ERROR %s\\n' \"$*\" >&2; }",
        "success() { printf 'SUCCESS %s\\n' \"$*\" >&2; }",
        "discover_go_files() {",
        "  find . -type f -name '*.go' \\",
        "    -not -path './vendor/*' \\",
        "    -not -path './_output/*' \\",
        "    -not -path './.tmp/*' \\",
        "    -not -path './.git/*' \\",
        "    -not -path './bazel-*/*' \\",
        "    -not -name '*.pb.go' \\",
        "    -not -name '*.pb.gw.go' \\",
        "    -not -name '*.gen.go' \\",
        "    -not -name '*_gen.go' \\",
        "    -not -name '*_generated.go' \\",
        "    -not -name 'zz_generated*.go' | sed 's|^\\./||' | LC_ALL=C sort",
        "}",
        "discover_go_modules() {",
        "  find . -type f -name 'go.mod' \\",
        "    -not -path './vendor/*' \\",
        "    -not -path './_output/*' \\",
        "    -not -path './.tmp/*' \\",
        "    -not -path './.git/*' \\",
        "    -not -path './bazel-*/*' | sed 's|^\\./||' | LC_ALL=C sort | while IFS= read -r path; do dirname \"${path}\"; done",
        "}",
    ]
    lines.extend(_shell_tool_vars(tools))
    lines.append("LOCAL_PREFIX=%s" % _sh_quote(local_prefix))
    if config:
        lines.append("LINT_CONFIG=%s" % _sh_quote(config))

    if kind == "fmt":
        lines.extend(_fmt_shell_body(files))
    elif kind == "fmt_check":
        lines.extend(_fmt_check_shell_body(files))
    elif kind == "lint":
        lines.extend(_lint_shell_body(modules))
    else:
        fail("unsupported kind: %s" % kind)
    return "\n".join(lines) + "\n"

def _fmt_batch_body(files):
    lines = []
    if files:
        file_query = None
        paths = _windows_paths(files)
    else:
        file_query = "powershell -NoProfile -Command \"$ErrorActionPreference='Stop'; Get-ChildItem -Path $env:WORKSPACE -Recurse -File -Filter *.go | Where-Object { $_.FullName -notmatch '\\\\(vendor|_output|\\.tmp|\\.git|bazel-[^\\\\]+)\\\\' -and $_.Name -notmatch '(\\.pb\\.go|\\.pb\\.gw\\.go|\\.gen\\.go|_gen\\.go|_generated\\.go|^zz_generated.*\\.go)$' } | Sort-Object FullName | ForEach-Object { $_.FullName }\""
        paths = []
    lines.extend([
        "set \"FOUND_GO=0\"",
        "echo INFO  Formatting Go files with gofumpt 1>&2",
    ])
    if file_query:
        lines.extend([
            "for /f \"usebackq delims=\" %%F in (`%s`) do (" % file_query,
            "  set \"FOUND_GO=1\"",
            "  \"!GOFUMPT!\" -w \"%%F\"",
            "  if errorlevel 1 exit /b 1",
            ")",
        ])
    else:
        for path in paths:
            lines.extend([
                "set \"FOUND_GO=1\"",
                "\"!GOFUMPT!\" -w %s" % _bat_quote("%WORKSPACE%\\" + path),
                "if errorlevel 1 exit /b 1",
            ])
    lines.extend([
        "if /I \"!FOUND_GO!\"==\"0\" (",
        "  echo WARN  No Go files found to format 1>&2",
        "  exit /b 0",
        ")",
        "echo INFO  Formatting Go files with goimports 1>&2",
    ])
    if file_query:
        lines.extend([
            "for /f \"usebackq delims=\" %%F in (`%s`) do (" % file_query,
            "  \"!GOIMPORTS!\" -w -local \"!LOCAL_PREFIX!\" \"%%F\"",
            "  if errorlevel 1 exit /b 1",
            ")",
            "echo INFO  Formatting Go files with golines 1>&2",
            "for /f \"usebackq delims=\" %%F in (`%s`) do (" % file_query,
            "  \"!GOLINES!\" -w --max-len=100 \"%%F\"",
            "  if errorlevel 1 exit /b 1",
            ")",
        ])
    else:
        for path in paths:
            lines.extend([
                "\"!GOIMPORTS!\" -w -local \"!LOCAL_PREFIX!\" %s" % _bat_quote("%WORKSPACE%\\" + path),
                "if errorlevel 1 exit /b 1",
            ])
        lines.append("echo INFO  Formatting Go files with golines 1>&2")
        for path in paths:
            lines.extend([
                "\"!GOLINES!\" -w --max-len=100 %s" % _bat_quote("%WORKSPACE%\\" + path),
                "if errorlevel 1 exit /b 1",
            ])
    lines.extend([
        "echo SUCCESS Formatting complete 1>&2",
        "exit /b 0",
    ])
    return lines

def _fmt_check_batch_body(files):
    lines = []
    if files:
        file_query = None
        paths = _windows_paths(files)
    else:
        file_query = "powershell -NoProfile -Command \"$ErrorActionPreference='Stop'; Get-ChildItem -Path $env:WORKSPACE -Recurse -File -Filter *.go | Where-Object { $_.FullName -notmatch '\\\\(vendor|_output|\\.tmp|\\.git|bazel-[^\\\\]+)\\\\' -and $_.Name -notmatch '(\\.pb\\.go|\\.pb\\.gw\\.go|\\.gen\\.go|_gen\\.go|_generated\\.go|^zz_generated.*\\.go)$' } | Sort-Object FullName | ForEach-Object { $_.FullName }\""
        paths = []

    lines.extend([
        "set \"FAILED=0\"",
        "set \"TMPFILE=%TEMP%\\quality_go_fmt_check_%RANDOM%.txt\"",
        "set \"FOUND_GO=0\"",
    ])
    if file_query:
        lines.extend([
            "for /f \"usebackq delims=\" %%F in (`%s`) do (" % file_query,
            "  set \"FOUND_GO=1\"",
            "  \"!GOFUMPT!\" -l \"%%F\" > \"!TMPFILE!\" 2>&1",
            "  if errorlevel 1 (",
            "    type \"!TMPFILE!\" 1>&2",
            "    del \"!TMPFILE!\" >NUL 2>&1",
            "    exit /b 1",
            "  )",
            "  for %%A in (\"!TMPFILE!\") do if %%~zA gtr 0 (",
            "    echo ERROR gofumpt would reformat %%F 1>&2",
            "    type \"!TMPFILE!\" 1>&2",
            "    set \"FAILED=1\"",
            "  )",
            ")",
            "for /f \"usebackq delims=\" %%F in (`%s`) do (" % file_query,
            "  \"!GOIMPORTS!\" -l -local \"!LOCAL_PREFIX!\" \"%%F\" > \"!TMPFILE!\" 2>&1",
            "  if errorlevel 1 (",
            "    type \"!TMPFILE!\" 1>&2",
            "    del \"!TMPFILE!\" >NUL 2>&1",
            "    exit /b 1",
            "  )",
            "  for %%A in (\"!TMPFILE!\") do if %%~zA gtr 0 (",
            "    echo ERROR goimports would reformat %%F 1>&2",
            "    type \"!TMPFILE!\" 1>&2",
            "    set \"FAILED=1\"",
            "  )",
            ")",
            "for /f \"usebackq delims=\" %%F in (`%s`) do (" % file_query,
            "  \"!GOLINES!\" -l --dry-run --max-len=100 \"%%F\" > \"!TMPFILE!\" 2>&1",
            "  if errorlevel 1 (",
            "    type \"!TMPFILE!\" 1>&2",
            "    del \"!TMPFILE!\" >NUL 2>&1",
            "    exit /b 1",
            "  )",
            "  for %%A in (\"!TMPFILE!\") do if %%~zA gtr 0 (",
            "    echo ERROR golines would reformat %%F 1>&2",
            "    type \"!TMPFILE!\" 1>&2",
            "    set \"FAILED=1\"",
            "  )",
            ")",
        ])
    else:
        for path in paths:
            abs_path = _bat_quote("%WORKSPACE%\\" + path)
            lines.extend([
                "set \"FOUND_GO=1\"",
                "\"!GOFUMPT!\" -l %s > \"!TMPFILE!\" 2>&1" % abs_path,
                "if errorlevel 1 (",
                "  type \"!TMPFILE!\" 1>&2",
                "  del \"!TMPFILE!\" >NUL 2>&1",
                "  exit /b 1",
                ")",
                "for %%A in (\"!TMPFILE!\") do if %%~zA gtr 0 (",
                "  echo ERROR gofumpt would reformat %s 1>&2" % path,
                "  type \"!TMPFILE!\" 1>&2",
                "  set \"FAILED=1\"",
                ")",
            ])
        for path in paths:
            abs_path = _bat_quote("%WORKSPACE%\\" + path)
            lines.extend([
                "\"!GOIMPORTS!\" -l -local \"!LOCAL_PREFIX!\" %s > \"!TMPFILE!\" 2>&1" % abs_path,
                "if errorlevel 1 (",
                "  type \"!TMPFILE!\" 1>&2",
                "  del \"!TMPFILE!\" >NUL 2>&1",
                "  exit /b 1",
                ")",
                "for %%A in (\"!TMPFILE!\") do if %%~zA gtr 0 (",
                "  echo ERROR goimports would reformat %s 1>&2" % path,
                "  type \"!TMPFILE!\" 1>&2",
                "  set \"FAILED=1\"",
                ")",
            ])
        for path in paths:
            abs_path = _bat_quote("%WORKSPACE%\\" + path)
            lines.extend([
                "\"!GOLINES!\" -l --dry-run --max-len=100 %s > \"!TMPFILE!\" 2>&1" % abs_path,
                "if errorlevel 1 (",
                "  type \"!TMPFILE!\" 1>&2",
                "  del \"!TMPFILE!\" >NUL 2>&1",
                "  exit /b 1",
                ")",
                "for %%A in (\"!TMPFILE!\") do if %%~zA gtr 0 (",
                "  echo ERROR golines would reformat %s 1>&2" % path,
                "  type \"!TMPFILE!\" 1>&2",
                "  set \"FAILED=1\"",
                ")",
            ])
    lines.extend([
        "if /I \"!FOUND_GO!\"==\"0\" (",
        "  del \"!TMPFILE!\" >NUL 2>&1",
        "  echo WARN  No Go files found to check 1>&2",
        "  exit /b 0",
        ")",
        "del \"!TMPFILE!\" >NUL 2>&1",
        "if /I \"!FAILED!\"==\"1\" exit /b 1",
        "echo SUCCESS Formatting checks passed 1>&2",
        "exit /b 0",
    ])
    return lines

def _lint_batch_body(modules):
    lines = [
        "set \"GOCACHE=%TEMP%\\go-build\"",
        "set \"GOLANGCI_LINT_CACHE=%TEMP%\\golangci-lint\"",
        "if not exist \"%GOCACHE%\" mkdir \"%GOCACHE%\"",
        "if not exist \"%GOLANGCI_LINT_CACHE%\" mkdir \"%GOLANGCI_LINT_CACHE%\"",
    ]
    if modules:
        module_query = None
        module_paths = _windows_paths(modules)
    else:
        module_query = "powershell -NoProfile -Command \"$ErrorActionPreference='Stop'; Get-ChildItem -Path $env:WORKSPACE -Recurse -File -Filter go.mod | Where-Object { $_.FullName -notmatch '\\\\(vendor|_output|\\.tmp|\\.git|bazel-[^\\\\]+)\\\\' } | Sort-Object FullName | ForEach-Object { $_.Directory.FullName }\""
        module_paths = []
    lines.extend([
        "set \"FOUND_MODULE=0\"",
    ])
    if module_query:
        lines.extend([
            "for /f \"usebackq delims=\" %%D in (`%s`) do (" % module_query,
            "  set \"FOUND_MODULE=1\"",
            "  echo INFO  Linting %%D 1>&2",
            "  pushd \"%%D\"",
            "  if errorlevel 1 exit /b 1",
            "  set \"GOWORK=off\"",
            "  \"!GOLANGCI_LINT!\" run --config \"!LINT_CONFIG!\" ./...",
            "  if errorlevel 1 (",
            "    popd",
            "    exit /b 1",
            "  )",
            "  popd",
            ")",
        ])
    else:
        for module in module_paths:
            lines.extend([
                "set \"FOUND_MODULE=1\"",
                "echo INFO  Linting %s 1>&2" % module.replace("\\", "/"),
                "pushd %s" % _bat_quote("%WORKSPACE%\\" + module),
                "if errorlevel 1 exit /b 1",
                "set \"GOWORK=off\"",
                "\"!GOLANGCI_LINT!\" run --config \"!LINT_CONFIG!\" ./...",
                "if errorlevel 1 (",
                "  popd",
                "  exit /b 1",
                ")",
                "popd",
            ])
    lines.extend([
        "if /I \"!FOUND_MODULE!\"==\"0\" (",
        "  echo WARN  No Go modules found to lint 1>&2",
        ") else (",
        "  echo SUCCESS Go lint passed 1>&2",
        ")",
        "exit /b 0",
    ])
    return lines

def _render_batch(kind, files, modules, local_prefix, config, tools):
    config_path = config.replace("/", "\\") if config else ""
    lines = [
        "@echo off",
        "setlocal EnableExtensions EnableDelayedExpansion",
        "set \"LAUNCHER_DIR=%~dp0\"",
        "if \"%RUNFILES_DIR%\"==\"\" set \"RUNFILES_DIR=%~dpn0.runfiles\\\"",
        "if \"%BUILD_WORKSPACE_DIRECTORY%\"==\"\" (",
        "  set \"WORKSPACE=%CD%\"",
        ") else (",
        "  set \"WORKSPACE=%BUILD_WORKSPACE_DIRECTORY%\"",
        ")",
        "cd /d \"%WORKSPACE%\"",
    ]
    lines.extend(_batch_tool_vars(tools))
    lines.extend([
        "set \"LOCAL_PREFIX=%s\"" % local_prefix,
    ])
    if config_path:
        lines.append("set \"LINT_CONFIG=%WORKSPACE%\\%s\"" % config_path)
    lines.append("goto :main")
    lines.append("")
    lines.append(":main")
    if kind == "fmt":
        lines.extend(_fmt_batch_body(files))
    elif kind == "fmt_check":
        lines.extend(_fmt_check_batch_body(files))
    elif kind == "lint":
        lines.extend(_lint_batch_body(modules))
    else:
        fail("unsupported kind: %s" % kind)
    return "\r\n".join(lines) + "\r\n"

def _impl(ctx):
    kind = ctx.attr.kind
    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    files = _short_paths(ctx.files.files)
    modules = sorted([_module_dir(path) for path in _short_paths(ctx.files.modules)])
    config = ctx.file.config.short_path if ctx.file.config else None

    tool_files = [
        _tool_file(ctx.attr.tool_gofumpt, "gofumpt"),
        _tool_file(ctx.attr.tool_goimports, "goimports"),
        _tool_file(ctx.attr.tool_golines, "golines"),
        _tool_file(ctx.attr.tool_golangci_lint, "golangci-lint"),
    ]
    tools = {
        "gofumpt": _tool_runfiles_path(tool_files[0], is_windows),
        "goimports": _tool_runfiles_path(tool_files[1], is_windows),
        "golines": _tool_runfiles_path(tool_files[2], is_windows),
        "golangci_lint": _tool_runfiles_path(tool_files[3], is_windows),
    }

    launcher = ctx.actions.declare_file(ctx.label.name + (".bat" if is_windows else ".sh"))
    content = _render_batch(kind, files, modules, ctx.attr.local_prefix, config, tools) if is_windows else _render_shell(kind, files, modules, ctx.attr.local_prefix, config, tools)
    ctx.actions.write(
        output = launcher,
        content = content,
        is_executable = not is_windows,
    )

    inputs = []
    inputs.extend(ctx.files.files)
    inputs.extend(ctx.files.modules)
    if ctx.file.config:
        inputs.append(ctx.file.config)
    inputs.extend(tool_files)

    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = inputs),
    )]

quality_go_runner = rule(
    implementation = _impl,
    executable = True,
    attrs = {
        "kind": attr.string(
            mandatory = True,
            values = ["fmt", "fmt_check", "lint"],
        ),
        "files": attr.label_list(allow_files = True),
        "modules": attr.label_list(allow_files = ["go.mod"]),
        "config": attr.label(allow_single_file = True),
        "local_prefix": attr.string(),
        "tool_gofumpt": attr.label(cfg = "exec", default = "@quality_tool_gofumpt//:tool"),
        "tool_goimports": attr.label(cfg = "exec", default = "@quality_tool_goimports//:tool"),
        "tool_golines": attr.label(cfg = "exec", default = "@quality_tool_golines//:tool"),
        "tool_golangci_lint": attr.label(cfg = "exec", default = "@quality_tool_golangci_lint//:tool"),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
)
