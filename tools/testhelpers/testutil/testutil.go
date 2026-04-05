package testutil

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

type RunResult struct {
	Stdout   string
	Stderr   string
	ExitCode int
}

func ReadFile(t *testing.T, path string) string {
	t.Helper()
	path = ResolvePath(path)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	return string(data)
}

func AssertContains(t *testing.T, path, pattern string) {
	t.Helper()
	data := ReadFile(t, path)
	if !strings.Contains(data, pattern) {
		t.Fatalf("missing pattern %q in %s", pattern, path)
	}
}

func Run(t *testing.T, env map[string]string, name string, args ...string) RunResult {
	t.Helper()
	name = ResolvePath(name)
	cmd := exec.Command(name, args...)
	cmd.Env = append([]string{}, os.Environ()...)
	for key, value := range env {
		cmd.Env = append(cmd.Env, key+"="+value)
	}
	stdout, err := cmd.Output()
	result := RunResult{Stdout: string(stdout)}
	if err == nil {
		return result
	}
	if exitErr, ok := err.(*exec.ExitError); ok {
		result.Stderr = string(exitErr.Stderr)
		result.ExitCode = exitErr.ExitCode()
		return result
	}
	t.Fatalf("run %s %v: %v", name, args, err)
	return RunResult{}
}

func MustRun(t *testing.T, env map[string]string, name string, args ...string) RunResult {
	t.Helper()
	result := Run(t, env, name, args...)
	if result.ExitCode != 0 {
		t.Fatalf("run %s %v failed: stdout=%s stderr=%s", name, args, result.Stdout, result.Stderr)
	}
	return result
}

func CopyForCommand(t *testing.T, src, dir, name string) string {
	t.Helper()
	src = ResolvePath(src)
	data, err := os.ReadFile(src)
	if err != nil {
		t.Fatalf("read %s: %v", src, err)
	}
	dstName := name
	if runtime.GOOS == "windows" && filepath.Ext(src) == ".exe" {
		dstName += ".exe"
	}
	dst := filepath.Join(dir, dstName)
	if err := os.WriteFile(dst, data, 0o755); err != nil {
		t.Fatalf("write %s: %v", dst, err)
	}
	return dst
}

func ResolvePath(path string) string {
	if filepath.IsAbs(path) {
		return path
	}
	if _, err := os.Stat(path); err == nil {
		return path
	}
	testSrcDir := os.Getenv("TEST_SRCDIR")
	if testSrcDir == "" {
		return path
	}
	workspace := os.Getenv("TEST_WORKSPACE")
	if workspace == "" {
		workspace = "_main"
	}
	candidate := filepath.Join(testSrcDir, workspace, filepath.FromSlash(path))
	if _, err := os.Stat(candidate); err == nil {
		return candidate
	}
	candidate = filepath.Join(testSrcDir, "_main", filepath.FromSlash(path))
	if _, err := os.Stat(candidate); err == nil {
		return candidate
	}
	return path
}
