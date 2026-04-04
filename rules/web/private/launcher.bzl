def _sh_quote(value):
    return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

def _bat_quote(value):
    return "\"" + value.replace("\"", "\"\"") + "\""

def _tool_named_file(dep, suffix, name):
    matches = []
    for file in dep[DefaultInfo].files.to_list():
        if file.path.endswith("/" + suffix) or file.path.endswith("\\" + suffix) or file.basename == suffix:
            matches.append(file)
    if len(matches) != 1:
        fail("expected a single file ending with %s for tool %s, got %d" % (suffix, name, len(matches)))
    return matches[0]

def _tool_runfiles_path(file, is_windows):
    path = file.path
    if path.startswith("external/"):
        runfiles_path = path[len("external/"):]
    else:
        runfiles_path = "_main/" + file.short_path
    return runfiles_path.replace("/", "\\") if is_windows else runfiles_path

def _init_script_lines():
    return [
        "import { existsSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';",
        "import { dirname, join } from 'node:path';",
        "",
        "const workspace = process.env.WEB_INIT_WORKSPACE;",
        "const projectDir = process.env.WEB_INIT_PROJECT_DIR;",
        "const packageName = process.env.WEB_INIT_PACKAGE_NAME;",
        "",
        "if (!workspace || !projectDir || !packageName) {",
        "  throw new Error('missing init environment');",
        "}",
        "",
        "const projectPath = projectDir === '.' ? workspace : join(workspace, ...projectDir.split('/'));",
        "if (existsSync(projectPath) && readdirSync(projectPath).length > 0) {",
        "  throw new Error(`project_dir ${projectDir} already exists and is not empty`);",
        "}",
        "",
        "const write = (relativePath, content) => {",
        "  const filePath = join(projectPath, relativePath);",
        "  mkdirSync(dirname(filePath), { recursive: true });",
        "  writeFileSync(filePath, content);",
        "};",
        "",
        "mkdirSync(projectPath, { recursive: true });",
        "",
        "const files = {",
        "  'package.json': `{\n  \"name\": \"${packageName}\",\n  \"version\": \"0.1.0\",\n  \"private\": true,\n  \"type\": \"module\",\n  \"scripts\": {\n    \"dev\": \"vite dev\",\n    \"build\": \"vite build\",\n    \"preview\": \"vite preview\",\n    \"typecheck\": \"tsc --noEmit\",\n    \"test\": \"vitest run\",\n    \"test:watch\": \"vitest\",\n    \"e2e\": \"playwright test\",\n    \"lint\": \"biome lint --error-on-warnings .\",\n    \"format\": \"biome format --write .\"\n  },\n  \"devDependencies\": {\n    \"@biomejs/biome\": \"2.4.10\",\n    \"@playwright/test\": \"1.59.1\",\n    \"typescript\": \"6.0.2\",\n    \"vite\": \"8.0.3\",\n    \"vitest\": \"4.1.2\"\n  }\n}\n`,",
        "  'biome.json': `{\n  \"$schema\": \"https://biomejs.dev/schemas/2.4.10/schema.json\",\n  \"files\": {\n    \"ignoreUnknown\": true,\n    \"includes\": [\"**\", \"!dist\", \"!coverage\", \"!node_modules\"]\n  },\n  \"formatter\": {\n    \"enabled\": true,\n    \"indentStyle\": \"space\",\n    \"lineWidth\": 100\n  },\n  \"linter\": {\n    \"enabled\": true,\n    \"rules\": {\n      \"recommended\": true\n    }\n  }\n}\n`,",
        "  'tsconfig.json': `{\n  \"compilerOptions\": {\n    \"target\": \"ES2022\",\n    \"useDefineForClassFields\": true,\n    \"module\": \"ESNext\",\n    \"moduleResolution\": \"Bundler\",\n    \"strict\": true,\n    \"jsx\": \"preserve\",\n    \"resolveJsonModule\": true,\n    \"isolatedModules\": true,\n    \"esModuleInterop\": true,\n    \"lib\": [\"ES2022\", \"DOM\", \"DOM.Iterable\"],\n    \"noEmit\": true,\n    \"types\": [\"vitest/globals\"]\n  },\n  \"include\": [\"src\", \"tests\", \"vite.config.ts\", \"vitest.config.ts\", \"playwright.config.ts\"]\n}\n`,",
        "  'vite.config.ts': `import { defineConfig } from \"vite\";\n\nexport default defineConfig({\n  server: {\n    host: \"0.0.0.0\",\n    port: 4173,\n  },\n  preview: {\n    host: \"0.0.0.0\",\n    port: 4173,\n  },\n});\n`,",
        "  'vitest.config.ts': `import { defineConfig } from \"vitest/config\";\n\nexport default defineConfig({\n  test: {\n    include: [\"tests/**/*.test.ts\"],\n  },\n});\n`,",
        "  'playwright.config.ts': `import { defineConfig } from \"@playwright/test\";\n\nexport default defineConfig({\n  testDir: \"./e2e\",\n  use: {\n    baseURL: \"http://127.0.0.1:4173\",\n  },\n  webServer: {\n    command: \"pnpm exec vite --host 127.0.0.1 --port 4173\",\n    url: \"http://127.0.0.1:4173\",\n    reuseExistingServer: !process.env.CI,\n  },\n});\n`,",
        "  'index.html': `<!doctype html>\n<html lang=\"en\">\n  <head>\n    <meta charset=\"UTF-8\" />\n    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n    <title>${packageName}</title>\n  </head>\n  <body>\n    <div id=\"app\"></div>\n    <script type=\"module\" src=\"/src/main.ts\"></script>\n  </body>\n</html>\n`,",
        "  'src/counter.ts': `export function nextCount(current: number): number {\n  return current + 1;\n}\n\nexport function mountCounter(button: HTMLButtonElement): void {\n  let count = 0;\n\n  const render = () => {\n    button.textContent = \"count is \" + count;\n  };\n\n  button.addEventListener(\"click\", () => {\n    count = nextCount(count);\n    render();\n  });\n\n  render();\n}\n`,",
        "  'src/main.ts': `import \"./style.css\";\nimport { mountCounter } from \"./counter\";\n\nconst app = document.querySelector<HTMLDivElement>(\"#app\");\n\nif (app) {\n  app.innerHTML = \"<button id=\\\"counter\\\" type=\\\"button\\\"></button>\";\n  const button = app.querySelector<HTMLButtonElement>(\"#counter\");\n  if (button) {\n    mountCounter(button);\n  }\n}\n`,",
        "  'src/style.css': `:root {\n  color: #111827;\n  font-family: \"Helvetica Neue\", sans-serif;\n  background: linear-gradient(180deg, #f8fafc 0%, #e2e8f0 100%);\n}\n\nbody {\n  margin: 0;\n  min-height: 100vh;\n}\n\n#app {\n  display: grid;\n  min-height: 100vh;\n  place-items: center;\n}\n\nbutton {\n  border: 0;\n  border-radius: 999px;\n  background: #0f172a;\n  color: #f8fafc;\n  cursor: pointer;\n  font-size: 1rem;\n  padding: 0.85rem 1.4rem;\n}\n`,",
        "  'tests/counter.test.ts': `import { describe, expect, it } from \"vitest\";\n\nimport { nextCount } from \"../src/counter\";\n\ndescribe(\"nextCount\", () => {\n  it(\"increments by one\", () => {\n    expect(nextCount(0)).toBe(1);\n  });\n});\n`,",
        "  'e2e/app.spec.ts': `import { expect, test } from \"@playwright/test\";\n\ntest(\"counter increments\", async ({ page }) => {\n  await page.goto(\"/\");\n  const button = page.getByRole(\"button\");\n  await expect(button).toHaveText(\"count is 0\");\n  await button.click();\n  await expect(button).toHaveText(\"count is 1\");\n});\n`,",
        "};",
        "",
        "for (const [relativePath, content] of Object.entries(files)) {",
        "  write(relativePath, content);",
        "}",
        "",
        "const workspaceFilePath = join(workspace, 'pnpm-workspace.yaml');",
        "if (projectDir.includes('/') && !existsSync(workspaceFilePath)) {",
        "  writeFileSync(workspaceFilePath, `packages:\\n  - '${projectDir}'\\n`);",
        "}",
    ]

