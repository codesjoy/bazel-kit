package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type changelogState struct {
	BaseSHA       string
	LastSHA       string
	CurrentBucket string
}

func runChangelog(args []string) error {
	fs := flag.NewFlagSet("changelog", flag.ContinueOnError)
	fs.SetOutput(ioDiscard{})

	var kind string
	var tool string
	var changelogFile string
	var configFile string
	var templateFile string
	var query string
	var fromRef string
	var toRef string
	var nextTag string
	var pathFilters stringListFlag
	var sortMode string
	var profile string
	var cadence string
	var useBaseline string
	var archiveEnable string
	var stateFile string
	var archiveDir string
	var now string
	strictState := false

	fs.StringVar(&kind, "kind", "", "")
	fs.StringVar(&tool, "tool", "", "")
	fs.StringVar(&changelogFile, "changelog-file", "CHANGELOG.md", "")
	fs.StringVar(&configFile, "config", ".chglog/config.yml", "")
	fs.StringVar(&templateFile, "template", ".chglog/CHANGELOG.tpl.md", "")
	fs.StringVar(&query, "query", "", "")
	fs.StringVar(&fromRef, "from-ref", "", "")
	fs.StringVar(&toRef, "to-ref", "", "")
	fs.StringVar(&nextTag, "next-tag", "unreleased", "")
	fs.Var(&pathFilters, "path-filter", "")
	fs.StringVar(&sortMode, "sort", "date", "")
	fs.StringVar(&profile, "profile", "balanced", "")
	fs.StringVar(&cadence, "cadence", "", "")
	fs.StringVar(&useBaseline, "use-baseline", "", "")
	fs.StringVar(&archiveEnable, "archive-enable", "", "")
	fs.StringVar(&stateFile, "state-file", ".chglog/state.env", "")
	fs.StringVar(&archiveDir, "archive-dir", ".chglog/archive", "")
	fs.StringVar(&now, "now", "", "")
	fs.BoolVar(&strictState, "strict-state", false, "")
	if err := fs.Parse(args); err != nil {
		return err
	}

	workspace, err := workspaceRoot()
	if err != nil {
		return err
	}

	cfg := changelogConfig{
		workspace:     workspace,
		tool:          tool,
		kind:          kind,
		changelogFile: changelogFile,
		configFile:    configFile,
		templateFile:  templateFile,
		query:         query,
		fromRef:       fromRef,
		toRef:         toRef,
		nextTag:       nextTag,
		pathFilters:   pathFilters,
		sortMode:      sortMode,
		profile:       profile,
		cadence:       cadence,
		useBaseline:   useBaseline,
		archiveEnable: archiveEnable,
		stateFile:     stateFile,
		archiveDir:    archiveDir,
		now:           now,
		strictState:   strictState,
	}
	return cfg.run()
}

type changelogConfig struct {
	workspace     string
	tool          string
	kind          string
	changelogFile string
	configFile    string
	templateFile  string
	query         string
	fromRef       string
	toRef         string
	nextTag       string
	pathFilters   []string
	sortMode      string
	profile       string
	cadence       string
	useBaseline   string
	archiveEnable string
	stateFile     string
	archiveDir    string
	now           string
	strictState   bool
}

func (c changelogConfig) run() error {
	switch c.kind {
	case "init":
		return c.init()
	case "generate":
		return c.generate()
	case "preview":
		return c.preview()
	case "verify":
		return c.verify()
	case "state_print":
		return c.statePrint()
	case "state_reset":
		return c.stateReset()
	default:
		return fmt.Errorf("Unsupported changelog action: %s", c.kind)
	}
}

func (c changelogConfig) resolvedCadence() (string, error) {
	defaultCadence, _, _, err := changelogProfileDefaults(c.profile)
	if err != nil {
		return "", err
	}
	value := c.cadence
	if value == "" {
		value = defaultCadence
	}
	switch value {
	case "monthly", "weekly", "none":
		return value, nil
	default:
		return "", fmt.Errorf("Unsupported CHANGELOG_CADENCE: %s", value)
	}
}

func (c changelogConfig) resolvedUseBaseline() (bool, error) {
	_, defaultValue, _, err := changelogProfileDefaults(c.profile)
	if err != nil {
		return false, err
	}
	return parseOptionalToggle("CHANGELOG_USE_BASELINE", c.useBaseline, defaultValue)
}

func (c changelogConfig) resolvedArchiveEnable() (bool, error) {
	_, _, defaultValue, err := changelogProfileDefaults(c.profile)
	if err != nil {
		return false, err
	}
	return parseOptionalToggle("CHANGELOG_ARCHIVE_ENABLE", c.archiveEnable, defaultValue)
}

