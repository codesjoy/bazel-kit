package private

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestPlanSmoke(t *testing.T) {
	launcher := os.Args[1]
	fakeBazel := testutil.ResolvePath(os.Args[2])
	rootBuild := testutil.ResolvePath(os.Args[3])
	workspace := filepath.Dir(rootBuild)
	tmpDir := t.TempDir()

	runPlan := func(changedFile, output string) map[string]any {
		env := map[string]string{
			"BUILD_WORKSPACE_DIRECTORY": workspace,
			"PIPELINE_BAZEL_BIN":        fakeBazel,
		}
		args := []string{"--baseline-environment", "staging", "--output", output}
		if changedFile != "" {
			args = append([]string{"--changed-files", changedFile}, args...)
		}
		testutil.MustRun(t, env, launcher, args...)
		data := testutil.ReadFile(t, output)
		var payload map[string]any
		if err := json.Unmarshal([]byte(data), &payload); err != nil {
			t.Fatal(err)
		}
		return payload
	}

	shared := runPlan("rules/pipeline/private/testdata/shared/contracts/schema.json", filepath.Join(tmpDir, "shared.json"))
	expectList(t, shared["affected_service_names"], []string{"api", "web"})
	if shared["baseline_environment"] != "staging" {
		t.Fatalf("unexpected baseline environment: %#v", shared["baseline_environment"])
	}
	serviceMatrix := shared["service_matrix"].(map[string]any)["include"].([]any)
	assertMapValue(t, serviceMatrix[0], "service", "api")
	assertMapValue(t, serviceMatrix[1], "service", "web")
	lintMatrix := shared["lint_matrix"].(map[string]any)["include"].([]any)
	assertMapValue(t, lintMatrix[0], "target", "//rules/pipeline/private:api_lint")
	assertMapValue(t, lintMatrix[1], "target", "//rules/pipeline/private:web_lint")
	renderMatrix := shared["render_matrix"].(map[string]any)["include"].([]any)
	assertMapValue(t, renderMatrix[0], "target", "//rules/pipeline/private:api_render")
	assertMapValue(t, renderMatrix[1], "target", "//rules/pipeline/private:web_render")

	web := runPlan("rules/pipeline/private/testdata/services/web/src/main.ts", filepath.Join(tmpDir, "web.json"))
	expectList(t, web["affected_service_names"], []string{"web"})
	serviceMatrix = web["service_matrix"].(map[string]any)["include"].([]any)
	assertMapValue(t, serviceMatrix[0], "runtime_deps_csv", "api")

	empty := runPlan("", filepath.Join(tmpDir, "empty.json"))
	if empty["empty"] != true {
		t.Fatalf("expected empty payload: %#v", empty)
	}
	expectList(t, empty["affected_service_names"], []string{})
}

func expectList(t *testing.T, raw any, expected []string) {
	t.Helper()
	items := raw.([]any)
	if len(items) != len(expected) {
		t.Fatalf("unexpected list length: %#v", raw)
	}
	for index, item := range items {
		if item != expected[index] {
			t.Fatalf("unexpected list item: %#v", raw)
		}
	}
}

func assertMapValue(t *testing.T, raw any, key string, expected any) {
	t.Helper()
	value := raw.(map[string]any)[key]
	if value != expected {
		t.Fatalf("unexpected %s: %#v", key, value)
	}
}