def _render_shell(kind, project_dir, package_name, node, pnpm):
    lines = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "launcher_dir=\"$(cd \"$(dirname \"$0\")\" && pwd)\"",
        "runfiles_dir=\"${RUNFILES_DIR:-${launcher_dir}/$(basename \"$0\").runfiles}\"",
        "RUNFILES_DIR=\"${runfiles_dir}\"",
        "workspace=\"${BUILD_WORKSPACE_DIRECTORY:-$(pwd)}\"",
        "PROJECT_DIR=%s" % _sh_quote(project_dir),
        "PACKAGE_NAME=%s" % _sh_quote(package_name),
        "PROJECT_PATH=\"${workspace}\"",
        "if [[ \"${PROJECT_DIR}\" != \".\" ]]; then",
        "  PROJECT_PATH=\"${workspace}/${PROJECT_DIR}\"",
        "fi",
        "PNPM_STORE_DIR=\"${workspace}/.pnpm-store\"",
        "PLAYWRIGHT_BROWSERS_PATH=\"${workspace}/.playwright-browsers\"",
        "NODE=%s" % _sh_quote("${RUNFILES_DIR}/" + node),
        "PNPM=%s" % _sh_quote("${RUNFILES_DIR}/" + pnpm),
        "PATH=\"$(dirname \"${NODE}\"):${PATH}\"",
        "info() { printf 'INFO  %s\\n' \"$*\" >&2; }",
        "error() { printf 'ERROR %s\\n' \"$*\" >&2; }",
        "success() { printf 'SUCCESS %s\\n' \"$*\" >&2; }",
        "require_project_dir() {",
        "  if [[ ! -d \"${PROJECT_PATH}\" ]]; then",
        "    error \"project_dir ${PROJECT_DIR} does not exist\"",
        "    exit 1",
        "  fi",
        "}",
        "require_project_file() {",
        "  local relative_path=\"$1\"",
        "  if [[ ! -f \"${PROJECT_PATH}/${relative_path}\" ]]; then",
        "    error \"required file ${relative_path} not found in ${PROJECT_DIR}\"",
        "    exit 1",
        "  fi",
        "}",
        "run_pnpm() {",
        "  \"${NODE}\" \"${PNPM}\" --dir \"${PROJECT_PATH}\" --store-dir \"${PNPM_STORE_DIR}\" \"$@\"",
        "}",
    ]

    if kind == "init":
        lines.extend([
            "info \"Initializing web project in ${PROJECT_DIR}\"",
            "INIT_SCRIPT=\"${TMPDIR:-/tmp}/web_init_${RANDOM}_$$.mjs\"",
            "trap 'rm -f \"${INIT_SCRIPT}\"' EXIT",
            "cat > \"${INIT_SCRIPT}\" <<'EOF'",
        ])
        lines.extend(_init_script_lines())
        lines.extend([
            "EOF",
            "WEB_INIT_WORKSPACE=\"${workspace}\" WEB_INIT_PROJECT_DIR=\"${PROJECT_DIR}\" WEB_INIT_PACKAGE_NAME=\"${PACKAGE_NAME}\" \"${NODE}\" \"${INIT_SCRIPT}\"",
            "success \"Web project initialized\"",
        ])
        return "\n".join(lines) + "\n"

    lines.extend([
        "require_project_dir",
        "require_project_file \"package.json\"",
        "mkdir -p \"${PNPM_STORE_DIR}\"",
        "export PLAYWRIGHT_BROWSERS_PATH",
    ])

    if kind == "install":
        lines.extend([
            "info \"Installing web dependencies in ${PROJECT_DIR}\"",
            "if [[ -f \"${PROJECT_PATH}/pnpm-lock.yaml\" ]]; then",
            "  run_pnpm install --frozen-lockfile",
            "else",
            "  run_pnpm install",
            "fi",
            "success \"Web dependencies installed\"",
        ])
    elif kind == "dev":
        lines.extend([
            "info \"Starting Vite dev server for ${PROJECT_DIR}\"",
            "run_pnpm exec vite dev --host 0.0.0.0",
        ])
    elif kind == "build":
        lines.extend([
            "info \"Building web project in ${PROJECT_DIR}\"",
            "run_pnpm exec vite build",
            "success \"Web build complete\"",
        ])
    elif kind == "preview":
        lines.extend([
            "info \"Starting Vite preview for ${PROJECT_DIR}\"",
            "run_pnpm exec vite preview --host 0.0.0.0",
        ])
    elif kind == "typecheck":
        lines.extend([
            "require_project_file \"tsconfig.json\"",
            "info \"Type checking ${PROJECT_DIR}\"",
            "run_pnpm exec tsc --noEmit",
            "success \"Web typecheck passed\"",
        ])
    elif kind == "test":
        lines.extend([
            "require_project_file \"vitest.config.ts\"",
            "info \"Running unit tests for ${PROJECT_DIR}\"",
            "run_pnpm exec vitest run",
            "success \"Web unit tests passed\"",
        ])
    elif kind == "browser_install":
        lines.extend([
            "require_project_file \"playwright.config.ts\"",
            "mkdir -p \"${PLAYWRIGHT_BROWSERS_PATH}\"",
            "info \"Installing Playwright browsers for ${PROJECT_DIR}\"",
            "run_pnpm exec playwright install",
            "success \"Playwright browsers installed\"",
        ])
    elif kind == "e2e":
        lines.extend([
            "require_project_file \"playwright.config.ts\"",
            "if [[ ! -d \"${PLAYWRIGHT_BROWSERS_PATH}\" ]] || [[ -z \"$(find \"${PLAYWRIGHT_BROWSERS_PATH}\" -mindepth 1 -print -quit 2>/dev/null)\" ]]; then",
            "  error \"Playwright browsers not installed; run web_browser_install first\"",
            "  exit 1",
            "fi",
            "info \"Running Playwright tests for ${PROJECT_DIR}\"",
            "run_pnpm exec playwright test",
            "success \"Web e2e tests passed\"",
        ])
    else:
        fail("unsupported kind: %s" % kind)

    return "\n".join(lines) + "\n"