func changelogProfileDefaults(profile string) (string, bool, bool, error) {
	switch profile {
	case "simple":
		return "none", false, false, nil
	case "balanced":
		return "monthly", true, true, nil
	case "high-frequency":
		return "weekly", true, true, nil
	default:
		return "", false, false, fmt.Errorf("Unsupported CHANGELOG_PROFILE: %s", profile)
	}
}

func parseOptionalToggle(name, raw string, defaultValue bool) (bool, error) {
	if raw == "" {
		return defaultValue, nil
	}
	switch raw {
	case "0":
		return false, nil
	case "1":
		return true, nil
	default:
		return false, fmt.Errorf("%s must be 0 or 1, got: %s", name, raw)
	}
}

func (c changelogConfig) ensureRenderPrereqs() error {
	if c.tool == "" {
		return fmt.Errorf("Required tool %q not found", c.tool)
	}
	if _, err := os.Stat(maybeJoinWorkspace(c.workspace, c.configFile)); err != nil {
		return fmt.Errorf("Required file %q not found", maybeJoinWorkspace(c.workspace, c.configFile))
	}
	if _, err := os.Stat(maybeJoinWorkspace(c.workspace, c.templateFile)); err != nil {
		return fmt.Errorf("Required file %q not found", maybeJoinWorkspace(c.workspace, c.templateFile))
	}
	return nil
}

func gitCapture(workspace string, args ...string) (string, error) {
	output, err := captureTrimmed(commandSpec{
		name: "git",
		args: args,
		dir:  workspace,
	})
	if err != nil {
		return "", err
	}
	return output, nil
}

func gitOptional(workspace string, args ...string) string {
	output, err := captureTrimmed(commandSpec{
		name: "git",
		args: args,
		dir:  workspace,
	})
	if err != nil {
		return ""
	}
	return output
}

func (c changelogConfig) init() error {
	infof("Initializing changelog scaffold")
	configPath := maybeJoinWorkspace(c.workspace, c.configFile)
	templatePath := maybeJoinWorkspace(c.workspace, c.templateFile)
	statePath := maybeJoinWorkspace(c.workspace, c.stateFile)
	archivePath := maybeJoinWorkspace(c.workspace, c.archiveDir)

	for _, path := range []string{filepath.Dir(configPath), filepath.Dir(templatePath), filepath.Dir(statePath), archivePath} {
		if err := os.MkdirAll(path, 0o755); err != nil {
			return err
		}
	}
	if err := writeIfMissing(configPath, []byte(c.renderDefaultConfig())); err != nil {
		return err
	}
	if err := writeIfMissing(templatePath, []byte(defaultChangelogTemplate)); err != nil {
		return err
	}
	if err := writeIfMissing(filepath.Join(filepath.Dir(statePath), "state.env.example"), []byte(defaultStateExample)); err != nil {
		return err
	}
	if err := writeIfMissing(filepath.Join(archivePath, ".gitkeep"), []byte("")); err != nil {
		return err
	}
	successf("Changelog scaffold initialization complete")
	return nil
}

func writeIfMissing(path string, data []byte) error {
	if _, err := os.Stat(path); err == nil {
		warnf("File exists, skipping: %s", path)
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	if err := writeFileLF(path, data); err != nil {
		return err
	}
	successf("Created file: %s", path)
	return nil
}

func (c changelogConfig) renderDefaultConfig() string {
	repoURL := gitOptional(c.workspace, "config", "--get", "remote.origin.url")
	if repoURL == "" {
		repoURL = "https://example.com/repo"
	}
	return fmt.Sprintf(`style: github
template: .chglog/CHANGELOG.tpl.md
info:
  title: CHANGELOG
  repository_url: %s
options:
  commits:
    filters:
      Type:
        - feat
        - fix
        - docs
        - style
        - refactor
        - perf
        - test
        - build
        - ci
        - chore
        - revert
  commit_groups:
    title_maps:
      feat: Features
      fix: Bug Fixes
      docs: Documentation
      style: Styles
      refactor: Refactors
      perf: Performance Improvements
      test: Tests
      build: Build System
      ci: CI
      chore: Chores
      revert: Reverts
  header:
    pattern: '^([[:alnum:]]+)(?:\(([[:alnum:]_./\-\s]+)\))?(!)?:\s(.+)$'
    pattern_maps:
      - Type
      - Scope
      - Breaking
      - Subject
  notes:
    keywords:
      - BREAKING CHANGE
`, repoURL)
}

func (c changelogConfig) loadState() (changelogState, error) {
	path := maybeJoinWorkspace(c.workspace, c.stateFile)
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return changelogState{}, nil
	}
	if err != nil {
		return changelogState{}, err
	}
	state := changelogState{}
	for _, line := range strings.Split(string(normalizeLF(data)), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			if c.strictState {
				return changelogState{}, fmt.Errorf("State file is malformed: %s", path)
			}
			continue
		}
		switch parts[0] {
		case "BASE_SHA":
			state.BaseSHA = parts[1]
		case "LAST_SHA":
			state.LastSHA = parts[1]
		case "CURRENT_BUCKET":
			state.CurrentBucket = parts[1]
		default:
			if c.strictState {
				return changelogState{}, fmt.Errorf("State file is malformed: %s", path)
			}
		}
	}
	return state, nil
}

