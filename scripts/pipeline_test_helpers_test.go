package scripts

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func mustRunPython(t *testing.T, env map[string]string, script string, args ...string) testutil.RunResult {
	t.Helper()
	allArgs := append([]string{testutil.ResolvePath(script)}, args...)
	return mustRunCommand(t, env, "python3", allArgs...)
}

func runPython(t *testing.T, env map[string]string, script string, args ...string) testutil.RunResult {
	t.Helper()
	allArgs := append([]string{testutil.ResolvePath(script)}, args...)
	return runCommand(t, env, "python3", allArgs...)
}

func mustRunCommand(t *testing.T, env map[string]string, name string, args ...string) testutil.RunResult {
	t.Helper()
	result := runCommand(t, env, name, args...)
	if result.ExitCode != 0 {
		t.Fatalf("run %s %v failed: stdout=%s stderr=%s", name, args, result.Stdout, result.Stderr)
	}
	return result
}

func runCommand(t *testing.T, env map[string]string, name string, args ...string) testutil.RunResult {
	t.Helper()
	name = testutil.ResolvePath(name)
	cmd := exec.Command(name, args...)
	cmd.Env = append([]string{}, os.Environ()...)
	for key, value := range env {
		cmd.Env = append(cmd.Env, key+"="+value)
	}
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	result := testutil.RunResult{
		Stdout: stdout.String(),
		Stderr: stderr.String(),
	}
	if err == nil {
		return result
	}
	if exitErr, ok := err.(*exec.ExitError); ok {
		result.ExitCode = exitErr.ExitCode()
		return result
	}
	t.Fatalf("run %s %v: %v", name, args, err)
	return testutil.RunResult{}
}

func writeJSONFile(t *testing.T, path string, payload any) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", filepath.Dir(path), err)
	}
	data, err := json.MarshalIndent(payload, "", "  ")
	if err != nil {
		t.Fatalf("marshal %s: %v", path, err)
	}
	if err := os.WriteFile(path, append(data, '\n'), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

func readJSONFile(t *testing.T, path string) map[string]any {
	t.Helper()
	data := testutil.ReadFile(t, path)
	payload := map[string]any{}
	if err := json.Unmarshal([]byte(data), &payload); err != nil {
		t.Fatalf("unmarshal %s: %v", path, err)
	}
	return payload
}

func setupGitopsRepo(t *testing.T) (string, string) {
	t.Helper()
	root := t.TempDir()
	remoteDir := filepath.Join(root, "remote.git")
	gitopsDir := filepath.Join(root, "gitops")
	testutil.MustRun(t, nil, "git", "init", "--bare", remoteDir)
	testutil.MustRun(t, nil, "git", "clone", remoteDir, gitopsDir)
	testutil.MustRun(t, nil, "git", "-C", gitopsDir, "config", "user.email", "dev@example.com")
	testutil.MustRun(t, nil, "git", "-C", gitopsDir, "config", "user.name", "Dev")
	return gitopsDir, remoteDir
}

func seedGitopsRepo(t *testing.T, repoDir, relativePath, content, message string) {
	t.Helper()
	path := filepath.Join(repoDir, relativePath)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", filepath.Dir(path), err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
	testutil.MustRun(t, nil, "git", "-C", repoDir, "add", relativePath)
	testutil.MustRun(t, nil, "git", "-C", repoDir, "commit", "-m", message)
	testutil.MustRun(t, nil, "git", "-C", repoDir, "push", "origin", "HEAD")
}

func headBranch(t *testing.T, repoDir string) string {
	t.Helper()
	return strings.TrimSpace(testutil.MustRun(t, nil, "git", "-C", repoDir, "branch", "--show-current").Stdout)
}

func headMessage(t *testing.T, repoDir string) string {
	t.Helper()
	return strings.TrimSpace(testutil.MustRun(t, nil, "git", "-C", repoDir, "log", "--format=%s", "-1").Stdout)
}

func remoteHead(t *testing.T, remoteDir, branch string) string {
	t.Helper()
	return strings.TrimSpace(testutil.MustRun(t, nil, "git", "--git-dir", remoteDir, "rev-parse", "refs/heads/"+branch).Stdout)
}

func localHead(t *testing.T, repoDir string) string {
	t.Helper()
	return strings.TrimSpace(testutil.MustRun(t, nil, "git", "-C", repoDir, "rev-parse", "HEAD").Stdout)
}
