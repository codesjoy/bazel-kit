package private

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestCopyrightLaunchers(t *testing.T) {
	if len(os.Args) < 8 {
		t.Fatalf("expected copyright args")
	}
	defsFile := os.Args[1]
	extensionsFile := os.Args[2]
	launcherFile := os.Args[3]
	versionsFile := os.Args[4]
	addLauncher := os.Args[5]
	verifyLauncher := os.Args[6]
	boilerplate := os.Args[7]

	testutil.AssertContains(t, defsFile, "def copyright_add(")
	testutil.AssertContains(t, defsFile, "def copyright_verify(")
	testutil.AssertContains(t, extensionsFile, "copyright_tools = module_extension(")
	testutil.AssertContains(t, launcherFile, "\"copyright\"")
	testutil.AssertContains(t, launcherFile, "\"--boilerplate\"")
	testutil.AssertContains(t, versionsFile, "\"copyright_tool_addlicense\"")

	workspace := t.TempDir()
	targetBoilerplate := filepath.Join(workspace, "rules", "copyright", "private", "testdata", "boilerplate.txt")
	if err := os.MkdirAll(filepath.Dir(targetBoilerplate), 0o755); err != nil {
		t.Fatal(err)
	}
	data := testutil.ReadFile(t, boilerplate)
	if err := os.WriteFile(targetBoilerplate, []byte(data), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(workspace, "demo.go"), []byte("package demo\n\nfunc Demo() {}\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	env := map[string]string{"BUILD_WORKSPACE_DIRECTORY": workspace}
	testutil.MustRun(t, env, addLauncher)
	testutil.AssertContains(t, filepath.Join(workspace, "demo.go"), "Licensed under the Apache License")
	testutil.MustRun(t, env, verifyLauncher)
}