func (c changelogConfig) writeState(state changelogState) error {
	content := fmt.Sprintf("BASE_SHA=%s\nLAST_SHA=%s\nCURRENT_BUCKET=%s\n", state.BaseSHA, state.LastSHA, state.CurrentBucket)
	path := maybeJoinWorkspace(c.workspace, c.stateFile)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return writeFileLF(path, []byte(content))
}

func (c changelogConfig) repoHasTags() bool {
	return gitOptional(c.workspace, "tag", "--list") != ""
}

func (c changelogConfig) resolvedManualQuery() string {
	if c.query != "" {
		return c.query
	}
	if c.fromRef != "" && c.toRef != "" {
		return c.fromRef + ".." + c.toRef
	}
	if c.fromRef != "" {
		return c.fromRef + ".."
	}
	if c.toRef != "" {
		return ".." + c.toRef
	}
	return ""
}

func (c changelogConfig) resolvedQuery(state changelogState, useBaseline bool) string {
	if manual := c.resolvedManualQuery(); manual != "" {
		return manual
	}
	if useBaseline && state.BaseSHA != "" {
		return state.BaseSHA + "..HEAD"
	}
	return ""
}

func (c changelogConfig) computeBucket(cadence string) (string, error) {
	if cadence == "none" {
		return "none", nil
	}
	nowValue := c.now
	if nowValue == "" {
		nowValue = time.Now().Format("2006-01-02")
	}
	parsed, err := time.Parse("2006-01-02", nowValue[:10])
	if err != nil {
		return "", err
	}
	if cadence == "monthly" {
		return parsed.Format("2006-01"), nil
	}
	year, week := parsed.ISOWeek()
	return fmt.Sprintf("%04d-W%02d", year, week), nil
}

func (c changelogConfig) archivePreviousIfNeeded(state changelogState, nextBucket string, archiveEnabled bool) error {
	if !archiveEnabled || state.CurrentBucket == "" || state.CurrentBucket == "none" || state.CurrentBucket == nextBucket {
		return nil
	}
	source := maybeJoinWorkspace(c.workspace, c.changelogFile)
	if _, err := os.Stat(source); err != nil {
		return nil
	}
	destination := filepath.Join(maybeJoinWorkspace(c.workspace, c.archiveDir), "CHANGELOG-"+state.CurrentBucket+".md")
	if err := copyFile(source, destination); err != nil {
		return err
	}
	infof("Archived previous changelog bucket %s", state.CurrentBucket)
	return nil
}

func (c changelogConfig) runGitChglog(outputFile string, query string) error {
	runArgs := []string{"--config", maybeJoinWorkspace(c.workspace, c.configFile), "--template", maybeJoinWorkspace(c.workspace, c.templateFile), "--sort", c.sortMode}
	if !c.repoHasTags() {
		runArgs = append(runArgs, "--next-tag", c.nextTag)
	}
	if outputFile != "" {
		runArgs = append(runArgs, "--output", outputFile)
	}
	for _, path := range c.pathFilters {
		runArgs = append(runArgs, "--path", path)
	}
	if query != "" {
		runArgs = append(runArgs, query)
	}
	return runStreaming(commandSpec{
		name: c.tool,
		args: runArgs,
		dir:  c.workspace,
	})
}

func (c changelogConfig) generate() error {
	if err := c.ensureRenderPrereqs(); err != nil {
		return err
	}
	cadence, err := c.resolvedCadence()
	if err != nil {
		return err
	}
	useBaseline, err := c.resolvedUseBaseline()
	if err != nil {
		return err
	}
	archiveEnabled, err := c.resolvedArchiveEnable()
	if err != nil {
		return err
	}
	state, err := c.loadState()
	if err != nil {
		return err
	}
	nextBucket, err := c.computeBucket(cadence)
	if err != nil {
		return err
	}
	if err := c.archivePreviousIfNeeded(state, nextBucket, archiveEnabled); err != nil {
		return err
	}
	target := maybeJoinWorkspace(c.workspace, c.changelogFile)
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return err
	}
	if err := c.runGitChglog(target, c.resolvedQuery(state, useBaseline)); err != nil {
		return err
	}
	head, err := gitCapture(c.workspace, "rev-parse", "HEAD")
	if err != nil {
		return err
	}
	state.LastSHA = head
	if useBaseline {
		state.BaseSHA = head
	}
	state.CurrentBucket = nextBucket
	if err := c.writeState(state); err != nil {
		return err
	}
	successf("Generated %s", target)
	return nil
}

