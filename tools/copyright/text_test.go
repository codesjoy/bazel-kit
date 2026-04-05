package copyright

import (
	"os"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestText(t *testing.T) {
	repositoriesFile := os.Args[1]
	versionsFile := os.Args[2]
	testutil.AssertContains(t, versionsFile, "copyright_tool_addlicense")
	testutil.AssertContains(t, versionsFile, "v1.2.0")
	testutil.AssertContains(t, versionsFile, "\"binary_name\": \"addlicense\"")
	testutil.AssertContains(t, repositoriesFile, "copyright_repository")
	testutil.AssertContains(t, repositoriesFile, "build_go_source_tool")
}
