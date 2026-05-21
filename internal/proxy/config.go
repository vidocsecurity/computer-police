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
	if global && pipAvailable() {
		path, err := userPipConfPath()
		if err != nil {
			return nil, err
		}
		managers = append(managers, packageManagerConfig{
			Name:    "pip",
			Path:    path,
			Enable:  func(registry string) error { return setPipConf(path, pypiSimpleRegistry(registry)) },
			Disable: func() error { return restoreFile(path) },
		})
	}
	if executableExists("uv") {
		paths := []string{filepath.Join(projectDir, "uv.toml")}
		if global {
			uvPaths, err := userUVConfigPaths()
			if err != nil {
				return nil, err
			}
			paths = uvPaths
		} else {
			paths = append(paths, nestedConfigPaths(projectDir, "uv.toml")...)
		}
		for _, path := range uniquePaths(paths) {
			path := path
			managers = append(managers, packageManagerConfig{
				Name:    "uv",
				Path:    path,
				Enable:  func(registry string) error { return setUVConfig(path, pypiSimpleRegistry(registry)) },
				Disable: func() error { return restoreFile(path) },
			})
		}
	}
	if executableExists("poetry") {
		for _, path := range pythonProjectConfigPaths(projectDir) {
			path := path
			managers = append(managers, packageManagerConfig{
				Name:    "poetry",
				Path:    path,
				Enable:  func(registry string) error { return setPoetrySource(path, pypiSimpleRegistry(registry)) },
				Disable: func() error { return restoreFile(path) },
			})
		}
	}
	if executableExists("pdm") {
		for _, path := range pythonProjectConfigPaths(projectDir) {
			path := path
			managers = append(managers, packageManagerConfig{
				Name:    "pdm",
				Path:    path,
				Enable:  func(registry string) error { return setPDMSource(path, pypiSimpleRegistry(registry)) },
				Disable: func() error { return restoreFile(path) },
			})
		}
	}
	if global && executableExists("pipx") {
		path, err := userPipConfPath()
		if err != nil {
			return nil, err
		}
		managers = append(managers, packageManagerConfig{
			Name:    "pipx",
			Path:    path,
			Enable:  func(registry string) error { return setPipConf(path, pypiSimpleRegistry(registry)) },
			Disable: func() error { return restoreFile(path) },
		})
	}
	return managers, nil
}

func pythonProjectConfigPaths(projectDir string) []string {
	paths := []string{}
	root := filepath.Join(projectDir, "pyproject.toml")
	if _, err := os.Stat(root); err == nil {
		paths = append(paths, root)
	}
	for _, path := range nestedConfigPaths(projectDir, "pyproject.toml") {
		paths = append(paths, path)
	}
	return uniquePaths(paths)
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

func pipAvailable() bool {
	if executableExists("pip") || executableExists("pip3") {
		return true
	}
	return executableExists("python") || executableExists("python3")
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

func setPipConf(path, registry string) error {
	content, existed, err := readExisting(path)
	if err != nil {
		return err
	}
	if err := backupOriginal(path, content, existed); err != nil {
		return err
	}
	lines := setINISectionKeys(splitLines(content), "global", map[string]string{
		"index-url":       registry,
		"extra-index-url": registry,
		"trusted-host":    proxyHost(registry),
	})
	return writeConfigFile(path, strings.Join(nonEmptyTrailing(lines), "\n")+"\n")
}

func setUVConfig(path, registry string) error {
	content, existed, err := readExisting(path)
	if err != nil {
		return err
	}
	if err := backupOriginal(path, content, existed); err != nil {
		return err
	}
	lines := setTopLevelTOMLKeys(splitLines(content), map[string]string{
		"index-url":           fmt.Sprintf("%q", registry),
		"allow-insecure-host": fmt.Sprintf("[%q]", proxyHost(registry)),
	})
	return writeConfigFile(path, strings.Join(nonEmptyTrailing(lines), "\n")+"\n")
}

func setPoetrySource(path, registry string) error {
	return appendPyProjectSource(path, "tool.poetry.source", []string{
		`name = "computer-police"`,
		fmt.Sprintf("url = %q", registry),
		`priority = "primary"`,
	})
}

func setPDMSource(path, registry string) error {
	return appendPyProjectSource(path, "tool.pdm.source", []string{
		`name = "computer-police"`,
		fmt.Sprintf("url = %q", registry),
		"verify_ssl = false",
	})
}

func appendPyProjectSource(path, table string, entry []string) error {
	content, existed, err := readExisting(path)
	if err != nil {
		return err
	}
	if err := backupOriginal(path, content, existed); err != nil {
		return err
	}
	lines := removeNamedTOMLArrayTable(splitLines(content), table, "computer-police")
	header := "[[" + table + "]]"
	if len(nonEmptyTrailing(lines)) > 0 {
		lines = append(lines, "")
	}
	lines = append(lines, header)
	lines = append(lines, entry...)
	return writeConfigFile(path, strings.Join(nonEmptyTrailing(lines), "\n")+"\n")
}

func removeNamedTOMLArrayTable(lines []string, table, name string) []string {
	header := "[[" + table + "]]"
	out := make([]string, 0, len(lines))
	for i := 0; i < len(lines); {
		if strings.TrimSpace(lines[i]) != header {
			out = append(out, lines[i])
			i++
			continue
		}
		j := i + 1
		for j < len(lines) {
			trimmed := strings.TrimSpace(lines[j])
			if strings.HasPrefix(trimmed, "[") {
				break
			}
			j++
		}
		if tomlBlockHasName(lines[i:j], name) {
			i = j
			continue
		}
		out = append(out, lines[i:j]...)
		i = j
	}
	return out
}

func tomlBlockHasName(lines []string, name string) bool {
	want := fmt.Sprintf("%q", name)
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		key, value, ok := strings.Cut(trimmed, "=")
		if !ok || strings.TrimSpace(key) != "name" {
			continue
		}
		if strings.TrimSpace(value) == want {
			return true
		}
	}
	return false
}

func setINISectionKeys(lines []string, section string, keys map[string]string) []string {
	header := "[" + section + "]"
	inSection := false
	sawSection := false
	seen := map[string]bool{}
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			if inSection {
				var inserts []string
				for _, key := range configSortedKeys(keys) {
					if !seen[key] {
						inserts = append(inserts, key+" = "+keys[key])
					}
				}
				lines = insertLines(lines, i, inserts)
				i += len(inserts)
			}
			inSection = trimmed == header
			if inSection {
				sawSection = true
			}
			continue
		}
		if !inSection || strings.HasPrefix(trimmed, "#") || strings.HasPrefix(trimmed, ";") {
			continue
		}
		key, _, ok := strings.Cut(trimmed, "=")
		if !ok {
			key, _, ok = strings.Cut(trimmed, ":")
		}
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		if value, ok := keys[key]; ok {
			lines[i] = key + " = " + value
			seen[key] = true
		}
	}
	var inserts []string
	if !sawSection {
		if len(nonEmptyTrailing(lines)) > 0 {
			lines = append(lines, "")
		}
		inserts = append(inserts, header)
	}
	for _, key := range configSortedKeys(keys) {
		if !seen[key] {
			inserts = append(inserts, key+" = "+keys[key])
		}
	}
	return append(lines, inserts...)
}

