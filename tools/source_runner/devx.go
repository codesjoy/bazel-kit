package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
)

func runDevx(args []string) error {
	fs := flag.NewFlagSet("devx", flag.ContinueOnError)
	fs.SetOutput(ioDiscard{})

	var kind string
	var runTargets stringListFlag
	var testTargets stringListFlag
	var coverageTargets stringListFlag
	var coverageThreshold int
	var coverageOutputDir string
	var bazelArgs stringListFlag
	var requiredCommands stringListFlag
	var verifyRunTargets stringListFlag
	var verifyTestTargets stringListFlag
	requireGitRepo := true

	fs.StringVar(&kind, "kind", "", "")
	fs.Var(&runTargets, "run-target", "")
	fs.Var(&testTargets, "test-target", "")
	fs.Var(&coverageTargets, "coverage-target", "")
	fs.IntVar(&coverageThreshold, "coverage-threshold", 0, "")
	fs.StringVar(&coverageOutputDir, "coverage-output-dir", "_output/coverage", "")
	fs.Var(&bazelArgs, "bazel-arg", "")
	fs.Var(&requiredCommands, "required-command", "")
	fs.Var(&verifyRunTargets, "verify-run-target", "")
	fs.Var(&verifyTestTargets, "verify-test-target", "")
	fs.BoolVar(&requireGitRepo, "require-git-repo", true, "")
	if err := fs.Parse(args); err != nil {
		return err
	}

	workspace, err := workspaceRoot()
	if err != nil {
		return err
	}

	switch kind {
	case "workflow":
		return runDevxWorkflow(workspace, runTargets, testTargets, coverageTargets, coverageThreshold, coverageOutputDir, bazelArgs)
	case "doctor":
		return runDevxDoctor(workspace, requiredCommands, verifyRunTargets, verifyTestTargets, requireGitRepo)
	case "hooks_install", "hooks_verify", "hooks_run", "hooks_run_all", "hooks_clean":
		return runDevxHooks(workspace, kind)
	default:
		return fmt.Errorf("unsupported devx kind: %s", kind)
	}
}

func runBazelStage(workspace, subcommand string, bazelArgs, targets []string) error {
	if len(targets) == 0 {
		return nil
	}
	infof("bazel %s %s", subcommand, strings.Join(targets, " "))
	args := append([]string{subcommand}, bazelArgs...)
	args = append(args, targets...)
	return runStreaming(commandSpec{
		name: "bazel",
		args: args,
		dir:  workspace,
	})
}

func parseLCOVPercent(path string) (float64, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return 0, err
	}
	var linesFound float64
	var linesHit float64
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "LF:") {
			value, err := strconv.ParseFloat(strings.TrimSpace(strings.TrimPrefix(line, "LF:")), 64)
			if err != nil {
				return 0, err
			}
			linesFound += value
		}
		if strings.HasPrefix(line, "LH:") {
			value, err := strconv.ParseFloat(strings.TrimSpace(strings.TrimPrefix(line, "LH:")), 64)
			if err != nil {
				return 0, err
			}
			linesHit += value
		}
	}
	if linesFound == 0 {
		return 0, nil
	}
	return 100 * linesHit / linesFound, nil
}