def _render_batch(kind, project_dir, package_name, node, pnpm):
    project_dir_value = "." if project_dir in ["", "."] else project_dir
    package_name_value = package_name
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
        "set \"PACKAGE_NAME=%s\"" % package_name_value,
        "set \"PROJECT_PATH=%WORKSPACE%\"",
        "if not \"%PROJECT_DIR%\"==\".\" set \"PROJECT_PATH=%WORKSPACE%\\%PROJECT_DIR%\"",
        "set \"PNPM_STORE_DIR=%WORKSPACE%\\.pnpm-store\"",
        "set \"PLAYWRIGHT_BROWSERS_PATH=%WORKSPACE%\\.playwright-browsers\"",
        "set \"NODE=%RUNFILES_DIR%%%s\"" % node,
        "set \"PNPM=%RUNFILES_DIR%%%s\"" % pnpm,
        "for %%I in (\"!NODE!\") do set \"NODE_DIR=%%~dpI\"",
        "set \"PATH=!NODE_DIR!;%PATH%\"",
    ]

    if kind == "init":
        lines.extend([
            "echo INFO  Initializing web project in %PROJECT_DIR% 1>&2",
            "set \"INIT_SCRIPT=%TEMP%\\web_init_%RANDOM%.mjs\"",
            "powershell -NoProfile -Command \"$content = @'",
        ])
        lines.extend(_init_script_lines())
        lines.extend([
            "'@; [System.IO.File]::WriteAllText($env:INIT_SCRIPT, $content, (New-Object System.Text.UTF8Encoding($false)))\"",
            "if errorlevel 1 exit /b 1",
            "set \"WEB_INIT_WORKSPACE=%WORKSPACE%\"",
            "set \"WEB_INIT_PROJECT_DIR=%PROJECT_DIR%\"",
            "set \"WEB_INIT_PACKAGE_NAME=%PACKAGE_NAME%\"",
            "\"!NODE!\" \"!INIT_SCRIPT!\"",
            "set \"STATUS=!ERRORLEVEL!\"",
            "del \"!INIT_SCRIPT!\" >NUL 2>&1",
            "if not \"!STATUS!\"==\"0\" exit /b !STATUS!",
            "echo SUCCESS Web project initialized 1>&2",
            "exit /b 0",
        ])
        return "\r\n".join(lines) + "\r\n"

    lines.extend([
        "if not exist \"!PROJECT_PATH!\" (",
        "  echo ERROR project_dir %PROJECT_DIR% does not exist 1>&2",
        "  exit /b 1",
        ")",
        "if not exist \"!PROJECT_PATH!\\package.json\" (",
        "  echo ERROR required file package.json not found in %PROJECT_DIR% 1>&2",
        "  exit /b 1",
        ")",
        "if not exist \"!PNPM_STORE_DIR!\" mkdir \"!PNPM_STORE_DIR!\" >NUL 2>&1",
    ])

    if kind == "install":
        lines.extend([
            "echo INFO  Installing web dependencies in %PROJECT_DIR% 1>&2",
            "if exist \"!PROJECT_PATH!\\pnpm-lock.yaml\" (",
            "  \"!NODE!\" \"!PNPM!\" --dir \"!PROJECT_PATH!\" --store-dir \"!PNPM_STORE_DIR!\" install --frozen-lockfile",
            ") else (",
            "  \"!NODE!\" \"!PNPM!\" --dir \"!PROJECT_PATH!\" --store-dir \"!PNPM_STORE_DIR!\" install",
            ")",
            "if errorlevel 1 exit /b 1",
            "echo SUCCESS Web dependencies installed 1>&2",
        ])
    elif kind == "dev":
        lines.extend([
            "echo INFO  Starting Vite dev server for %PROJECT_DIR% 1>&2",
            "\"!NODE!\" \"!PNPM!\" --dir \"!PROJECT_PATH!\" --store-dir \"!PNPM_STORE_DIR!\" exec vite dev --host 0.0.0.0",
            "if errorlevel 1 exit /b 1",
        ])
    elif kind == "build":
        lines.extend([
            "echo INFO  Building web project in %PROJECT_DIR% 1>&2",
            "\"!NODE!\" \"!PNPM!\" --dir \"!PROJECT_PATH!\" --store-dir \"!PNPM_STORE_DIR!\" exec vite build",
            "if errorlevel 1 exit /b 1",
            "echo SUCCESS Web build complete 1>&2",
        ])
    elif kind == "preview":
        lines.extend([
            "echo INFO  Starting Vite preview for %PROJECT_DIR% 1>&2",
            "\"!NODE!\" \"!PNPM!\" --dir \"!PROJECT_PATH!\" --store-dir \"!PNPM_STORE_DIR!\" exec vite preview --host 0.0.0.0",
            "if errorlevel 1 exit /b 1",
        ])
    elif kind == "typecheck":
        lines.extend([
            "if not exist \"!PROJECT_PATH!\\tsconfig.json\" (",
            "  echo ERROR required file tsconfig.json not found in %PROJECT_DIR% 1>&2",
            "  exit /b 1",
            ")",
            "echo INFO  Type checking %PROJECT_DIR% 1>&2",
            "\"!NODE!\" \"!PNPM!\" --dir \"!PROJECT_PATH!\" --store-dir \"!PNPM_STORE_DIR!\" exec tsc --noEmit",
            "if errorlevel 1 exit /b 1",
            "echo SUCCESS Web typecheck passed 1>&2",
        ])
    elif kind == "test":
        lines.extend([
            "if not exist \"!PROJECT_PATH!\\vitest.config.ts\" (",
            "  echo ERROR required file vitest.config.ts not found in %PROJECT_DIR% 1>&2",
            "  exit /b 1",
            ")",
            "echo INFO  Running unit tests for %PROJECT_DIR% 1>&2",
            "\"!NODE!\" \"!PNPM!\" --dir \"!PROJECT_PATH!\" --store-dir \"!PNPM_STORE_DIR!\" exec vitest run",
            "if errorlevel 1 exit /b 1",
            "echo SUCCESS Web unit tests passed 1>&2",
        ])
    elif kind == "browser_install":
        lines.extend([
            "if not exist \"!PROJECT_PATH!\\playwright.config.ts\" (",
            "  echo ERROR required file playwright.config.ts not found in %PROJECT_DIR% 1>&2",
            "  exit /b 1",
            ")",
            "if not exist \"!PLAYWRIGHT_BROWSERS_PATH!\" mkdir \"!PLAYWRIGHT_BROWSERS_PATH!\" >NUL 2>&1",
            "echo INFO  Installing Playwright browsers for %PROJECT_DIR% 1>&2",
            "\"!NODE!\" \"!PNPM!\" --dir \"!PROJECT_PATH!\" --store-dir \"!PNPM_STORE_DIR!\" exec playwright install",
            "if errorlevel 1 exit /b 1",
            "echo SUCCESS Playwright browsers installed 1>&2",
        ])
    elif kind == "e2e":
        lines.extend([
            "if not exist \"!PROJECT_PATH!\\playwright.config.ts\" (",
            "  echo ERROR required file playwright.config.ts not found in %PROJECT_DIR% 1>&2",
            "  exit /b 1",
            ")",
            "if not exist \"!PLAYWRIGHT_BROWSERS_PATH!\" (",
            "  echo ERROR Playwright browsers not installed; run web_browser_install first 1>&2",
            "  exit /b 1",
            ")",
            "dir /b \"!PLAYWRIGHT_BROWSERS_PATH!\" >NUL 2>&1",
            "if errorlevel 1 (",
            "  echo ERROR Playwright browsers not installed; run web_browser_install first 1>&2",
            "  exit /b 1",
            ")",
            "echo INFO  Running Playwright tests for %PROJECT_DIR% 1>&2",
            "\"!NODE!\" \"!PNPM!\" --dir \"!PROJECT_PATH!\" --store-dir \"!PNPM_STORE_DIR!\" exec playwright test",
            "if errorlevel 1 exit /b 1",
            "echo SUCCESS Web e2e tests passed 1>&2",
        ])
    else:
        fail("unsupported kind: %s" % kind)

    lines.append("exit /b 0")
    return "\r\n".join(lines) + "\r\n"

