package config

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/vidoc/package-police/internal/agentdist"
	"github.com/vidoc/package-police/internal/paths"
)

var PackageManagers = []string{"npm", "pnpm", "yarn", "bun"}

type InitOptions struct {
	Repo             bool
	Claude           bool
	ConsentPathPatch bool
}

type UninstallOptions struct {
	DeleteLedger bool
}

type Config struct {
	RealBinaries map[string]string
}

func Init(out io.Writer, opts InitOptions) error {
	fmt.Fprintln(out, "Vidoc Agent Guard will install lightweight package-manager shims.")
	fmt.Fprintln(out)
	fmt.Fprintln(out, "Will collect: package names and versions, lockfile/package.json hashes, repo metadata, timestamp, and package-manager command metadata.")
	fmt.Fprintln(out, "Will not collect: source code, secrets, .env files, package contents, terminal output, or environment variable values.")
	fmt.Fprintln(out, "Mode: local-only")
	fmt.Fprintln(out)

	for _, dir := range []string{paths.Home(), paths.ShimsDir(), filepath.Dir(paths.LedgerPath()), filepath.Dir(paths.DebugLogPath())} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err
		}
	}

	cfg := Config{RealBinaries: map[string]string{}}
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	for _, pm := range PackageManagers {
		real := FindRealBinary(pm)
		if real != "" {
			cfg.RealBinaries[pm] = real
		}
		if err := writeShim(pm, exe); err != nil {
			return err
		}
		fmt.Fprintf(out, "Installed shim: %s\n", filepath.Join(paths.ShimsDir(), pm))
		if real != "" {
			fmt.Fprintf(out, "Resolved %s real binary: %s\n", pm, real)
		} else {
			fmt.Fprintf(out, "No %s binary found yet; shim will search PATH at runtime.\n", pm)
		}
	}
	if err := WriteConfig(cfg); err != nil {
		return err
	}
	fmt.Fprintf(out, "Wrote config: %s\n", paths.ConfigPath())

	if _, err := os.OpenFile(paths.LedgerPath(), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644); err != nil {
		return err
	}
	fmt.Fprintf(out, "Ledger ready: %s\n", paths.LedgerPath())

	if opts.ConsentPathPatch {
		if changed, err := patchShellProfile(); err != nil {
			return err
		} else if changed {
			fmt.Fprintln(out, "Updated shell profile with Vidoc shims PATH entry.")
		} else {
			fmt.Fprintln(out, "Shell profile already contains Vidoc shims PATH entry.")
		}
	} else {
		fmt.Fprintf(out, "Add this to PATH before package managers if needed: export PATH=\"%s:$PATH\"\n", paths.ShimsDir())
	}

	if opts.Repo {
		changed, err := agentdist.Install(".", agentdist.Options{Claude: opts.Claude})
		if err != nil {
			return err
		}
		for _, path := range changed {
			fmt.Fprintf(out, "Updated agent distribution file: %s\n", path)
		}
	}
	return nil
}

func Uninstall(out io.Writer, opts UninstallOptions) error {
	for _, pm := range PackageManagers {
		path := filepath.Join(paths.ShimsDir(), pm)
		if err := os.Remove(path); err == nil {
			fmt.Fprintf(out, "Removed shim: %s\n", path)
		}
	}
	if err := unpatchShellProfile(); err != nil {
		return err
	}
	fmt.Fprintln(out, "Removed Vidoc PATH marker from shell profile when present.")
	if opts.DeleteLedger {
		if err := os.Remove(paths.LedgerPath()); err == nil {
			fmt.Fprintf(out, "Deleted ledger: %s\n", paths.LedgerPath())
		}
	} else {
		fmt.Fprintf(out, "Preserved ledger: %s\n", paths.LedgerPath())
	}
	return nil
}

func writeShim(pm, exe string) error {
	body := fmt.Sprintf("#!/bin/sh\nexec %q __shim %s \"$@\"\n", exe, pm)
	path := filepath.Join(paths.ShimsDir(), pm)
	return os.WriteFile(path, []byte(body), 0o755)
}

