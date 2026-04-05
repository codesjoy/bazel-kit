package main

import (
	"flag"
	"fmt"
)

func runPythonLaunch(args []string) error {
	fs := flag.NewFlagSet("python-launch", flag.ContinueOnError)
	fs.SetOutput(ioDiscard{})

	var script string
	var envPairs envPairFlag
	fs.StringVar(&script, "script", "", "")
	fs.Var(&envPairs, "env", "")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if script == "" {
		return fmt.Errorf("script is required")
	}
	python, err := resolvePython()
	if err != nil {
		return err
	}
	runArgs := append([]string{script}, fs.Args()...)
	return runStreaming(commandSpec{
		name:    python.name,
		preArgs: python.args,
		args:    runArgs,
		env:     envPairs,
	})
}