func runDevxWorkflow(workspace string, runTargets, testTargets, coverageTargets []string, coverageThreshold int, coverageOutputDir string, bazelArgs []string) error {
	if _, err := requireTool("bazel"); err != nil {
		return err
	}
	infof("Running devx workflow")
	if err := runBazelStage(workspace, "run", bazelArgs, runTargets); err != nil {
		return err
	}
	if err := runBazelStage(workspace, "test", bazelArgs, testTargets); err != nil {
		return err
	}
	if len(coverageTargets) > 0 {
		outDir := maybeJoinWorkspace(workspace, coverageOutputDir)
		if err := os.MkdirAll(outDir, 0o755); err != nil {
			return err
		}
		infof("bazel coverage %s", strings.Join(coverageTargets, " "))
		args := append([]string{"coverage"}, bazelArgs...)
		args = append(args, "--combined_report=lcov")
		args = append(args, coverageTargets...)
		if err := runStreaming(commandSpec{
			name: "bazel",
			args: args,
			dir:  workspace,
		}); err != nil {
			return err
		}
		outputPath, err := captureTrimmed(commandSpec{
			name: "bazel",
			args: []string{"info", "output_path"},
			dir:  workspace,
		})
		if err != nil {
			return err
		}
		lcovPath := filepath.Join(outputPath, "_coverage", "_coverage_report.dat")
		if _, err := os.Stat(lcovPath); err != nil {
			return fmt.Errorf("Combined lcov report not found at %s", lcovPath)
		}
		if err := copyFile(lcovPath, filepath.Join(outDir, "lcov.info")); err != nil {
			return err
		}
		if coverageThreshold > 0 {
			actual, err := parseLCOVPercent(lcovPath)
			if err != nil {
				return err
			}
			infof("Coverage %.2f%%", actual)
			if actual < float64(coverageThreshold) {
				return fmt.Errorf("Coverage %.2f%% is below threshold %d%%", actual, coverageThreshold)
			}
		}
	}
	successf("Devx workflow complete")
	return nil
}

func runDevxDoctor(workspace string, requiredCommands, verifyRunTargets, verifyTestTargets []string, requireGitRepo bool) error {
	if _, err := requireTool("bazel"); err != nil {
		return err
	}
	infof("Running doctor checks")
	for _, command := range requiredCommands {
		if _, err := requireTool(command); err != nil {
			return err
		}
	}
	if requireGitRepo {
		if _, err := requireTool("git"); err != nil {
			return err
		}
		if err := runStreaming(commandSpec{
			name:   "git",
			args:   []string{"rev-parse", "--git-dir"},
			dir:    workspace,
			stdout: ioDiscard{},
			stderr: ioDiscard{},
		}); err != nil {
			return fmt.Errorf("Current workspace is not a git repository")
		}
	}
	if len(verifyRunTargets) > 0 {
		infof("Verifying run targets")
		if err := runStreaming(commandSpec{
			name: "bazel",
			args: append([]string{"build", "--nobuild"}, verifyRunTargets...),
			dir:  workspace,
		}); err != nil {
			return err
		}
	}
	if len(verifyTestTargets) > 0 {
		infof("Verifying test targets")
		if err := runStreaming(commandSpec{
			name: "bazel",
			args: append([]string{"build", "--nobuild"}, verifyTestTargets...),
			dir:  workspace,
		}); err != nil {
			return err
		}
	}
	successf("Doctor checks passed")
	return nil
}

type pythonSpec struct {
	name string
	args []string
}

func resolvePython() (*pythonSpec, error) {
	if path := os.Getenv("PYTHON"); path != "" {
		return &pythonSpec{name: path}, nil
	}
	candidates := []pythonSpec{
		{name: "python3"},
		{name: "python"},
	}
	if runtime.GOOS == "windows" {
		candidates = append([]pythonSpec{{name: "py", args: []string{"-3"}}}, candidates...)
	}
	for _, candidate := range candidates {
		if _, err := exec.LookPath(candidate.name); err != nil {
			continue
		}
		if _, _, exitCode, err := runCaptured(commandSpec{
			name:    candidate.name,
			preArgs: candidate.args,
			args:    []string{"-V"},
		}); err == nil && exitCode == 0 {
			return &candidate, nil
		}
	}
	return nil, fmt.Errorf("python is required")
}

