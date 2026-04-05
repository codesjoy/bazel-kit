package wire

import (
	"os"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestText(t *testing.T) {
	repositoriesFile := os.Args[1]
	versionsFile := os.Args[2]
	testutil.AssertContains(t, versionsFile, "wire_tool_wire")
	testutil.AssertContains(t, versionsFile, "v0.7.0")
	testutil.AssertContains(t, versionsFile, "./cmd/wire")
	testutil.AssertContains(t, repositoriesFile, "wire_repository")
	testutil.AssertContains(t, repositoriesFile, "build_go_source_tool")
}
