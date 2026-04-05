package migrate

import (
	"os"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestText(t *testing.T) {
	repositoriesFile := os.Args[1]
	versionsFile := os.Args[2]
	testutil.AssertContains(t, versionsFile, "migrate_tool_migrate")
	testutil.AssertContains(t, versionsFile, "v4.19.1")
	testutil.AssertContains(t, versionsFile, "\"build_tags\": [\"postgres\"]")
	testutil.AssertContains(t, repositoriesFile, "migrate_repository")
	testutil.AssertContains(t, repositoriesFile, "build_go_source_tool")
}
