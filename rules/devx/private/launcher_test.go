package private

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestDevxLaunchers(t *testing.T) {
	if len(os.Args) < 13 {
		t.Fatalf("expected devx args")
	}
	defsFile := os.Args[1]
	launcherFile := os.Args[2]
	workflowLauncher := os.Args[3]
	failLauncher := os.Args[4]
	doctorLauncher := os.Args[5]
	installLauncher := os.Args[6]
	verifyLauncher := os.Args[7]
	runLauncher := os.Args[8]
	runAllLauncher := os.Args[9]
	cleanLauncher := os.Args[10]
	fakeBazel := os.Args[11]
	fakePreCommit := os.Args[12]

	testutil.AssertContains(t, defsFile, "def devx_workflow(")
	testutil.AssertContains(t, defsFile, "def devx_doctor(")
	testutil.AssertContains(t, defsFile, "def hooks_install(")
	testutil.AssertContains(t, defsFile, "def hooks_run_all(")
	testutil.AssertContains(t, launcherFile, "\"devx\"")
	testutil.AssertContains(t, launcherFile, "\"--coverage-threshold\"")
	testutil.AssertContains(t, launcherFile, "_runner")

	t.Run("workflow", func(t *testing.T) {
		workspace := t.TempDir()
		binDir := t.TempDir()
		testutil.CopyForCommand(t, fakeBazel, binDir, "bazel")
		env := map[string]string{
			"BUILD_WORKSPACE_DIRECTORY": workspace,
			"PATH":                      binDir + string(os.PathListSeparator) + os.Getenv("PATH"),
			"FAKE_BAZEL_LOG":            filepath.Join(workspace, "fake-bazel.log"),
		}
		testutil.MustRun(t, env, workflowLauncher)
		if _, err := os.Stat(filepath.Join(workspace, "_output", "coverage", "lcov.info")); err != nil {
			t.Fatal(err)
		}
		testutil.AssertContains(t, filepath.Join(workspace, "fake-bazel.log"), "//demo:fmt_check")
		testutil.AssertContains(t, filepath.Join(workspace, "fake-bazel.log"), "//demo:unit")
		testutil.AssertContains(t, filepath.Join(workspace, "fake-bazel.log"), "coverage ")
		testutil.AssertContains(t, filepath.Join(workspace, "fake-bazel.log"), "//demo:coverage")
		result := testutil.Run(t, env, failLauncher)
		if result.ExitCode == 0 {
			t.Fatalf("expected workflow threshold failure")
		}
	})

	t.Run("doctor", func(t *testing.T) {
		workspace := t.TempDir()
		binDir := t.TempDir()
		testutil.CopyForCommand(t, fakeBazel, binDir, "bazel")
		testutil.MustRun(t, nil, "git", "init", workspace)
		env := map[string]string{
			"BUILD_WORKSPACE_DIRECTORY": workspace,
			"PATH":                      binDir + string(os.PathListSeparator) + os.Getenv("PATH"),
			"FAKE_BAZEL_LOG":            filepath.Join(workspace, "fake-bazel.log"),
		}
		testutil.MustRun(t, env, doctorLauncher)
		testutil.AssertContains(t, filepath.Join(workspace, "fake-bazel.log"), "build --nobuild //demo:fmt_check")
		testutil.AssertContains(t, filepath.Join(workspace, "fake-bazel.log"), "build --nobuild //demo:unit")
	})

	t.Run("hooks", func(t *testing.T) {
		workspace := t.TempDir()
		binDir := t.TempDir()
		testutil.CopyForCommand(t, fakePreCommit, binDir, "pre-commit")
		testutil.MustRun(t, nil, "git", "init", workspace)
		if err := os.WriteFile(filepath.Join(workspace, ".pre-commit-config.yaml"), []byte("repos:\n  - repo: local\n"), 0o644); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(workspace, "demo.txt"), []byte("demo\n"), 0o644); err != nil {
			t.Fatal(err)
		}
		env := map[string]string{
			"BUILD_WORKSPACE_DIRECTORY": workspace,
			"PATH":                      binDir + string(os.PathListSeparator) + os.Getenv("PATH"),
			"PRE_COMMIT_LOG":            filepath.Join(workspace, "pre-commit.log"),
		}
		testutil.MustRun(t, env, installLauncher)
		if _, err := os.Stat(filepath.Join(workspace, ".git", "hooks", "pre-commit")); err != nil {
			t.Fatal(err)
		}
		if _, err := os.Stat(filepath.Join(workspace, ".git", "hooks", "commit-msg")); err != nil {
			t.Fatal(err)
		}
		testutil.MustRun(t, env, verifyLauncher)
		testutil.MustRun(t, env, runLauncher)
		testutil.MustRun(t, env, runAllLauncher)
		testutil.MustRun(t, env, cleanLauncher)
		logFile := filepath.Join(workspace, "pre-commit.log")
		testutil.AssertContains(t, logFile, "install --install-hooks --hook-type pre-commit --hook-type commit-msg")
		testutil.AssertContains(t, logFile, "run")
		testutil.AssertContains(t, logFile, "run --all-files")
		testutil.AssertContains(t, logFile, "uninstall --hook-type pre-commit --hook-type commit-msg")
		if _, err := os.Stat(filepath.Join(workspace, ".git", "hooks", "pre-commit")); !os.IsNotExist(err) {
			t.Fatalf("expected pre-commit hook to be removed")
		}
		if _, err := os.Stat(filepath.Join(workspace, ".git", "hooks", "commit-msg")); !os.IsNotExist(err) {
			t.Fatalf("expected commit-msg hook to be removed")
		}
		if strings.Contains(testutil.ReadFile(t, logFile), "unsupported") {
			t.Fatalf("unexpected fake pre-commit failure")
		}
	})
}
