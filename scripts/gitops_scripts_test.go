package scripts

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGitopsCommitScript(t *testing.T) {
	script := os.Args[1]
	gitopsDir, remoteDir := setupGitopsRepo(t)

	noop := runPython(t, nil, script, gitopsDir, "deploy(api): noop")
	if noop.ExitCode != 0 {
		t.Fatalf("unexpected noop failure: %s", noop.Stderr)
	}
	if !strings.Contains(noop.Stderr, "no GitOps changes to commit") {
		t.Fatalf("unexpected noop stderr: %s", noop.Stderr)
	}

	seedPath := filepath.Join(gitopsDir, "apps", "dev", "api")
	if err := os.MkdirAll(seedPath, 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", seedPath, err)
	}
	if err := os.WriteFile(filepath.Join(seedPath, "manifest.yaml"), []byte("api: v1\n"), 0o644); err != nil {
		t.Fatalf("write manifest: %v", err)
	}

	mustRunPython(t, nil, script, gitopsDir, "deploy(api): 123456")
	if headMessage(t, gitopsDir) != "deploy(api): 123456" {
		t.Fatalf("unexpected commit message: %s", headMessage(t, gitopsDir))
	}
	branch := headBranch(t, gitopsDir)
	if branch == "" {
		t.Fatalf("expected current branch")
	}
	if localHead(t, gitopsDir) != remoteHead(t, remoteDir, branch) {
		t.Fatalf("expected remote head to match local head")
	}
}

func TestCleanupGitopsScript(t *testing.T) {
	cleanupScript := os.Args[2]
	gitopsDir, remoteDir := setupGitopsRepo(t)
	seedGitopsRepo(t, gitopsDir, filepath.Join("preview", "pr-42", "api", "manifest.yaml"), "api: v1\n", "seed preview")

	noop := runPython(t, nil, cleanupScript, gitopsDir, filepath.Join("preview", "pr-999"), "cleanup(preview): noop")
	if noop.ExitCode != 0 {
		t.Fatalf("unexpected noop failure: %s", noop.Stderr)
	}
	if !strings.Contains(noop.Stderr, "no GitOps cleanup changes to commit") {
		t.Fatalf("unexpected noop stderr: %s", noop.Stderr)
	}

	mustRunPython(t, nil, cleanupScript, gitopsDir, filepath.Join("preview", "pr-42"), "cleanup(preview): pr-42")
	if _, err := os.Stat(filepath.Join(gitopsDir, "preview", "pr-42")); !os.IsNotExist(err) {
		t.Fatalf("expected preview directory to be removed, stat err=%v", err)
	}
	if headMessage(t, gitopsDir) != "cleanup(preview): pr-42" {
		t.Fatalf("unexpected cleanup commit message: %s", headMessage(t, gitopsDir))
	}
	branch := headBranch(t, gitopsDir)
	if branch == "" {
		t.Fatalf("expected current branch")
	}
	if localHead(t, gitopsDir) != remoteHead(t, remoteDir, branch) {
		t.Fatalf("expected remote head to match local head")
	}
}
