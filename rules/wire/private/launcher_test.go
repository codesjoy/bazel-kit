package private

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestWireLaunchers(t *testing.T) {
	if len(os.Args) < 8 {
		t.Fatalf("expected wire launcher args")
	}
	defsFile := os.Args[1]
	extensionsFile := os.Args[2]
	launcherFile := os.Args[3]
	versionsFile := os.Args[4]
	genLauncher := os.Args[5]
	diffLauncher := os.Args[6]
	checkLauncher := os.Args[7]

	testutil.AssertContains(t, defsFile, "def wire_gen(")
	testutil.AssertContains(t, defsFile, "def wire_diff(")
	testutil.AssertContains(t, defsFile, "def wire_check(")
	testutil.AssertContains(t, extensionsFile, "wire_tools = module_extension(")
	testutil.AssertContains(t, launcherFile, "\"wire\"")
	testutil.AssertContains(t, launcherFile, "\"--target-pkg\"")
	testutil.AssertContains(t, launcherFile, "_runner")
	testutil.AssertContains(t, versionsFile, "\"wire_tool_wire\"")

	workspace := t.TempDir()
	if err := os.MkdirAll(filepath.Join(workspace, "apps", "demo", "cmd", "server"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(workspace, "apps", "demo", "go.mod"), []byte("module example.com/demo\n\ngo 1.25.8\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	env := map[string]string{"BUILD_WORKSPACE_DIRECTORY": workspace}
	testutil.MustRun(t, env, genLauncher)
	testutil.MustRun(t, env, diffLauncher)
	testutil.AssertContains(t, filepath.Join(workspace, "wire.log"), "./cmd/server")
	testutil.AssertContains(t, filepath.Join(workspace, "wire.log"), "diff ./cmd/server")

	if err := os.WriteFile(filepath.Join(workspace, "apps", "demo", ".wire-diff-fail"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	result := testutil.Run(t, env, checkLauncher)
	if result.ExitCode == 0 {
		t.Fatalf("expected wire check to fail when diff reports drift")
	}
	if !strings.Contains(result.Stderr, "Wire outputs are out of date") {
		t.Fatalf("unexpected stderr: %s", result.Stderr)
	}
}
