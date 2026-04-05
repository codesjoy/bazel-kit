package private

import (
	"os"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestRunnerText(t *testing.T) {
	defsFile := os.Args[1]
	extensionsFile := os.Args[2]
	launcherFile := os.Args[3]
	planFile := os.Args[4]
	renderFile := os.Args[5]
	versionsFile := os.Args[6]
	testutil.AssertContains(t, defsFile, "def pipeline_service(")
	testutil.AssertContains(t, defsFile, "pipeline_helm_render = _pipeline_helm_render")
	testutil.AssertContains(t, extensionsFile, "pipeline_tools = module_extension(")
	testutil.AssertContains(t, launcherFile, "PipelineServiceInfo = provider(")
	testutil.AssertContains(t, launcherFile, "pipeline_plan = rule(")
	testutil.AssertContains(t, launcherFile, "pipeline_helm_render = rule(")
	testutil.AssertContains(t, launcherFile, "python-launch")
	testutil.AssertContains(t, planFile, "def query_affected_service_labels(")
	testutil.AssertContains(t, planFile, "\"baseline_environment\"")
	testutil.AssertContains(t, renderFile, "def override_payload(")
	testutil.AssertContains(t, renderFile, "runtimeDependencies")
	testutil.AssertContains(t, versionsFile, "\"pipeline_tool_helm\"")
}
