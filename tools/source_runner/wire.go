package main

import (
	"flag"
	"fmt"
	"os"
)

func runWire(args []string) error {
	fs := flag.NewFlagSet("wire", flag.ContinueOnError)
	fs.SetOutput(ioDiscard{})

	var kind string
	var modules stringListFlag
	var targetPkgs stringListFlag
	var tool string
	var gocacheDir string

	fs.StringVar(&kind, "kind", "", "")
	fs.Var(&modules, "module", "")
	fs.Var(&targetPkgs, "target-pkg", "")
	fs.StringVar(&tool, "tool", "", "")
	fs.StringVar(&gocacheDir, "gocache-dir", "_output/wire-go-build-cache", "")
	if err := fs.Parse(args); err != nil {
		return err
	}

	workspace, err := workspaceRoot()
	if err != nil {
		return err
	}
	if len(modules) == 0 {
		modules, err = discoverModuleDirs(workspace)
		if err != nil {
			return err
		}
	}
	if len(modules) == 0 {
		return fmt.Errorf("no application modules selected for Wire")
	}
	if len(targetPkgs) == 0 {
		return fmt.Errorf("target_pkgs must not be empty")
	}
	if tool == "" {
		return fmt.Errorf("tool is required")
	}
	if err := os.MkdirAll(maybeJoinWorkspace(workspace, gocacheDir), 0o755); err != nil {
		return err
	}

	for _, module := range modules {
		infof("Wire %s %s", kind, module)
		runArgs := append([]string{}, targetPkgs...)
		if kind == "diff" || kind == "check" {
			runArgs = append([]string{"diff"}, runArgs...)
		}
		_, _, exitCode, err := runCaptured(commandSpec{
			name: tool,
			args: runArgs,
			dir:  maybeJoinWorkspace(workspace, module),
			env: map[string]string{
				"GOWORK":  "off",
				"GOCACHE": maybeJoinWorkspace(workspace, gocacheDir),
			},
			stdout: os.Stdout,
			stderr: os.Stderr,
		})
		if err != nil {
			return err
		}
		if (kind == "diff" || kind == "check") && exitCode == 1 {
			return fmt.Errorf("Wire outputs are out of date in %s", module)
		}
		if exitCode != 0 {
			return fmt.Errorf("wire %s failed in %s", kind, module)
		}
	}
	successf("Wire %s complete", kind)
	return nil
}
