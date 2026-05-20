package shim

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"

	"github.com/vidoc/package-police/internal/collector"
	"github.com/vidoc/package-police/internal/config"
	"github.com/vidoc/package-police/internal/paths"
)

var observed = map[string]map[string]bool{
	"npm":  {"install": true, "i": true, "update": true, "ci": true, "uninstall": true, "remove": true, "rm": true},
	"pnpm": {"install": true, "add": true, "update": true, "remove": true},
	"yarn": {"install": true, "add": true, "up": true, "upgrade": true, "remove": true},
	"bun":  {"install": true, "add": true, "update": true, "remove": true},
}

func Run(pm string, args []string, version string) int {
	real := resolveReal(pm)
	if real == "" {
		return 127
	}
	if !IsObserved(pm, args) {
		return runReal(real, args)
	}

	start := time.Now().UTC()
	cwd, _ := os.Getwd()
	before := collector.CaptureState(cwd, pm)
	code := runReal(real, args)
	end := time.Now().UTC()

	capture := collector.Capture{
		TimestampStart: start,
		TimestampEnd:   end,
		CWD:            cwd,
		PackageManager: pm,
		Argv:           args,
		ExitCode:       code,
		Before:         before,
	}
	if err := spawnCollector(capture); err != nil {
		collector.Debugf("spawn collector failed: %v", err)
	}
	return code
}

func IsObserved(pm string, args []string) bool {
	if len(args) == 0 {
		return pm == "npm" || pm == "pnpm" || pm == "yarn" || pm == "bun"
	}
	cmd := args[0]
	return observed[pm][cmd]
}

func resolveReal(pm string) string {
	cfg := config.Load()
	if real := cfg.RealBinaries[pm]; real != "" {
		if info, err := os.Stat(real); err == nil && !info.IsDir() {
			return real
		}
	}
	return config.FindRealBinary(pm)
}

func runReal(real string, args []string) int {
	cmd := exec.Command(real, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		if exit, ok := err.(*exec.ExitError); ok {
			if status, ok := exit.Sys().(syscall.WaitStatus); ok {
				return status.ExitStatus()
			}
		}
		return 1
	}
	return 0
}

func spawnCollector(capture collector.Capture) error {
	dir := filepath.Join(paths.Home(), "tmp")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	file, err := os.CreateTemp(dir, "capture-*.json")
	if err != nil {
		return err
	}
	encErr := json.NewEncoder(file).Encode(capture)
	closeErr := file.Close()
	if encErr != nil {
		return encErr
	}
	if closeErr != nil {
		return closeErr
	}
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	cmd := exec.Command(exe, "__collect", file.Name())
	cmd.Stdin = nil
	cmd.Stdout = nil
	cmd.Stderr = nil
	if err := cmd.Start(); err != nil {
		return err
	}
	return cmd.Process.Release()
}
