package private

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestChangelogLaunchers(t *testing.T) {
	if len(os.Args) < 11 {
		t.Fatalf("expected changelog args")
	}
	defsFile := os.Args[1]
	extensionsFile := os.Args[2]
	launcherFile := os.Args[3]
	versionsFile := os.Args[4]
	initLauncher := os.Args[5]
	generateLauncher := os.Args[6]
	previewLauncher := os.Args[7]
	verifyLauncher := os.Args[8]
	statePrintLauncher := os.Args[9]
	stateResetLauncher := os.Args[10]

	testutil.AssertContains(t, defsFile, "def changelog_generate(")
	testutil.AssertContains(t, defsFile, "def changelog_state_reset(")
	testutil.AssertContains(t, extensionsFile, "changelog_tools = module_extension(")
	testutil.AssertContains(t, launcherFile, "\"changelog\"")
	testutil.AssertContains(t, launcherFile, "\"--profile\"")
	testutil.AssertContains(t, versionsFile, "\"changelog_tool_git_chglog\"")

	workspace := t.TempDir()
	testutil.MustRun(t, nil, "git", "init", workspace)
	testutil.MustRun(t, nil, "git", "-C", workspace, "config", "user.email", "dev@example.com")
	testutil.MustRun(t, nil, "git", "-C", workspace, "config", "user.name", "Dev")
	if err := os.WriteFile(filepath.Join(workspace, "README.md"), []byte("# demo\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	testutil.MustRun(t, nil, "git", "-C", workspace, "add", "README.md")
	testutil.MustRun(t, nil, "git", "-C", workspace, "commit", "-m", "feat: initial commit")
	testutil.MustRun(t, nil, "git", "-C", workspace, "tag", "v0.1.0")

	env := map[string]string{"BUILD_WORKSPACE_DIRECTORY": workspace}
	testutil.MustRun(t, env, initLauncher)
	if _, err := os.Stat(filepath.Join(workspace, ".chglog", "config.yml")); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(workspace, ".chglog", "CHANGELOG.tpl.md")); err != nil {
		t.Fatal(err)
	}
	testutil.MustRun(t, env, stateResetLauncher)
	if err := os.WriteFile(filepath.Join(workspace, "app.txt"), []byte("app\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	testutil.MustRun(t, nil, "git", "-C", workspace, "add", "app.txt")
	testutil.MustRun(t, nil, "git", "-C", workspace, "commit", "-m", "fix(core): add app file")
	testutil.MustRun(t, env, generateLauncher)
	if _, err := os.Stat(filepath.Join(workspace, "CHANGELOG.md")); err != nil {
		t.Fatal(err)
	}
	testutil.MustRun(t, env, verifyLauncher)
	preview := testutil.MustRun(t, env, previewLauncher)
	if strings.TrimSpace(preview.Stdout) == "" {
		t.Fatalf("expected preview output")
	}
	state := testutil.MustRun(t, env, statePrintLauncher)
	if !strings.Contains(state.Stdout, "BASE_SHA=") {
		t.Fatalf("unexpected state output: %s", state.Stdout)
	}
}
