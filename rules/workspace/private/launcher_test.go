package private

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestWorkspaceLaunchers(t *testing.T) {
	if len(os.Args) < 12 {
		t.Fatalf("expected launcher arguments")
	}
	defsFile := os.Args[1]
	launcherFile := os.Args[2]
	syncLauncher := os.Args[3]
	tidyLauncher := os.Args[4]
	downloadLauncher := os.Args[5]
	verifyLauncher := os.Args[6]
	driftLauncher := os.Args[7]
	modulesPrintLauncher := os.Args[8]
	cleanLauncher := os.Args[9]
	fakeBazel := os.Args[10]
	fakeGo := os.Args[11]

	testutil.AssertContains(t, defsFile, "def workspace_sync(")
	testutil.AssertContains(t, defsFile, "def go_mod_tidy(")
	testutil.AssertContains(t, defsFile, "def workspace_drift_check(")
	testutil.AssertContains(t, defsFile, "def go_clean(")
	testutil.AssertContains(t, launcherFile, "\"workspace\"")
	testutil.AssertContains(t, launcherFile, "\"--go-work\"")
	testutil.AssertContains(t, launcherFile, "\"--run-bazel-mod-tidy\"")
	testutil.AssertContains(t, launcherFile, "_runner")

	workspace := t.TempDir()
	binDir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(workspace, "apps", "api"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(workspace, "apps", "web"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(workspace, "_output"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(workspace, "apps", "api", "go.mod"), []byte("module example.com/api\n\ngo 1.25.8\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(workspace, "apps", "web", "go.mod"), []byte("module example.com/web\n\ngo 1.25.8\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(workspace, "_output", "marker"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}

	testutil.CopyForCommand(t, fakeGo, binDir, "go")
	testutil.CopyForCommand(t, fakeBazel, binDir, "bazel")

	env := map[string]string{
		"BUILD_WORKSPACE_DIRECTORY": workspace,
		"PATH":                      binDir + string(os.PathListSeparator) + os.Getenv("PATH"),
		"FAKE_GO_LOG":               filepath.Join(workspace, "fake-go.log"),
		"FAKE_BAZEL_LOG":            filepath.Join(workspace, "fake-bazel.log"),
	}

	testutil.MustRun(t, env, syncLauncher)
	if _, err := os.Stat(filepath.Join(workspace, "go.work")); err != nil {
		t.Fatal(err)
	}
	testutil.AssertContains(t, filepath.Join(workspace, "go.work"), "./apps/api")
	testutil.AssertContains(t, filepath.Join(workspace, "fake-bazel.log"), "mod tidy")

	testutil.MustRun(t, env, tidyLauncher)
	testutil.MustRun(t, env, downloadLauncher)
	testutil.MustRun(t, env, verifyLauncher)
	testutil.MustRun(t, env, driftLauncher)
	result := testutil.MustRun(t, env, modulesPrintLauncher)
	if result.Stdout == "" || !contains(result.Stdout, "apps/api") {
		t.Fatalf("unexpected modules output: %s", result.Stdout)
	}
	testutil.MustRun(t, env, cleanLauncher)
	if _, err := os.Stat(filepath.Join(workspace, "_output", "marker")); !os.IsNotExist(err) {
		t.Fatalf("expected _output marker to be removed, err=%v", err)
	}
	testutil.AssertContains(t, filepath.Join(workspace, "fake-go.log"), "mod tidy")
	testutil.AssertContains(t, filepath.Join(workspace, "fake-go.log"), "mod download")
	testutil.AssertContains(t, filepath.Join(workspace, "fake-go.log"), "mod verify")
	testutil.AssertContains(t, filepath.Join(workspace, "fake-go.log"), "clean -cache -testcache")
}

func contains(value, pattern string) bool {
	return strings.Contains(value, pattern)
}
