package main

import (
	"fmt"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		fatalf("expected subcommand")
	}

	var err error
	switch os.Args[1] {
	case "workspace":
		err = runWorkspace(os.Args[2:])
	case "wire":
		err = runWire(os.Args[2:])
	case "migrate":
		err = runMigrate(os.Args[2:])
	case "copyright":
		err = runCopyright(os.Args[2:])
	case "devx":
		err = runDevx(os.Args[2:])
	case "shell":
		err = runShell(os.Args[2:])
	case "changelog":
		err = runChangelog(os.Args[2:])
	case "python-launch":
		err = runPythonLaunch(os.Args[2:])
	default:
		err = fmt.Errorf("unsupported subcommand: %s", os.Args[1])
	}
	if err != nil {
		fatalf("%v", err)
	}
}
