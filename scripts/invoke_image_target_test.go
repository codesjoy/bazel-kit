package scripts

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestInvokeImageTarget(t *testing.T) {
	script := os.Args[1]
	fakeBazel := testutil.ResolvePath(os.Args[2])

	t.Run("writes metadata", func(t *testing.T) {
		workspace := t.TempDir()
		configPath := filepath.Join(workspace, "pipeline.json")
		metadataPath := filepath.Join(workspace, "artifacts", "api.json")
		writeJSONFile(t, configPath, map[string]any{
			"services": map[string]any{
				"api": map[string]any{
					"image_repository": "ghcr.io/acme/api",
				},
			},
		})

		mustRunPython(t, map[string]string{"PIPELINE_BAZEL_BIN": fakeBazel}, script,
			"--config", configPath,
			"--service", "api",
			"--target", "//scripts:api_image",
			"--tag", "pr-42",
			"--metadata-file", metadataPath,
			"--workspace", workspace,
		)

		payload := readJSONFile(t, metadataPath)
		if payload["service"] != "api" {
			t.Fatalf("unexpected service: %#v", payload["service"])
		}
		if payload["image_repository"] != "ghcr.io/acme/api" {
			t.Fatalf("unexpected repository: %#v", payload["image_repository"])
		}
		if payload["image_tag"] != "pr-42" {
			t.Fatalf("unexpected tag: %#v", payload["image_tag"])
		}
		if !strings.HasPrefix(payload["image_digest"].(string), "sha256:") {
			t.Fatalf("unexpected digest: %#v", payload["image_digest"])
		}
	})

	t.Run("fails when service is missing", func(t *testing.T) {
		workspace := t.TempDir()
		configPath := filepath.Join(workspace, "pipeline.json")
		writeJSONFile(t, configPath, map[string]any{"services": map[string]any{}})

		result := runPython(t, map[string]string{"PIPELINE_BAZEL_BIN": fakeBazel}, script,
			"--config", configPath,
			"--service", "api",
			"--target", "//scripts:api_image",
			"--tag", "pr-42",
			"--metadata-file", filepath.Join(workspace, "api.json"),
			"--workspace", workspace,
		)
		if result.ExitCode == 0 {
			t.Fatalf("expected failure for missing service")
		}
		if !strings.Contains(result.Stderr, "service api not found") {
			t.Fatalf("unexpected stderr: %s", result.Stderr)
		}
	})

	t.Run("fails when image repository is missing", func(t *testing.T) {
		workspace := t.TempDir()
		configPath := filepath.Join(workspace, "pipeline.json")
		writeJSONFile(t, configPath, map[string]any{
			"services": map[string]any{
				"api": map[string]any{},
			},
		})

		result := runPython(t, map[string]string{"PIPELINE_BAZEL_BIN": fakeBazel}, script,
			"--config", configPath,
			"--service", "api",
			"--target", "//scripts:api_image",
			"--tag", "pr-42",
			"--metadata-file", filepath.Join(workspace, "api.json"),
			"--workspace", workspace,
		)
		if result.ExitCode == 0 {
			t.Fatalf("expected failure for missing image repository")
		}
		if !strings.Contains(result.Stderr, "missing image_repository") {
			t.Fatalf("unexpected stderr: %s", result.Stderr)
		}
	})
}
