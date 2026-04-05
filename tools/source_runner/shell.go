package main

import (
	"flag"
)

func runShell(args []string) error {
	fs := flag.NewFlagSet("shell", flag.ContinueOnError)
	fs.SetOutput(ioDiscard{})

	var kind string
	var scripts stringListFlag
	var roots stringListFlag
	var shfmtTool string
	var shellcheckTool string
	shellcheckRequired := false

	fs.StringVar(&kind, "kind", "", "")
	fs.Var(&scripts, "script", "")
	fs.Var(&roots, "root", "")
	fs.StringVar(&shfmtTool, "tool-shfmt", "", "")
	fs.StringVar(&shellcheckTool, "tool-shellcheck", "", "")
	fs.BoolVar(&shellcheckRequired, "shellcheck-required", false, "")
	if err := fs.Parse(args); err != nil {
		return err
	}

	workspace, err := workspaceRoot()
	if err != nil {
		return err
	}
	files, err := discoverShellFiles(workspace, roots, scripts)
	if err != nil {
		return err
	}
	if len(files) == 0 {
		warnf("No shell scripts found to lint")
		return nil
	}

	paths := make([]string, 0, len(files))
	for _, file := range files {
		paths = append(paths, maybeJoinWorkspace(workspace, file))
	}

	if kind == "lint" {
		infof("Linting shell scripts")
	} else {
		infof("Linting repository shell scripts")
	}
	if err := runStreaming(commandSpec{
		name: shfmtTool,
		args: append([]string{"-d"}, paths...),
		dir:  workspace,
	}); err != nil {
		return err
	}
	env := map[string]string{}
	if shellcheckRequired {
		env["QUALITY_SHELLCHECK_REQUIRED"] = "1"
	}
	if err := runStreaming(commandSpec{
		name: shellcheckTool,
		args: append([]string{"-x"}, paths...),
		dir:  workspace,
		env:  env,
	}); err != nil {
		return err
	}
	if kind == "lint" {
		successf("Shell scripts linted successfully")
	} else {
		successf("Repository shell scripts linted successfully")
	}
	return nil
}
