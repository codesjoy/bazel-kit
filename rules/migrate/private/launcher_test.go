package private

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/codesjoy/bazel-kit/tools/testhelpers/testutil"
)

func TestMigrateLaunchers(t *testing.T) {
	if len(os.Args) < 9 {
		t.Fatalf("expected migrate args")
	}
	defsFile := os.Args[1]
	extensionsFile := os.Args[2]
	launcherFile := os.Args[3]
	versionsFile := os.Args[4]
	upLauncher := os.Args[5]
	downLauncher := os.Args[6]
	versionLauncher := os.Args[7]
	forceLauncher := os.Args[8]

	testutil.AssertContains(t, defsFile, "def migrate_up(")
	testutil.AssertContains(t, defsFile, "def migrate_force(")
	testutil.AssertContains(t, extensionsFile, "migrate_tools = module_extension(")
	testutil.AssertContains(t, launcherFile, "\"migrate\"")
	testutil.AssertContains(t, launcherFile, "\"--table\"")
	testutil.AssertContains(t, versionsFile, "\"migrate_tool_migrate\"")

	workspace := t.TempDir()
	migrationsDir := filepath.Join(workspace, "db", "migrations")
	if err := os.MkdirAll(migrationsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(migrationsDir, "0001_init.up.sql"), []byte("select 1;\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(migrationsDir, "0001_init.down.sql"), []byte("select 1;\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	env := map[string]string{
		"BUILD_WORKSPACE_DIRECTORY": workspace,
		"DATABASE_DSN":              "postgres://demo:demo@127.0.0.1:5432/demo?sslmode=disable",
	}
	testutil.MustRun(t, env, upLauncher)
	testutil.MustRun(t, env, downLauncher)
	testutil.MustRun(t, env, versionLauncher)
	testutil.MustRun(t, env, forceLauncher)

	logFile := filepath.Join(workspace, "migrate.log")
	testutil.AssertContains(t, logFile, "up")
	testutil.AssertContains(t, logFile, "down 2")
	testutil.AssertContains(t, logFile, "version")
	testutil.AssertContains(t, logFile, "force 7")
	testutil.AssertContains(t, logFile, "x-migrations-table=schema_migrations")
}
