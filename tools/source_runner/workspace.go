package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"strings"
)

func runWorkspace(args []string) error {
	fs := flag.NewFlagSet("workspace", flag.ContinueOnError)
	fs.SetOutput(ioDiscard{})

	var kind string
	var modules stringListFlag
	var goWork string
	var gazelleTarget string
	runBazelModTidy := true
	outputDir := "_output"

	fs.StringVar(&kind, "kind", "", "")
	fs.Var(&modules, "module", "")
	fs.StringVar(&goWork, "go-work", "go.work", "")
	fs.StringVar(&gazelleTarget, "gazelle-target", "", "")
	fs.BoolVar(&runBazelModTidy, "run-bazel-mod-tidy", true, "")
	fs.StringVar(&outputDir, "output-dir", "_output", "")
	if err := fs.Parse(args); err != nil {
		return err
	}

	workspace, err := workspaceRoot()
	if err != nil {
		return err
	}

	selectedModules := append([]string(nil), modules...)
	if len(selectedModules) == 0 {
		selectedModules, err = discoverModuleDirs(workspace)
		if err != nil {
			return err
		}
	}
	if len(selectedModules) == 0 {
		return fmt.Errorf("no modules discovered")
	}

	switch kind {
	case "sync":
		return runWorkspaceSync(workspace, selectedModules, goWork, gazelleTarget, runBazelModTidy)
	case "go_mod_tidy":
		return runWorkspaceGoCommand(workspace, selectedModules, "mod", "tidy")
	case "go_mod_download":
		return runWorkspaceGoCommand(workspace, selectedModules, "mod", "download")
	case "go_mod_verify":
		return runWorkspaceGoCommand(workspace, selectedModules, "mod", "verify")
	case "drift_check":
		return runWorkspaceDriftCheck(workspace, selectedModules, goWork)
	case "modules_print":
		return runWorkspaceModulesPrint(workspace, selectedModules)
	case "go_clean":
		return runWorkspaceClean(workspace, selectedModules, outputDir)
	default:
		return fmt.Errorf("unsupported workspace kind: %s", kind)
	}
}

type ioDiscard struct{}

func (ioDiscard) Write(p []byte) (int, error) { return len(p), nil }

func resolveGoVersion(workspace string) (string, error) {
	goBin, err := requireTool("go")
	if err != nil {
		return "", err
	}
	version, err := captureTrimmed(commandSpec{
		name: goBin,
		args: []string{"env", "GOVERSION"},
		dir:  workspace,
	})
	if err == nil && version != "" {
		return strings.TrimPrefix(firstLine(version), "go"), nil
	}

	version, err = captureTrimmed(commandSpec{
		name: goBin,
		args: []string{"version"},
		dir:  workspace,
	})
	if err != nil {
		return "", err
	}
	fields := strings.Fields(version)
	if len(fields) < 3 {
		return "", fmt.Errorf("unable to determine Go version")
	}
	return strings.TrimPrefix(fields[2], "go"), nil
}

func goWorkContent(modules []string, version string) []byte {
	var buf bytes.Buffer
	fmt.Fprintf(&buf, "go %s\n\n", version)
	buf.WriteString("use (\n")
	for _, module := range modules {
		fmt.Fprintf(&buf, "    ./%s\n", module)
	}
	buf.WriteString(")\n")
	return buf.Bytes()
}

func runWorkspaceSync(workspace string, modules []string, goWork, gazelleTarget string, runBazelModTidy bool) error {
	if _, err := requireTool("bazel"); err != nil {
		return err
	}
	if _, err := requireTool("go"); err != nil {
		return err
	}
	version, err := resolveGoVersion(workspace)
	if err != nil {
		return err
	}
	infof("Writing go.work for %d module(s)", len(modules))
	if err := writeFileLF(maybeJoinWorkspace(workspace, goWork), goWorkContent(modules, version)); err != nil {
		return err
	}
	successf("go.work synced")

	if runBazelModTidy {
		infof("Tidying Bazel module dependencies")
		if err := runStreaming(commandSpec{
			name: "bazel",
			args: []string{"mod", "tidy"},
			dir:  workspace,
		}); err != nil {
			return err
		}
	}
	if gazelleTarget != "" {
		infof("Running %s", gazelleTarget)
		if err := runStreaming(commandSpec{
			name: "bazel",
			args: []string{"run", gazelleTarget},
			dir:  workspace,
		}); err != nil {
			return err
		}
	}
	successf("Workspace sync complete")
	return nil
}

func runWorkspaceGoCommand(workspace string, modules []string, args ...string) error {
	if _, err := requireTool("go"); err != nil {
		return err
	}
	label := strings.Join(args, " ")
	switch label {
	case "mod tidy":
		infof("Tidying Go modules")
	case "mod download":
		infof("Downloading Go modules")
	case "mod verify":
		infof("Verifying Go modules")
	}
	for _, module := range modules {
		infof("%s", module)
		if err := runStreaming(commandSpec{
			name: "go",
			args: args,
			dir:  maybeJoinWorkspace(workspace, module),
			env:  map[string]string{"GOWORK": "off"},
		}); err != nil {
			return err
		}
	}
	switch label {
	case "mod tidy":
		successf("All modules tidied")
	case "mod download":
		successf("All modules downloaded")
	case "mod verify":
		successf("All modules verified")
	}
	return nil
}

func runWorkspaceDriftCheck(workspace string, modules []string, goWork string) error {
	if _, err := requireTool("go"); err != nil {
		return err
	}
	path := maybeJoinWorkspace(workspace, goWork)
	actual, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("go.work not found at %s", path)
	}
	version, err := resolveGoVersion(workspace)
	if err != nil {
		return err
	}
	expected := goWorkContent(modules, version)
	if !bytes.Equal(normalizeLF(actual), expected) {
		return fmt.Errorf("go.work is out of sync")
	}
	successf("go.work matches discovered modules")
	return nil
}

func runWorkspaceModulesPrint(workspace string, modules []string) error {
	allModules, err := discoverModuleDirs(workspace)
	if err != nil {
		return err
	}
	fmt.Printf("ALL_MODULES:\n")
	for _, module := range allModules {
		fmt.Printf("  - %s\n", module)
	}
	fmt.Printf("MODULES:\n")
	for _, module := range modules {
		fmt.Printf("  - %s\n", module)
	}
	successf("Module discovery context printed")
	return nil
}

func runWorkspaceClean(workspace string, modules []string, outputDir string) error {
	if _, err := requireTool("go"); err != nil {
		return err
	}
	infof("Cleaning Go workspace artifacts")
	if err := os.RemoveAll(maybeJoinWorkspace(workspace, outputDir)); err != nil {
		return err
	}
	for _, module := range modules {
		infof("%s", module)
		if err := runStreaming(commandSpec{
			name: "go",
			args: []string{"clean", "-cache", "-testcache"},
			dir:  maybeJoinWorkspace(workspace, module),
			env:  map[string]string{"GOWORK": "off"},
		}); err != nil {
			return err
		}
	}
	successf("Go clean complete")
	return nil
}