func (c changelogConfig) preview() error {
	if err := c.ensureRenderPrereqs(); err != nil {
		return err
	}
	useBaseline, err := c.resolvedUseBaseline()
	if err != nil {
		return err
	}
	state, err := c.loadState()
	if err != nil {
		return err
	}
	return c.runGitChglog("", c.resolvedQuery(state, useBaseline))
}

func (c changelogConfig) verify() error {
	if err := c.ensureRenderPrereqs(); err != nil {
		return err
	}
	useBaseline, err := c.resolvedUseBaseline()
	if err != nil {
		return err
	}
	target := maybeJoinWorkspace(c.workspace, c.changelogFile)
	actual, err := os.ReadFile(target)
	if err != nil {
		return fmt.Errorf("%s not found", target)
	}
	tempFile, err := os.CreateTemp("", "changelog-verify-*")
	if err != nil {
		return err
	}
	tempPath := tempFile.Name()
	tempFile.Close()
	defer os.Remove(tempPath)

	state, err := c.loadState()
	if err != nil {
		return err
	}
	if err := c.runGitChglog(tempPath, c.resolvedQuery(state, useBaseline)); err != nil {
		return err
	}
	expected, err := os.ReadFile(tempPath)
	if err != nil {
		return err
	}
	if !bytes.Equal(normalizeLF(actual), normalizeLF(expected)) {
		return fmt.Errorf("CHANGELOG.md is out of date. Run changelog_generate.")
	}
	successf("CHANGELOG.md is up to date")
	return nil
}

func (c changelogConfig) statePrint() error {
	cadence, err := c.resolvedCadence()
	if err != nil {
		return err
	}
	useBaseline, err := c.resolvedUseBaseline()
	if err != nil {
		return err
	}
	archiveEnabled, err := c.resolvedArchiveEnable()
	if err != nil {
		return err
	}
	state, err := c.loadState()
	if err != nil {
		return err
	}
	fmt.Printf("CHANGELOG_PROFILE=%s\n", c.profile)
	fmt.Printf("CHANGELOG_CADENCE=%s\n", cadence)
	fmt.Printf("CHANGELOG_USE_BASELINE=%s\n", boolToToggle(useBaseline))
	fmt.Printf("CHANGELOG_ARCHIVE_ENABLE=%s\n", boolToToggle(archiveEnabled))
	fmt.Printf("BASE_SHA=%s\n", state.BaseSHA)
	fmt.Printf("LAST_SHA=%s\n", state.LastSHA)
	fmt.Printf("CURRENT_BUCKET=%s\n", state.CurrentBucket)
	fmt.Printf("RESOLVED_QUERY=%s\n", c.resolvedQuery(state, useBaseline))
	return nil
}

func boolToToggle(value bool) string {
	if value {
		return "1"
	}
	return "0"
}

func (c changelogConfig) stateReset() error {
	cadence, err := c.resolvedCadence()
	if err != nil {
		return err
	}
	head, err := gitCapture(c.workspace, "rev-parse", "HEAD")
	if err != nil {
		return err
	}
	bucket, err := c.computeBucket(cadence)
	if err != nil {
		return err
	}
	state := changelogState{
		BaseSHA:       head,
		LastSHA:       head,
		CurrentBucket: bucket,
	}
	if err := c.writeState(state); err != nil {
		return err
	}
	successf("Changelog state reset to HEAD")
	return nil
}

const defaultChangelogTemplate = `{{- range .Versions }}
## {{- if .Tag.Previous }} [{{ .Tag.Name }}]({{ $.Info.RepositoryURL }}/compare/{{ .Tag.Previous.Name }}...{{ .Tag.Name }}){{- else }} {{ .Tag.Name }}{{- end }} ({{ datetime "2006-01-02" .Tag.Date }})

{{- range .CommitGroups }}
### {{ .Title }}

{{- range .Commits }}
- {{- if .Scope }} **{{ .Scope }}:** {{- end }} {{ .Subject }}
{{- end }}
{{- end }}

{{- if .NoteGroups }}
{{- range .NoteGroups }}
### {{ .Title }}

{{- range .Notes }}
{{ .Body }}
{{- end }}
{{- end }}
{{- end }}

{{- end }}
`

const defaultStateExample = `# Changelog state file example.
BASE_SHA=
LAST_SHA=
CURRENT_BUCKET=
`
