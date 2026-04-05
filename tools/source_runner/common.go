package main

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
)

type stringListFlag []string

func (f *stringListFlag) String() string {
	return strings.Join(*f, ",")
}

func (f *stringListFlag) Set(value string) error {
	*f = append(*f, value)
	return nil
}

type envPairFlag map[string]string

func (f *envPairFlag) String() string {
	if *f == nil {
		return ""
	}
	keys := make([]string, 0, len(*f))
	for key := range *f {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	parts := make([]string, 0, len(keys))
	for _, key := range keys {
		parts = append(parts, key+"="+(*f)[key])
	}
	return strings.Join(parts, ",")
}

func (f *envPairFlag) Set(value string) error {
	parts := strings.SplitN(value, "=", 2)
	if len(parts) != 2 || parts[0] == "" {
		return fmt.Errorf("invalid env pair: %s", value)
	}
	if *f == nil {
		*f = map[string]string{}
	}
	(*f)[parts[0]] = parts[1]
	return nil
}

type commandSpec struct {
	name    string
	preArgs []string
	args    []string
	dir     string
	env     map[string]string
	stdout  io.Writer
	stderr  io.Writer
	stdin   io.Reader
}

func fatalf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "ERROR "+format+"\n", args...)
	os.Exit(1)
}

func infof(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "INFO  "+format+"\n", args...)
}

func warnf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "WARN  "+format+"\n", args...)
}

func successf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "SUCCESS "+format+"\n", args...)
}

func workspaceRoot() (string, error) {
	if value := os.Getenv("BUILD_WORKSPACE_DIRECTORY"); value != "" {
		return filepath.Abs(value)
	}
	return os.Getwd()
}

func requireTool(name string) (string, error) {
	path, err := exec.LookPath(name)
	if err != nil {
		return "", fmt.Errorf("required tool %q not found in PATH", name)
	}
	return path, nil
}

func maybeJoinWorkspace(workspace, value string) string {
	if value == "" || filepath.IsAbs(value) {
		return value
	}
	return filepath.Join(workspace, filepath.FromSlash(value))
}

func workspaceRel(workspace, path string) (string, error) {
	rel, err := filepath.Rel(workspace, path)
	if err != nil {
		return "", err
	}
	if rel == "." {
		return ".", nil
	}
	return filepath.ToSlash(rel), nil
}

func shouldSkipDir(name string) bool {
	return name == "vendor" || name == "_output" || name == ".tmp" || name == ".git" || strings.HasPrefix(name, "bazel-")
}

func discoverFilesInRoots(workspace string, roots []string, match func(rel string, path string, entry fs.DirEntry) bool) ([]string, error) {
	if len(roots) == 0 {
		roots = []string{"."}
	}
	seen := map[string]struct{}{}
	var results []string

	for _, root := range roots {
		rootPath := maybeJoinWorkspace(workspace, root)
		info, err := os.Stat(rootPath)
		if err != nil {
			return nil, err
		}
		if !info.IsDir() {
			return nil, fmt.Errorf("root %s is not a directory", root)
		}

		if err := filepath.WalkDir(rootPath, func(path string, entry fs.DirEntry, walkErr error) error {
			if walkErr != nil {
				return walkErr
			}
			if entry.IsDir() {
				if path != rootPath && shouldSkipDir(entry.Name()) {
					return fs.SkipDir
				}
				return nil
			}
			rel, err := workspaceRel(workspace, path)
			if err != nil {
				return err
			}
			if !match(rel, path, entry) {
				return nil
			}
			if _, ok := seen[rel]; ok {
				return nil
			}
			seen[rel] = struct{}{}
			results = append(results, rel)
			return nil
		}); err != nil {
			return nil, err
		}
	}

	sort.Strings(results)
	return results, nil
}

func discoverGoModules(workspace string) ([]string, error) {
	return discoverFilesInRoots(workspace, []string{"."}, func(rel, path string, entry fs.DirEntry) bool {
		return entry.Name() == "go.mod"
	})
}

func discoverModuleDirs(workspace string) ([]string, error) {
	files, err := discoverGoModules(workspace)
	if err != nil {
		return nil, err
	}
	results := make([]string, 0, len(files))
	for _, file := range files {
		dir := filepath.ToSlash(filepath.Dir(file))
		if dir == "." {
			results = append(results, ".")
			continue
		}
		results = append(results, dir)
	}
	sort.Strings(results)
	return results, nil
}