def _impl(ctx):
    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    node_file = _tool_named_file(ctx.attr.tool_node, "node.exe" if is_windows else "node", "node")
    pnpm_file = _tool_named_file(ctx.attr.tool_pnpm, "package/dist/pnpm.cjs", "pnpm")

    node_path = _tool_runfiles_path(node_file, is_windows)
    pnpm_path = _tool_runfiles_path(pnpm_file, is_windows)

    launcher = ctx.actions.declare_file(ctx.label.name + (".bat" if is_windows else ".sh"))
    content = _render_batch(ctx.attr.kind, ctx.attr.project_dir, ctx.attr.package_name, node_path, pnpm_path) if is_windows else _render_shell(ctx.attr.kind, ctx.attr.project_dir, ctx.attr.package_name, node_path, pnpm_path)
    ctx.actions.write(
        output = launcher,
        content = content,
        is_executable = not is_windows,
    )

    runfiles_files = []
    runfiles_files.extend(ctx.attr.tool_node[DefaultInfo].files.to_list())
    runfiles_files.extend(ctx.attr.tool_pnpm[DefaultInfo].files.to_list())

    return [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = runfiles_files),
    )]

web_runner = rule(
    implementation = _impl,
    executable = True,
    attrs = {
        "kind": attr.string(
            mandatory = True,
            values = ["init", "install", "dev", "build", "preview", "typecheck", "test", "browser_install", "e2e"],
        ),
        "project_dir": attr.string(mandatory = True),
        "package_name": attr.string(default = ""),
        "tool_node": attr.label(cfg = "exec", default = "@web_tool_node//:tool"),
        "tool_pnpm": attr.label(cfg = "exec", default = "@web_tool_pnpm//:tool"),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
)
