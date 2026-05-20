package proxy

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
)

type EnableOptions struct {
	ProjectDir  string
	RegistryURL string
	Global      bool
}

type DisableOptions struct {
	ProjectDir string
	Global     bool
}

func EnableProject(out io.Writer, opts EnableOptions) error {
	dir := opts.ProjectDir
	if dir == "" {
		var err error
		dir, err = os.Getwd()
		if err != nil {
			return err
		}
	}
	registry := opts.RegistryURL
	if registry == "" {
		registry = fmt.Sprintf("http://%s:%d/", DefaultHost, DefaultPort)
	}

	managers, err := detectedSupportedManagers(opts.Global, dir)
	if err != nil {
		return err
	}
	if len(managers) == 0 {
		return fmt.Errorf("no supported package managers detected")
	}
	for _, manager := range managers {
		if err := manager.Enable(registry); err != nil {
			return err
		}
		fmt.Fprintf(out, "configured %s registry=%s (%s)\n", manager.Name, registry, manager.Path)
	}
	return nil
}

func DisableProject(out io.Writer, opts DisableOptions) error {
	dir := opts.ProjectDir
	if dir == "" {
		var err error
		dir, err = os.Getwd()
		if err != nil {
			return err
		}
	}
	managers, err := detectedSupportedManagers(opts.Global, dir)
	if err != nil {
		return err
	}
	if len(managers) == 0 {
		return fmt.Errorf("no supported package managers detected")
	}
	for _, manager := range managers {
		if err := manager.Disable(); err != nil {
			return err
		}
		fmt.Fprintf(out, "restored %s (%s)\n", manager.Name, manager.Path)
	}
	return nil
}

type packageManagerConfig struct {
	Name    string
	Path    string
	Enable  func(string) error
	Disable func() error
}

func detectedSupportedManagers(global bool, projectDir string) ([]packageManagerConfig, error) {
	var managers []packageManagerConfig
	if executableExists("npm") {
		paths := []string{filepath.Join(projectDir, ".npmrc")}
		if global {
			var err error
			path, err := userNPMRCPath()
			if err != nil {
				return nil, err
			}
			paths = []string{path}
		} else {
			paths = append(paths, nestedConfigPaths(projectDir, ".npmrc")...)
		}
		for _, path := range uniquePaths(paths) {
			path := path
			managers = append(managers, packageManagerConfig{
				Name:    "npm",
				Path:    path,
				Enable:  func(registry string) error { return setNPMRC(path, registry) },
				Disable: func() error { return restoreFile(path) },
			})
		}
	}
	if bunAvailable() {
		paths := []string{filepath.Join(projectDir, "bunfig.toml")}
		if global {
			var err error
			path, err := userBunfigPath()
			if err != nil {
				return nil, err
			}
			paths = []string{path}
		} else {
			paths = append(paths, nestedConfigPaths(projectDir, "bunfig.toml")...)
		}
		for _, path := range uniquePaths(paths) {
			path := path
			managers = append(managers, packageManagerConfig{
				Name:    "bun",
				Path:    path,
				Enable:  func(registry string) error { return setBunfig(path, strings.TrimRight(registry, "/")) },
				Disable: func() error { return restoreFile(path) },
			})
		}
	}
	return managers, nil
}

func nestedConfigPaths(root, name string) []string {
	var paths []string
	_ = filepath.WalkDir(root, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if entry.IsDir() {
			if path != root && skipConfigWalkDir(entry.Name()) {
				return filepath.SkipDir
			}
			return nil
		}
		if entry.Name() == name && filepath.Dir(path) != root {
			paths = append(paths, path)
		}
		return nil
	})
	sort.Strings(paths)
	return paths
}

func skipConfigWalkDir(name string) bool {
	switch name {
	case ".git", ".hg", ".svn", ".build", ".next", ".turbo", "node_modules", "vendor":
		return true
	default:
		return false
	}
}

func uniquePaths(paths []string) []string {
	seen := map[string]struct{}{}
	var unique []string
	for _, path := range paths {
		cleaned := filepath.Clean(path)
		if _, ok := seen[cleaned]; ok {
			continue
		}
		seen[cleaned] = struct{}{}
		unique = append(unique, cleaned)
	}
	return unique
}

func executableExists(name string) bool {
	_, ok := resolveExecutable(name)
	return ok
}

func bunAvailable() bool {
	_, ok := resolveExecutable("bun", bunExecutableFallbacks()...)
	return ok
}

func resolveExecutable(name string, fallbackPaths ...string) (string, bool) {
	if path, err := exec.LookPath(name); err == nil {
		return path, true
	}
	for _, path := range fallbackPaths {
		if executableFile(path) {
			return path, true
		}
	}
	return "", false
}

func executableFile(path string) bool {
	if path == "" {
		return false
	}
	info, err := os.Stat(path)
	if err != nil || info.IsDir() {
		return false
	}
	if runtime.GOOS == "windows" {
		return true
	}
	return info.Mode()&0o111 != 0
}

