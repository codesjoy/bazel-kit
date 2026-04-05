package main

import (
	"flag"
	"fmt"
	"io/fs"
	"path/filepath"
	"time"
)

func runCopyright(args []string) error {
	flagSet := flag.NewFlagSet("copyright", flag.ContinueOnError)
	flagSet.SetOutput(ioDiscard{})

	var kind string
	var tool string
	var boilerplate string
	var roots stringListFlag
	var patterns stringListFlag
	var year string

	flagSet.StringVar(&kind, "kind", "", "")
	flagSet.StringVar(&tool, "tool", "", "")
	flagSet.StringVar(&boilerplate, "boilerplate", "", "")
	flagSet.Var(&roots, "root", "")
	flagSet.Var(&patterns, "pattern", "")
	flagSet.StringVar(&year, "year", "", "")
	if err := flagSet.Parse(args); err != nil {
		return err
	}

	workspace, err := workspaceRoot()
	if err != nil {
		return err
	}
	if len(roots) == 0 {
		roots = []string{"."}
	}
	if len(patterns) == 0 {
		patterns = []string{"*.go", "*.sh"}
	}
	files, err := discoverFilesInRoots(workspace, roots, func(rel, path string, entry fs.DirEntry) bool {
		return baseMatch(patterns, rel)
	})
	if err != nil {
		return err
	}
	if len(files) == 0 {
		warnf("No files matched copyright patterns")
		return nil
	}

	runArgs := []string{"-f", maybeJoinWorkspace(workspace, boilerplate)}
	if kind == "add" {
		if year == "" {
			year = fmt.Sprintf("%d", time.Now().Year())
		}
		runArgs = append(runArgs, "-y", year)
		infof("Adding copyright headers")
	} else {
		runArgs = append(runArgs, "-check")
		infof("Verifying copyright headers")
	}
	for _, file := range files {
		runArgs = append(runArgs, maybeJoinWorkspace(workspace, filepath.ToSlash(file)))
	}
	if err := runStreaming(commandSpec{
		name: tool,
		args: runArgs,
		dir:  workspace,
	}); err != nil {
		return err
	}
	successf("Copyright %s complete", kind)
	return nil
}
