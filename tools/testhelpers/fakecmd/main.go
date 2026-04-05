package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	name := strings.TrimSuffix(strings.ToLower(filepath.Base(os.Args[0])), filepath.Ext(os.Args[0]))
	switch {
	case name == "go" || name == "fake_go":
		handleFakeGo()
	case name == "bazel" || name == "fake_bazel":
		handleFakeBazel()
	case name == "wire" || name == "fake_wire":
		handleFakeWire()
	case name == "migrate" || name == "fake_migrate":
		handleFakeMigrate()
	case name == "pre-commit" || name == "fake_pre_commit":
		handleFakePreCommit()
	case name == "shfmt" || name == "fake_shfmt":
		handleFakeShellTool("shfmt")
	case name == "fake_shellcheck_enabled":
		handleFakeShellcheck(true)
	case name == "shellcheck" || name == "fake_shellcheck_disabled":
		handleFakeShellcheck(false)
	case name == "helm" || name == "fake_helm":
		handleFakeHelm()
	case name == "noop_gazelle":
		fmt.Println("noop gazelle target")
	case name == "fmt_check":
		fmt.Println("fmt_check")
	case strings.HasSuffix(name, "_image"):
		handleFakeImage(strings.TrimSuffix(name, "_image"))
	default:
		fmt.Fprintf(os.Stderr, "unsupported fake command: %s\n", name)
		os.Exit(1)
	}
}

func workspaceDir() string {
	if value := os.Getenv("BUILD_WORKSPACE_DIRECTORY"); value != "" {
		return value
	}
	cwd, err := os.Getwd()
	if err != nil {
		return "."
	}
	return cwd
}

func appendLine(path, line string) {
	_ = os.MkdirAll(filepath.Dir(path), 0o755)
	handle, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer handle.Close()
	_, _ = handle.WriteString(line + "\n")
}

func handleFakeGo() {
	workspace := workspaceDir()
	logFile := os.Getenv("FAKE_GO_LOG")
	if logFile == "" {
		logFile = filepath.Join(workspace, "fake-go.log")
	}
	args := os.Args[1:]
	if len(args) >= 2 && args[0] == "env" && args[1] == "GOVERSION" {
		fmt.Println("go1.25.8")
		return
	}
	if len(args) >= 1 && args[0] == "version" {
		fmt.Println("go version go1.25.8 fake/fake")
		return
	}
	if len(args) >= 2 && args[0] == "mod" {
		appendLine(logFile, "mod "+args[1])
		return
	}
	if len(args) >= 1 && args[0] == "clean" {
		appendLine(logFile, "clean "+strings.Join(args[1:], " "))
		return
	}
	fmt.Fprintf(os.Stderr, "unsupported fake go call: %s\n", strings.Join(args, " "))
	os.Exit(1)
}

func handleFakeBazel() {
	workspace := workspaceDir()
	logFile := os.Getenv("FAKE_BAZEL_LOG")
	if logFile == "" {
		logFile = filepath.Join(workspace, "fake-bazel.log")
	}
	outputPath := os.Getenv("FAKE_BAZEL_OUTPUT_PATH")
	if outputPath == "" {
		outputPath = filepath.Join(workspace, "bazel-out", "fake-output")
	}
	args := os.Args[1:]
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "missing fake bazel command")
		os.Exit(1)
	}
	command := args[0]
	if os.Getenv("FAKE_BAZEL_FAIL_ON") == command {
		os.Exit(1)
	}

	switch command {
	case "run", "test", "build":
		appendLine(logFile, command+" "+strings.Join(args[1:], " "))
	case "coverage":
		appendLine(logFile, "coverage "+strings.Join(args[1:], " "))
		coverageDir := filepath.Join(outputPath, "_coverage")
		_ = os.MkdirAll(coverageDir, 0o755)
		_ = os.WriteFile(filepath.Join(coverageDir, "_coverage_report.dat"), []byte("TN:\nSF:demo.go\nDA:1,1\nDA:2,1\nDA:3,0\nLH:2\nLF:3\nend_of_record\n"), 0o644)
	case "info":
		if len(args) >= 2 && args[1] == "output_path" {
			fmt.Println(outputPath)
			return
		}
		fmt.Fprintf(os.Stderr, "unsupported fake bazel info call: %s\n", strings.Join(args[1:], " "))
		os.Exit(1)
	case "mod":
		if len(args) >= 2 && args[1] == "tidy" {
			appendLine(logFile, "mod tidy")
			return
		}
		fmt.Fprintf(os.Stderr, "unsupported fake bazel mod call: %s\n", strings.Join(args[1:], " "))
		os.Exit(1)
	case "query":
		query := strings.Join(args[1:], " ")
		switch {
		case strings.Contains(query, "testdata/shared/contracts/schema.json"):
			fmt.Println("//rules/pipeline/private:api_service")
			fmt.Println("//rules/pipeline/private:web_service")
		case strings.Contains(query, "testdata/services/web/src/main.ts"):
			fmt.Println("//rules/pipeline/private:web_service")
		}
	default:
		fmt.Fprintf(os.Stderr, "unsupported fake bazel command: %s\n", command)
		os.Exit(1)
	}
}

func handleFakeWire() {
	workspace := workspaceDir()
	args := os.Args[1:]
	appendLine(filepath.Join(workspace, "wire.log"), strings.Join(args, " "))
	if len(args) > 0 && args[0] == "diff" {
		if _, err := os.Stat(".wire-diff-fail"); err == nil {
			os.Exit(1)
		}
		return
	}
	_ = os.WriteFile("wire_gen.txt", []byte("generated\n"), 0o644)
}

