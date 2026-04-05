package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
)

func runMigrate(args []string) error {
	fs := flag.NewFlagSet("migrate", flag.ContinueOnError)
	fs.SetOutput(ioDiscard{})

	var kind string
	var tool string
	var dsn string
	var dsnEnv string
	var migrationsDir string
	var table string
	var downSteps int
	var forceVersion string

	fs.StringVar(&kind, "kind", "", "")
	fs.StringVar(&tool, "tool", "", "")
	fs.StringVar(&dsn, "dsn", "", "")
	fs.StringVar(&dsnEnv, "dsn-env", "", "")
	fs.StringVar(&migrationsDir, "migrations-dir", "", "")
	fs.StringVar(&table, "table", "schema_migrations", "")
	fs.IntVar(&downSteps, "down-steps", 1, "")
	fs.StringVar(&forceVersion, "force-version", "", "")
	if err := fs.Parse(args); err != nil {
		return err
	}

	workspace, err := workspaceRoot()
	if err != nil {
		return err
	}
	if dsn == "" && dsnEnv != "" {
		dsn = os.Getenv(dsnEnv)
	}
	if dsn == "" {
		return fmt.Errorf("Database DSN is not set")
	}
	if tool == "" {
		return fmt.Errorf("tool is required")
	}
	migrationPath := maybeJoinWorkspace(workspace, migrationsDir)
	info, err := os.Stat(migrationPath)
	if err != nil || !info.IsDir() {
		return fmt.Errorf("Migration directory not found: %s", migrationPath)
	}
	if kind == "up" || kind == "down" {
		hasFiles := false
		entries, err := os.ReadDir(migrationPath)
		if err != nil {
			return err
		}
		for _, entry := range entries {
			name := entry.Name()
			if entry.IsDir() {
				continue
			}
			if strings.HasSuffix(name, ".up.sql") || strings.HasSuffix(name, ".down.sql") {
				hasFiles = true
				break
			}
		}
		if !hasFiles {
			return fmt.Errorf("No migration files found in %s", migrationPath)
		}
	}

	if !strings.Contains(dsn, "x-migrations-table=") {
		if strings.Contains(dsn, "?") {
			dsn += "&x-migrations-table=" + table
		} else {
			dsn += "?x-migrations-table=" + table
		}
	}

	runArgs := []string{"-path", migrationPath, "-database", dsn}
	switch kind {
	case "up":
		runArgs = append(runArgs, "up")
	case "down":
		runArgs = append(runArgs, "down", fmt.Sprintf("%d", downSteps))
	case "version":
		runArgs = append(runArgs, "version")
	case "force":
		runArgs = append(runArgs, "force", forceVersion)
	default:
		return fmt.Errorf("unsupported migrate kind: %s", kind)
	}

	infof("Running migrate %s", kind)
	if err := runStreaming(commandSpec{
		name: tool,
		args: runArgs,
		dir:  workspace,
	}); err != nil {
		return err
	}
	successf("Migrate %s complete", kind)
	return nil
}
