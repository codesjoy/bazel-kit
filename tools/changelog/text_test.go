package changelog

import (
	"os"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestText(t *testing.T) {
	repositoriesFile := os.Args[1]
	versionsFile := os.Args[2]
	testutil.AssertContains(t, versionsFile, "changelog_tool_git_chglog")
	testutil.AssertContains(t, versionsFile, "v0.15.4")
	testutil.AssertContains(t, versionsFile, "./cmd/git-chglog")
	testutil.AssertContains(t, repositoriesFile, "changelog_repository")
	testutil.AssertContains(t, repositoriesFile, "build_go_source_tool")
}
