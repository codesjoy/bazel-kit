package private

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestQualityLaunchers(t *testing.T) {
	if len(os.Args) < 13 {
		t.Fatalf("expected quality args")
	}
	goDefs := os.Args[1]
	shellDefs := os.Args[2]
	webDefs := os.Args[3]
	extensionsFile := os.Args[4]
	goLauncher := os.Args[5]
	shellLauncher := os.Args[6]
	webLauncher := os.Args[7]
	goVersions := os.Args[8]
	shellVersions := os.Args[9]
	webVersions := os.Args[10]
	scriptsLauncher := os.Args[11]
	failLauncher := os.Args[12]

	testutil.AssertContains(t, goDefs, "def go_fmt(")
	testutil.AssertContains(t, goDefs, "def go_fmt_check(")
	testutil.AssertContains(t, goDefs, "def go_lint(")
	testutil.AssertContains(t, shellDefs, "def shell_lint(")
	testutil.AssertContains(t, shellDefs, "def shell_scripts_lint(")
	testutil.AssertContains(t, webDefs, "def web_fmt(")
	testutil.AssertContains(t, webDefs, "def web_fmt_check(")
	testutil.AssertContains(t, webDefs, "def web_lint(")
	testutil.AssertContains(t, extensionsFile, "quality_tools = module_extension(")
	testutil.AssertContains(t, goLauncher, "quality_go_runner = rule(")
	testutil.AssertContains(t, shellLauncher, "\"shell\"")
	testutil.AssertContains(t, shellLauncher, "\"--shellcheck-required\"")
	testutil.AssertContains(t, webLauncher, "quality_web_runner = rule(")
	testutil.AssertContains(t, goVersions, "\"golangci-lint\"")
	testutil.AssertContains(t, shellVersions, "\"shellcheck\"")
	testutil.AssertContains(t, webVersions, "\"quality_tool_biome\"")
	if strings.Contains(testutil.ReadFile(t, shellLauncher), "bash -n") {
		t.Fatalf("shell launcher still depends on bash -n")
	}

	workspace := t.TempDir()
	if err := os.MkdirAll(filepath.Join(workspace, "scripts", "bin"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(workspace, "scripts", "bin", "demo"), []byte("#!/usr/bin/env bash\necho demo\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(workspace, "scripts", "check.sh"), []byte("#!/usr/bin/env bash\nprintf 'ok\\n'\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	env := map[string]string{"BUILD_WORKSPACE_DIRECTORY": workspace}
	testutil.MustRun(t, env, scriptsLauncher)
	logFile := filepath.Join(workspace, "shell-tools.log")
	testutil.AssertContains(t, logFile, "shfmt")
	testutil.AssertContains(t, logFile, "shellcheck_enabled")
	testutil.AssertContains(t, logFile, "scripts/bin/demo")

	result := testutil.Run(t, env, failLauncher)
	if result.ExitCode == 0 {
		t.Fatalf("expected shellcheck_required launcher to fail when shellcheck is disabled")
	}
}
