package private

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestRenderSmoke(t *testing.T) {
	launcher := os.Args[1]
	rootBuild := testutil.ResolvePath(os.Args[2])
	workspace := filepath.Dir(rootBuild)
	outDir := t.TempDir()

	env := map[string]string{"BUILD_WORKSPACE_DIRECTORY": workspace}
	testutil.MustRun(t, env, launcher,
		"--environment", "preview",
		"--output-dir", outDir,
		"--namespace", "preview-api",
		"--host", "api.preview.example.test",
		"--image-repository", "ghcr.io/acme/api",
		"--image-digest", "sha256:deadbeef",
		"--preview-id", "pr-42",
		"--baseline-environment", "itest-baseline",
		"--runtime-dependency", "web=https://web.itest.example.test",
	)

	manifest := filepath.Join(outDir, "manifest.yaml")
	metadata := filepath.Join(outDir, "metadata.json")
	testutil.AssertContains(t, manifest, "release: api")
	testutil.AssertContains(t, manifest, "namespace: preview-api")
	testutil.AssertContains(t, manifest, "\"repository\": \"ghcr.io/acme/api\"")
	testutil.AssertContains(t, manifest, "\"digest\": \"sha256:deadbeef\"")
	testutil.AssertContains(t, manifest, "\"previewId\": \"pr-42\"")
	testutil.AssertContains(t, manifest, "\"baselineEnvironment\": \"itest-baseline\"")
	testutil.AssertContains(t, manifest, "previewEnabled: true")
	testutil.AssertContains(t, manifest, "api.preview.example.test")
	testutil.AssertContains(t, manifest, "\"web\": \"https://web.itest.example.test\"")
	testutil.AssertContains(t, metadata, "\"service\": \"api\"")
	testutil.AssertContains(t, metadata, "\"environment\": \"preview\"")
	testutil.AssertContains(t, metadata, "\"namespace\": \"preview-api\"")
	if strings.TrimSpace(testutil.ReadFile(t, manifest)) == "" {
		t.Fatalf("expected manifest output")
	}
}