func handleFakeMigrate() {
	appendLine(filepath.Join(workspaceDir(), "migrate.log"), strings.Join(os.Args[1:], " "))
}

func handleFakePreCommit() {
	workspace := workspaceDir()
	logFile := os.Getenv("PRE_COMMIT_LOG")
	if logFile == "" {
		logFile = filepath.Join(workspace, "pre-commit.log")
	}
	args := os.Args[1:]
	appendLine(logFile, strings.Join(args, " "))
	if len(args) == 0 {
		return
	}
	switch args[0] {
	case "install":
		hooksDir := filepath.Join(workspace, ".git", "hooks")
		_ = os.MkdirAll(hooksDir, 0o755)
		_ = os.WriteFile(filepath.Join(hooksDir, "pre-commit"), []byte("exit 0\n"), 0o755)
		_ = os.WriteFile(filepath.Join(hooksDir, "commit-msg"), []byte("exit 0\n"), 0o755)
	case "uninstall":
		_ = os.Remove(filepath.Join(workspace, ".git", "hooks", "pre-commit"))
		_ = os.Remove(filepath.Join(workspace, ".git", "hooks", "commit-msg"))
	case "run":
		return
	default:
		fmt.Fprintf(os.Stderr, "unsupported fake pre-commit command: %s\n", args[0])
		os.Exit(1)
	}
}

func handleFakeShellTool(name string) {
	appendLine(filepath.Join(workspaceDir(), "shell-tools.log"), name+" "+strings.Join(os.Args[1:], " "))
}

func handleFakeShellcheck(enabled bool) {
	label := "shellcheck_disabled"
	if enabled {
		label = "shellcheck_enabled"
	}
	appendLine(filepath.Join(workspaceDir(), "shell-tools.log"), label+" "+strings.Join(os.Args[1:], " "))
	if !enabled && os.Getenv("QUALITY_SHELLCHECK_REQUIRED") == "1" {
		os.Exit(1)
	}
}

func handleFakeHelm() {
	args := os.Args[1:]
	if len(args) < 4 || args[0] != "template" {
		fmt.Fprintf(os.Stderr, "unsupported fake helm call: %s\n", strings.Join(args, " "))
		os.Exit(1)
	}
	releaseName := args[1]
	namespace := ""
	valuesFiles := []string{}
	for index := 2; index < len(args); index++ {
		switch args[index] {
		case "--namespace":
			index++
			namespace = args[index]
		case "--values":
			index++
			valuesFiles = append(valuesFiles, args[index])
		}
	}
	override := map[string]any{}
	if len(valuesFiles) > 0 {
		data, err := os.ReadFile(valuesFiles[len(valuesFiles)-1])
		if err == nil {
			_ = json.Unmarshal(data, &override)
		}
	}
	image := mapStringMap(override["image"])
	pipeline := mapStringMap(override["pipeline"])
	ingress := mapStringMap(override["ingress"])
	runtimeDeps := mapStringMap(override["runtimeDependencies"])
	fmt.Printf("release: %s\n", releaseName)
	fmt.Printf("namespace: %s\n", namespace)
	fmt.Printf("previewEnabled: %v\n", pipeline["previewId"] != "")
	if host, ok := ingress["host"]; ok {
		fmt.Println(host)
	}
	if repo, ok := image["repository"]; ok {
		fmt.Printf("\"repository\": %q\n", repo)
	}
	if digest, ok := image["digest"]; ok {
		fmt.Printf("\"digest\": %q\n", digest)
	}
	if previewID, ok := pipeline["previewId"]; ok {
		fmt.Printf("\"previewId\": %q\n", previewID)
	}
	if baseline, ok := pipeline["baselineEnvironment"]; ok {
		fmt.Printf("\"baselineEnvironment\": %q\n", baseline)
	}
	for key, value := range runtimeDeps {
		fmt.Printf("\"%s\": %q\n", key, value)
	}
}

func mapStringMap(value any) map[string]string {
	rawMap, ok := value.(map[string]any)
	if !ok {
		return map[string]string{}
	}
	result := map[string]string{}
	for key, item := range rawMap {
		result[key] = fmt.Sprint(item)
	}
	return result
}

func handleFakeImage(service string) {
	args := os.Args[1:]
	imageRepository := ""
	imageTag := ""
	digestFile := ""
	for index := 0; index < len(args); index++ {
		switch args[index] {
		case "--image-repository":
			index++
			imageRepository = args[index]
		case "--image-tag":
			index++
			imageTag = args[index]
		case "--digest-file":
			index++
			digestFile = args[index]
		default:
			fmt.Fprintf(os.Stderr, "unexpected arg: %s\n", args[index])
			os.Exit(1)
		}
	}
	if imageRepository == "" || imageTag == "" || digestFile == "" {
		fmt.Fprintln(os.Stderr, "image_runner requires --image-repository, --image-tag, and --digest-file")
		os.Exit(1)
	}
	sum := sha256.Sum256([]byte(service + ":" + imageRepository + ":" + imageTag))
	digest := "sha256:" + hex.EncodeToString(sum[:])
	_ = os.WriteFile(digestFile, []byte(digest+"\n"), 0o644)
	fmt.Fprintf(os.Stderr, "built %s -> %s@%s\n", service, imageRepository, digest)
}