func resolvePreCommit(installMissing bool) ([]string, error) {
	if path, err := exec.LookPath("pre-commit"); err == nil {
		return []string{path}, nil
	}
	pythonCmd, err := resolvePython()
	if err != nil {
		if installMissing {
			return nil, fmt.Errorf("python is required to install pre-commit")
		}
		return nil, fmt.Errorf("pre-commit not found")
	}
	moduleArgs := []string{"-m", "pre_commit"}
	if _, _, exitCode, err := runCaptured(commandSpec{
		name:    pythonCmd.name,
		preArgs: pythonCmd.args,
		args:    append(moduleArgs, "--version"),
	}); err == nil && exitCode == 0 {
		return append(append([]string{pythonCmd.name}, pythonCmd.args...), moduleArgs...), nil
	}
	if installMissing {
		if err := runStreaming(commandSpec{
			name:    pythonCmd.name,
			preArgs: pythonCmd.args,
			args:    []string{"-m", "pip", "install", "--user", "pre-commit"},
		}); err != nil {
			return nil, err
		}
		if path, err := exec.LookPath("pre-commit"); err == nil {
			return []string{path}, nil
		}
		return append(append([]string{pythonCmd.name}, pythonCmd.args...), moduleArgs...), nil
	}
	return nil, fmt.Errorf("pre-commit not found")
}

func runCommandVector(argv []string, workspace string) error {
	if len(argv) == 0 {
		return fmt.Errorf("missing command")
	}
	return runStreaming(commandSpec{
		name:    argv[0],
		preArgs: argv[1:],
		dir:     workspace,
	})
}

func runDevxHooks(workspace, kind string) error {
	preCommitConfig := filepath.Join(workspace, ".pre-commit-config.yaml")
	ensureConfig := func() error {
		if _, err := os.Stat(preCommitConfig); err != nil {
			return fmt.Errorf("Missing %s", preCommitConfig)
		}
		return nil
	}

	switch kind {
	case "hooks_install":
		if err := ensureConfig(); err != nil {
			return err
		}
		preCommit, err := resolvePreCommit(true)
		if err != nil {
			return err
		}
		infof("Installing pre-commit hooks")
		if err := runCommandVector(append(preCommit, "install", "--install-hooks", "--hook-type", "pre-commit", "--hook-type", "commit-msg"), workspace); err != nil {
			return err
		}
		successf("pre-commit hooks installed")
		return nil
	case "hooks_verify":
		if err := ensureConfig(); err != nil {
			return err
		}
		if _, err := os.Stat(filepath.Join(workspace, ".git", "hooks", "pre-commit")); err != nil {
			return fmt.Errorf("Missing .git/hooks/pre-commit")
		}
		if _, err := os.Stat(filepath.Join(workspace, ".git", "hooks", "commit-msg")); err != nil {
			return fmt.Errorf("Missing .git/hooks/commit-msg")
		}
		successf("pre-commit hooks verified")
		return nil
	case "hooks_run":
		if err := ensureConfig(); err != nil {
			return err
		}
		preCommit, err := resolvePreCommit(false)
		if err != nil {
			return err
		}
		infof("Running pre-commit hooks on staged files")
		if err := runCommandVector(append(preCommit, "run"), workspace); err != nil {
			return err
		}
		successf("pre-commit run complete")
		return nil
	case "hooks_run_all":
		if err := ensureConfig(); err != nil {
			return err
		}
		preCommit, err := resolvePreCommit(false)
		if err != nil {
			return err
		}
		infof("Running pre-commit hooks on all files")
		if err := runCommandVector(append(preCommit, "run", "--all-files"), workspace); err != nil {
			return err
		}
		successf("pre-commit run-all complete")
		return nil
	case "hooks_clean":
		preCommit, err := resolvePreCommit(false)
		if err != nil {
			return err
		}
		infof("Removing pre-commit hooks")
		if err := runCommandVector(append(preCommit, "uninstall", "--hook-type", "pre-commit", "--hook-type", "commit-msg"), workspace); err != nil {
			return err
		}
		successf("pre-commit hooks removed")
		return nil
	default:
		return fmt.Errorf("unsupported hooks kind: %s", kind)
	}
}