func setTopLevelTOMLKeys(lines []string, keys map[string]string) []string {
	seen := map[string]bool{}
	insertAt := len(lines)
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "[") {
			insertAt = i
			break
		}
		key, _, ok := strings.Cut(trimmed, "=")
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		if value, ok := keys[key]; ok {
			lines[i] = key + " = " + value
			seen[key] = true
		}
	}
	var inserts []string
	for _, key := range configSortedKeys(keys) {
		if !seen[key] {
			inserts = append(inserts, key+" = "+keys[key])
		}
	}
	return insertLines(lines, insertAt, inserts)
}

func insertLines(lines []string, index int, inserts []string) []string {
	if len(inserts) == 0 {
		return lines
	}
	out := make([]string, 0, len(lines)+len(inserts))
	out = append(out, lines[:index]...)
	out = append(out, inserts...)
	out = append(out, lines[index:]...)
	return out
}

func configSortedKeys(keys map[string]string) []string {
	out := make([]string, 0, len(keys))
	for key := range keys {
		out = append(out, key)
	}
	sort.Strings(out)
	return out
}

func pypiSimpleRegistry(registry string) string {
	return strings.TrimRight(registry, "/") + "/simple/"
}

func proxyHost(registry string) string {
	host := strings.TrimPrefix(strings.TrimPrefix(strings.TrimRight(registry, "/"), "http://"), "https://")
	if before, _, ok := strings.Cut(host, "/"); ok {
		host = before
	}
	if before, _, ok := strings.Cut(host, ":"); ok {
		return before
	}
	return host
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
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	backup := path + ".computer-police-backup"
	marker := path + ".computer-police-created"
	if _, err := os.Stat(backup); err == nil {
		return nil
	}
	if existed {
		return os.WriteFile(backup, []byte(content), 0o644)
	}
	return os.WriteFile(marker, []byte("created by Computer Police registry proxy\n"), 0o644)
}

func writeConfigFile(path, content string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(content), 0o644)
}

func restoreFile(path string) error {
	backup := path + ".computer-police-backup"
	marker := path + ".computer-police-created"
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

func userPipConfPath() (string, error) {
	if configDir, err := os.UserConfigDir(); err == nil && configDir != "" {
		return filepath.Join(configDir, "pip", "pip.conf"), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".pip", "pip.conf"), nil
}

func userUVConfigPath() (string, error) {
	paths, err := userUVConfigPaths()
	if err != nil {
		return "", err
	}
	if len(paths) == 0 {
		return "", fmt.Errorf("no uv config path available")
	}
	return paths[0], nil
}

func userUVConfigPaths() ([]string, error) {
	var paths []string
	if xdg := os.Getenv("XDG_CONFIG_HOME"); xdg != "" {
		paths = append(paths, filepath.Join(xdg, "uv", "uv.toml"))
	}
	if configDir, err := os.UserConfigDir(); err == nil && configDir != "" {
		paths = append(paths, filepath.Join(configDir, "uv", "uv.toml"))
	}
	home, err := os.UserHomeDir()
	if err != nil {
		if len(paths) > 0 {
			return uniquePaths(paths), nil
		}
		return nil, err
	}
	paths = append(paths, filepath.Join(home, ".config", "uv", "uv.toml"))
	return uniquePaths(paths), nil
}