func FindRealBinary(name string) string {
	pathEnv := os.Getenv("PATH")
	for _, dir := range filepath.SplitList(pathEnv) {
		if samePath(dir, paths.ShimsDir()) {
			continue
		}
		candidate := filepath.Join(dir, name)
		if info, err := os.Stat(candidate); err == nil && !info.IsDir() && info.Mode()&0o111 != 0 {
			return candidate
		}
	}
	return ""
}

func WriteConfig(cfg Config) error {
	var b strings.Builder
	b.WriteString("agent_guard:\n")
	b.WriteString("  enabled: true\n")
	b.WriteString("  mode: local-only\n")
	b.WriteString("  ledger_path: \"~/.vidoc/install-ledger/events.ndjson\"\n")
	b.WriteString("  collect:\n")
	b.WriteString("    package_names: true\n    package_versions: true\n    lockfile_hashes: true\n    repo_metadata: true\n    command_metadata: true\n")
	b.WriteString("    source_code: false\n    env_values: false\n    terminal_output: false\n")
	b.WriteString("  privacy:\n")
	b.WriteString("    hash_git_remote: true\n    hash_machine_id: true\n    include_absolute_paths_local: true\n    include_absolute_paths_sync: false\n")
	b.WriteString("  package_managers:\n")
	for _, pm := range PackageManagers {
		b.WriteString("    " + pm + ":\n")
		b.WriteString("      enabled: true\n")
		if real := cfg.RealBinaries[pm]; real != "" {
			b.WriteString(fmt.Sprintf("      real_binary: %q\n", real))
		} else {
			b.WriteString("      real_binary: \"\"\n")
		}
	}
	return os.WriteFile(paths.ConfigPath(), []byte(b.String()), 0o644)
}

func Load() Config {
	cfg := Config{RealBinaries: map[string]string{}}
	data, err := os.ReadFile(paths.ConfigPath())
	if err != nil {
		return cfg
	}
	lines := strings.Split(string(data), "\n")
	current := ""
	for _, line := range lines {
		trim := strings.TrimSpace(line)
		if strings.HasSuffix(trim, ":") {
			name := strings.TrimSuffix(trim, ":")
			for _, pm := range PackageManagers {
				if name == pm {
					current = pm
				}
			}
			continue
		}
		if strings.HasPrefix(trim, "real_binary:") && current != "" {
			value := strings.TrimSpace(strings.TrimPrefix(trim, "real_binary:"))
			value = strings.Trim(value, `"`)
			cfg.RealBinaries[current] = value
		}
	}
	return cfg
}

func patchShellProfile() (bool, error) {
	profile := filepath.Join(os.Getenv("HOME"), ".zshrc")
	marker := "# Vidoc Agent Guard shims"
	line := marker + "\nexport PATH=\"" + paths.ShimsDir() + ":$PATH\"\n"
	data, _ := os.ReadFile(profile)
	if strings.Contains(string(data), marker) {
		return false, nil
	}
	f, err := os.OpenFile(profile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return false, err
	}
	defer f.Close()
	_, err = f.WriteString("\n" + line)
	return err == nil, err
}

func unpatchShellProfile() error {
	profile := filepath.Join(os.Getenv("HOME"), ".zshrc")
	data, err := os.ReadFile(profile)
	if err != nil {
		return nil
	}
	lines := strings.Split(string(data), "\n")
	out := make([]string, 0, len(lines))
	skipNext := false
	for _, line := range lines {
		if skipNext {
			skipNext = false
			continue
		}
		if line == "# Vidoc Agent Guard shims" {
			skipNext = true
			continue
		}
		out = append(out, line)
	}
	return os.WriteFile(profile, []byte(strings.Join(out, "\n")), 0o644)
}

func samePath(a, b string) bool {
	aa, errA := filepath.EvalSymlinks(a)
	bb, errB := filepath.EvalSymlinks(b)
	if errA != nil {
		aa = filepath.Clean(a)
	}
	if errB != nil {
		bb = filepath.Clean(b)
	}
	return aa == bb
}
