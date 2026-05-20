package proxy

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

type EnableOptions struct {
	ProjectDir  string
	RegistryURL string
	Bun         bool
}

type DisableOptions struct {
	ProjectDir string
	Bun        bool
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
	if err := setNPMRC(filepath.Join(dir, ".npmrc"), registry); err != nil {
		return err
	}
	fmt.Fprintf(out, "configured .npmrc registry=%s\n", registry)
	if opts.Bun {
		if err := setBunfig(filepath.Join(dir, "bunfig.toml"), strings.TrimRight(registry, "/")); err != nil {
			return err
		}
		fmt.Fprintf(out, "configured bunfig.toml install.registry=%s\n", strings.TrimRight(registry, "/"))
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
	if err := restoreFile(filepath.Join(dir, ".npmrc")); err != nil {
		return err
	}
	fmt.Fprintln(out, "restored .npmrc")
	if opts.Bun {
		if err := restoreFile(filepath.Join(dir, "bunfig.toml")); err != nil {
			return err
		}
		fmt.Fprintln(out, "restored bunfig.toml")
	}
	return nil
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
