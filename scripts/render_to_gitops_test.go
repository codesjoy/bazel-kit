package scripts

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestRenderToGitops(t *testing.T) {
	script := os.Args[1]
	fakeBazel := testutil.ResolvePath(os.Args[2])
	workspace := t.TempDir()
	configPath := filepath.Join(workspace, "pipeline.json")
	imageMetadata := filepath.Join(workspace, "image.json")
	gitopsDir := filepath.Join(workspace, "gitops")

	writeJSONFile(t, configPath, map[string]any{
		"baseline_environment": "itest-baseline",
		"preview": map[string]any{
			"gitops_root":        "preview",
			"namespace_template": "preview-${preview_id}-${service}",
			"host_template":      "${service}.${preview_id}.preview.example.test",
			"scheme":             "https",
		},
		"environments": map[string]any{
			"itest-baseline": map[string]any{
				"host_template": "${service}.itest.example.test",
				"scheme":        "https",
			},
		},
		"services": map[string]any{
			"api": map[string]any{
				"image_repository": "ghcr.io/acme/api",
			},
		},
	})
	writeJSONFile(t, imageMetadata, map[string]any{
		"service":          "api",
		"image_repository": "ghcr.io/acme/api",
		"image_tag":        "pr-42",
		"image_digest":     "sha256:deadbeef",
	})

	result := mustRunPython(t, map[string]string{"PIPELINE_BAZEL_BIN": fakeBazel}, script,
		"--config", configPath,
		"--service", "api",
		"--render-target", "//scripts:api_render",
		"--environment", "preview",
		"--preview-mode", "shared_baseline",
		"--runtime-deps-json", "[\"web\"]",
		"--gitops-dir", gitopsDir,
		"--workspace", workspace,
		"--preview-id", "pr-42",
		"--baseline-environment", "itest-baseline",
		"--image-metadata", imageMetadata,
	)

	resolvedGitopsDir, err := filepath.EvalSymlinks(gitopsDir)
	if err != nil {
		t.Fatalf("resolve gitops dir: %v", err)
	}
	destination := filepath.Join(resolvedGitopsDir, "preview", "pr-42", "api")
	if strings.TrimSpace(result.Stdout) != destination {
		t.Fatalf("unexpected destination: %q", result.Stdout)
	}
	manifest := filepath.Join(destination, "manifest.yaml")
	metadata := filepath.Join(destination, "metadata.json")
	testutil.AssertContains(t, manifest, "\"repository\": \"ghcr.io/acme/api\"")
	testutil.AssertContains(t, manifest, "\"digest\": \"sha256:deadbeef\"")
	testutil.AssertContains(t, manifest, "\"previewId\": \"pr-42\"")
	testutil.AssertContains(t, manifest, "\"baselineEnvironment\": \"itest-baseline\"")
	testutil.AssertContains(t, manifest, "\"web\": \"https://web.itest.example.test\"")
	testutil.AssertContains(t, metadata, "\"service\": \"api\"")
	testutil.AssertContains(t, metadata, "\"environment\": \"preview\"")
	testutil.AssertContains(t, metadata, "\"namespace\": \"preview-pr-42-api\"")
}