func discoverGoFiles(workspace string) ([]string, error) {
	return discoverFilesInRoots(workspace, []string{"."}, func(rel, path string, entry fs.DirEntry) bool {
		name := entry.Name()
		if filepath.Ext(name) != ".go" {
			return false
		}
		if strings.HasSuffix(name, ".pb.go") || strings.HasSuffix(name, ".pb.gw.go") || strings.HasSuffix(name, ".gen.go") || strings.HasSuffix(name, "_gen.go") || strings.HasSuffix(name, "_generated.go") || strings.HasPrefix(name, "zz_generated") {
			return false
		}
		return true
	})
}

func baseMatch(patterns []string, rel string) bool {
	base := filepath.Base(rel)
	for _, pattern := range patterns {
		ok, err := filepath.Match(pattern, base)
		if err == nil && ok {
			return true
		}
	}
	return false
}

func discoverShellFiles(workspace string, roots, scripts []string) ([]string, error) {
	if len(scripts) > 0 {
		results := append([]string(nil), scripts...)
		sort.Strings(results)
		return results, nil
	}
	return discoverFilesInRoots(workspace, roots, func(rel, path string, entry fs.DirEntry) bool {
		if strings.HasSuffix(rel, ".sh") {
			return true
		}
		for _, root := range roots {
			root = strings.Trim(filepath.ToSlash(root), "/")
			if root == "." || root == "" {
				if strings.HasPrefix(rel, "bin/") {
					return true
				}
				continue
			}
			if rel == root+"/bin" || strings.HasPrefix(rel, root+"/bin/") {
				return true
			}
		}
		return false
	})
}

func mergedEnv(extra map[string]string) []string {
	base := os.Environ()
	if len(extra) == 0 {
		return base
	}
	values := map[string]string{}
	for _, entry := range base {
		parts := strings.SplitN(entry, "=", 2)
		if len(parts) == 2 {
			values[parts[0]] = parts[1]
		}
	}
	for key, value := range extra {
		values[key] = value
	}
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	merged := make([]string, 0, len(keys))
	for _, key := range keys {
		merged = append(merged, key+"="+values[key])
	}
	return merged
}

func buildCommand(spec commandSpec) *exec.Cmd {
	args := append(append([]string{}, spec.preArgs...), spec.args...)
	if runtime.GOOS == "windows" {
		ext := strings.ToLower(filepath.Ext(spec.name))
		if ext == ".bat" || ext == ".cmd" {
			cmd := exec.Command("cmd.exe", append([]string{"/c", spec.name}, args...)...)
			cmd.Dir = spec.dir
			cmd.Env = mergedEnv(spec.env)
			cmd.Stdin = spec.stdin
			cmd.Stdout = spec.stdout
			cmd.Stderr = spec.stderr
			return cmd
		}
	}
	cmd := exec.Command(spec.name, args...)
	cmd.Dir = spec.dir
	cmd.Env = mergedEnv(spec.env)
	cmd.Stdin = spec.stdin
	cmd.Stdout = spec.stdout
	cmd.Stderr = spec.stderr
	return cmd
}

func runStreaming(spec commandSpec) error {
	if spec.stdout == nil {
		spec.stdout = os.Stdout
	}
	if spec.stderr == nil {
		spec.stderr = os.Stderr
	}
	return buildCommand(spec).Run()
}

func runCaptured(spec commandSpec) (string, string, int, error) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	spec.stdout = &stdout
	spec.stderr = &stderr
	err := buildCommand(spec).Run()
	exitCode := 0
	if err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			exitCode = exitErr.ExitCode()
		} else {
			return stdout.String(), stderr.String(), -1, err
		}
	}
	return stdout.String(), stderr.String(), exitCode, nil
}

func captureTrimmed(spec commandSpec) (string, error) {
	stdout, stderr, exitCode, err := runCaptured(spec)
	if err != nil {
		return "", err
	}
	if exitCode != 0 {
		return "", fmt.Errorf("%s", strings.TrimSpace(stdout+stderr))
	}
	return strings.TrimSpace(stdout), nil
}

func writeFileLF(path string, data []byte) error {
	return os.WriteFile(path, normalizeLF(data), 0o644)
}

func normalizeLF(data []byte) []byte {
	return bytes.ReplaceAll(data, []byte("\r\n"), []byte("\n"))
}

func copyFile(src, dst string) error {
	input, err := os.Open(src)
	if err != nil {
		return err
	}
	defer input.Close()

	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	output, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer output.Close()

	if _, err := io.Copy(output, input); err != nil {
		return err
	}
	return output.Close()
}

func firstLine(value string) string {
	lines := strings.Split(strings.TrimSpace(value), "\n")
	if len(lines) == 0 {
		return ""
	}
	return strings.TrimSpace(lines[0])
}