func bunExecutableFallbacks() []string {
	home, _ := os.UserHomeDir()
	var paths []string
	if install := os.Getenv("BUN_INSTALL"); install != "" {
		paths = append(paths, filepath.Join(install, "bin", executableName("bun")))
	}
	if home != "" {
		paths = append(paths, filepath.Join(home, ".bun", "bin", executableName("bun")))
	}
	switch runtime.GOOS {
	case "darwin":
		paths = append(paths,
			"/opt/homebrew/bin/bun",
			"/usr/local/bin/bun")
	case "linux":
		paths = append(paths,
			"/usr/local/bin/bun",
			"/usr/bin/bun")
	}
	return paths
}

func executableName(name string) string {
	if runtime.GOOS == "windows" {
		return name + ".exe"
	}
	return name
}

func setNPMRC(path, registry string) error {
	content, existed, err := readExisting(path)
	if err != nil {
		return err
	}
	if err := backupOriginal(path, content, existed); err != nil {
		return err
	}
	lines := splitLines(content)
	found := false
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "registry=") {
			lines[i] = "registry=" + registry
			found = true
		}
	}
	if !found {
		lines = append(lines, "registry="+registry)
	}
	return os.WriteFile(path, []byte(strings.Join(nonEmptyTrailing(lines), "\n")+"\n"), 0o644)
}

func setBunfig(path, registry string) error {
	content, existed, err := readExisting(path)
	if err != nil {
		return err
	}
	if err := backupOriginal(path, content, existed); err != nil {
		return err
	}
	lines := splitLines(content)
	inInstall := false
	sawInstall := false
	setRegistry := false
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			inInstall = trimmed == "[install]"
			if inInstall {
				sawInstall = true
			}
			continue
		}
		if inInstall && strings.HasPrefix(trimmed, "registry") {
			lines[i] = fmt.Sprintf("registry = %q", registry)
			setRegistry = true
		}
	}
	if !sawInstall {
		if len(nonEmptyTrailing(lines)) > 0 {
			lines = append(lines, "")
		}
		lines = append(lines, "[install]", fmt.Sprintf("registry = %q", registry))
	} else if !setRegistry {
		out := make([]string, 0, len(lines)+1)
		inserted := false
		for _, line := range lines {
			out = append(out, line)
			if !inserted && strings.TrimSpace(line) == "[install]" {
				out = append(out, fmt.Sprintf("registry = %q", registry))
				inserted = true
			}
		}
		lines = out
	}
	return os.WriteFile(path, []byte(strings.Join(nonEmptyTrailing(lines), "\n")+"\n"), 0o644)
}

func readExisting(path string) (string, bool, error) {
	data, err := os.ReadFile(path)
	if err == nil {
		return string(data), true, nil
	}
	if os.IsNotExist(err) {
		return "", false, nil
	}
	return "", false, err
}

func backupOriginal(path, content string, existed bool) error {
	backup := path + ".package-police-backup"
	marker := path + ".package-police-created"
	if _, err := os.Stat(backup); err == nil {
		return nil
	}
	if existed {
		return os.WriteFile(backup, []byte(content), 0o644)
	}
	return os.WriteFile(marker, []byte("created by package-police registry proxy\n"), 0o644)
}

func restoreFile(path string) error {
	backup := path + ".package-police-backup"
	marker := path + ".package-police-created"
	if data, err := os.ReadFile(backup); err == nil {
		if err := os.WriteFile(path, data, 0o644); err != nil {
			return err
		}
		_ = os.Remove(backup)
		_ = os.Remove(marker)
		return nil
	}
	if _, err := os.Stat(marker); err == nil {
		_ = os.Remove(path)
		_ = os.Remove(marker)
		return nil
	}
	return nil
}

func splitLines(content string) []string {
	content = strings.ReplaceAll(content, "\r\n", "\n")
	content = strings.TrimSuffix(content, "\n")
	if content == "" {
		return nil
	}
	return strings.Split(content, "\n")
}

func nonEmptyTrailing(lines []string) []string {
	for len(lines) > 0 && strings.TrimSpace(lines[len(lines)-1]) == "" {
		lines = lines[:len(lines)-1]
	}
	return lines
}

func userNPMRCPath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".npmrc"), nil
}

func userBunfigPath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	candidates := []string{}
	if xdg := os.Getenv("XDG_CONFIG_HOME"); xdg != "" {
		candidates = append(candidates,
			filepath.Join(xdg, "bun", "bunfig.toml"),
			filepath.Join(xdg, ".bunfig.toml"))
	}
	if configDir, err := os.UserConfigDir(); err == nil && configDir != "" {
		candidates = append(candidates, filepath.Join(configDir, "bun", "bunfig.toml"))
	}
	candidates = append(candidates, filepath.Join(home, ".bunfig.toml"))
	for _, path := range candidates {
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
	}
	if runtime.GOOS == "windows" && len(candidates) > 0 {
		return candidates[0], nil
	}
	return filepath.Join(home, ".bunfig.toml"), nil
}
