package proxy

import (
	"bytes"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestEnableDisableProjectRestoresCustomRegistries(t *testing.T) {
	project := t.TempDir()
	fakeBin := t.TempDir()
	t.Setenv("PATH", fakeBin)
	writeFakeExecutable(t, fakeBin, "npm")
	writeFakeExecutable(t, fakeBin, "bun")

	npmrc := filepath.Join(project, ".npmrc")
	originalNPMRC := "always-auth=true\nregistry=https://registry.example.test/npm/\n"
	if err := os.WriteFile(npmrc, []byte(originalNPMRC), 0o644); err != nil {
		t.Fatal(err)
	}

	bunfig := filepath.Join(project, "bunfig.toml")
	originalBunfig := "[install]\nregistry = \"https://registry.example.test/bun/\"\n"
	if err := os.WriteFile(bunfig, []byte(originalBunfig), 0o644); err != nil {
		t.Fatal(err)
	}

	var out bytes.Buffer
	proxyRegistry := "http://127.0.0.1:4873/"
	if err := EnableProject(&out, EnableOptions{
		ProjectDir:  project,
		RegistryURL: proxyRegistry,
		Global:      false,
	}); err != nil {
		t.Fatalf("EnableProject failed: %v\n%s", err, out.String())
	}

	enabledNPMRC := readFile(t, npmrc)
	if !strings.Contains(enabledNPMRC, "registry="+proxyRegistry) {
		t.Fatalf(".npmrc was not pointed at proxy:\n%s", enabledNPMRC)
	}
	enabledBunfig := readFile(t, bunfig)
	if !strings.Contains(enabledBunfig, `registry = "http://127.0.0.1:4873"`) {
		t.Fatalf("bunfig.toml was not pointed at proxy:\n%s", enabledBunfig)
	}

	out.Reset()
	if err := DisableProject(&out, DisableOptions{
		ProjectDir: project,
		Global:     false,
	}); err != nil {
		t.Fatalf("DisableProject failed: %v\n%s", err, out.String())
	}

	if restored := readFile(t, npmrc); restored != originalNPMRC {
		t.Fatalf(".npmrc was not restored\nwant:\n%s\ngot:\n%s", originalNPMRC, restored)
	}
	if restored := readFile(t, bunfig); restored != originalBunfig {
		t.Fatalf("bunfig.toml was not restored\nwant:\n%s\ngot:\n%s", originalBunfig, restored)
	}
	if _, err := os.Stat(npmrc + ".computer-police-backup"); !os.IsNotExist(err) {
		t.Fatalf("npm backup was not removed after restore: %v", err)
	}
	if _, err := os.Stat(bunfig + ".computer-police-backup"); !os.IsNotExist(err) {
		t.Fatalf("bun backup was not removed after restore: %v", err)
	}
}

func TestEnableDisableProjectRemovesCreatedRegistryFiles(t *testing.T) {
	project := t.TempDir()
	fakeBin := t.TempDir()
	t.Setenv("PATH", fakeBin)
	writeFakeExecutable(t, fakeBin, "npm")
	writeFakeExecutable(t, fakeBin, "bun")

	var out bytes.Buffer
	if err := EnableProject(&out, EnableOptions{
		ProjectDir:  project,
		RegistryURL: "http://127.0.0.1:4873/",
		Global:      false,
	}); err != nil {
		t.Fatalf("EnableProject failed: %v\n%s", err, out.String())
	}

	out.Reset()
	if err := DisableProject(&out, DisableOptions{
		ProjectDir: project,
		Global:     false,
	}); err != nil {
		t.Fatalf("DisableProject failed: %v\n%s", err, out.String())
	}

	for _, name := range []string{".npmrc", "bunfig.toml"} {
		path := filepath.Join(project, name)
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Fatalf("%s should be removed after disable when created by Computer Police: %v", name, err)
		}
		if _, err := os.Stat(path + ".computer-police-created"); !os.IsNotExist(err) {
			t.Fatalf("%s creation marker should be removed after disable: %v", name, err)
		}
	}
}

func TestEnableDisableProjectRestoresPythonProjectConfigs(t *testing.T) {
	project := t.TempDir()
	fakeBin := t.TempDir()
	t.Setenv("PATH", fakeBin)
	writeFakeExecutable(t, fakeBin, "uv")
	writeFakeExecutable(t, fakeBin, "poetry")
	writeFakeExecutable(t, fakeBin, "pdm")

	pyproject := filepath.Join(project, "pyproject.toml")
	originalPyproject := "[project]\nname = \"example\"\nversion = \"0.1.0\"\n"
	if err := os.WriteFile(pyproject, []byte(originalPyproject), 0o644); err != nil {
		t.Fatal(err)
	}

	var out bytes.Buffer
	proxyRegistry := "http://127.0.0.1:4873/"
	if err := EnableProject(&out, EnableOptions{
		ProjectDir:  project,
		RegistryURL: proxyRegistry,
		Global:      false,
	}); err != nil {
		t.Fatalf("EnableProject failed: %v\n%s", err, out.String())
	}

	uvConfig := readFile(t, filepath.Join(project, "uv.toml"))
	if !strings.Contains(uvConfig, `index-url = "http://127.0.0.1:4873/simple/"`) {
		t.Fatalf("uv.toml was not pointed at proxy:\n%s", uvConfig)
	}
	enabledPyproject := readFile(t, pyproject)
	for _, want := range []string{
		"[[tool.poetry.source]]",
		"[[tool.pdm.source]]",
		`url = "http://127.0.0.1:4873/simple/"`,
	} {
		if !strings.Contains(enabledPyproject, want) {
			t.Fatalf("pyproject.toml missing %q:\n%s", want, enabledPyproject)
		}
	}

	out.Reset()
	if err := DisableProject(&out, DisableOptions{
		ProjectDir: project,
		Global:     false,
	}); err != nil {
		t.Fatalf("DisableProject failed: %v\n%s", err, out.String())
	}

	if restored := readFile(t, pyproject); restored != originalPyproject {
		t.Fatalf("pyproject.toml was not restored\nwant:\n%s\ngot:\n%s", originalPyproject, restored)
	}
	if _, err := os.Stat(filepath.Join(project, "uv.toml")); !os.IsNotExist(err) {
		t.Fatalf("uv.toml should be removed after disable when created by Computer Police: %v", err)
	}
}

func TestEnableDisableGlobalRestoresPythonUserConfigs(t *testing.T) {
	home := t.TempDir()
	configHome := filepath.Join(home, ".config")
	fakeBin := t.TempDir()
	t.Setenv("PATH", fakeBin)
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", configHome)
	writeFakeExecutable(t, fakeBin, "pip")
	writeFakeExecutable(t, fakeBin, "pipx")
	writeFakeExecutable(t, fakeBin, "uv")

	pipConf := filepath.Join(configHome, "pip", "pip.conf")
	if err := os.MkdirAll(filepath.Dir(pipConf), 0o755); err != nil {
		t.Fatal(err)
	}
	originalPipConf := "[global]\nindex-url = https://pypi.example.test/simple/\n"
	if err := os.WriteFile(pipConf, []byte(originalPipConf), 0o644); err != nil {
		t.Fatal(err)
	}

	var out bytes.Buffer
	proxyRegistry := "http://127.0.0.1:4873/"
	if err := EnableProject(&out, EnableOptions{
		ProjectDir:  t.TempDir(),
		RegistryURL: proxyRegistry,
		Global:      true,
	}); err != nil {
		t.Fatalf("EnableProject failed: %v\n%s", err, out.String())
	}
	if !strings.Contains(out.String(), "configured pipx registry=") {
		t.Fatalf("pipx manager was not detected:\n%s", out.String())
	}

	enabledPipConf := readFile(t, pipConf)
	for _, want := range []string{
		"index-url = http://127.0.0.1:4873/simple/",
		"extra-index-url = http://127.0.0.1:4873/simple/",
		"trusted-host = 127.0.0.1",
	} {
		if !strings.Contains(enabledPipConf, want) {
			t.Fatalf("pip.conf missing %q:\n%s", want, enabledPipConf)
		}
	}
	uvConfig := readFile(t, filepath.Join(configHome, "uv", "uv.toml"))
	if !strings.Contains(uvConfig, `index-url = "http://127.0.0.1:4873/simple/"`) {
		t.Fatalf("global uv.toml was not pointed at proxy:\n%s", uvConfig)
	}

	out.Reset()
	if err := DisableProject(&out, DisableOptions{
		ProjectDir: t.TempDir(),
		Global:     true,
	}); err != nil {
		t.Fatalf("DisableProject failed: %v\n%s", err, out.String())
	}

	if restored := readFile(t, pipConf); restored != originalPipConf {
		t.Fatalf("pip.conf was not restored\nwant:\n%s\ngot:\n%s", originalPipConf, restored)
	}
	if _, err := os.Stat(filepath.Join(configHome, "uv", "uv.toml")); !os.IsNotExist(err) {
		t.Fatalf("global uv.toml should be removed after disable when created by Computer Police: %v", err)
	}
}

func TestDoctorReportsPythonRegistryConfigs(t *testing.T) {
	home := t.TempDir()
	configHome := filepath.Join(home, ".config")
	project := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", configHome)
	t.Chdir(project)

	registry := "http://127.0.0.1:4873/simple/"
	pipConf := filepath.Join(configHome, "pip", "pip.conf")
	uvConfig := filepath.Join(configHome, "uv", "uv.toml")
	for path, content := range map[string]string{
		pipConf:                                  "[global]\nindex-url = " + registry + "\n",
		uvConfig:                                 "index-url = \"" + registry + "\"\n",
		filepath.Join(project, "uv.toml"):        "index-url = \"" + registry + "\"\n",
		filepath.Join(project, "pyproject.toml"): "[[tool.poetry.source]]\nname = \"computer-police\"\nurl = \"" + registry + "\"\n",
	} {
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	var out bytes.Buffer
	if err := Doctor(&out); err != nil {
		t.Fatalf("Doctor failed: %v", err)
	}
	output := out.String()
	for _, want := range []string{
		"✓ pip.conf configured for proxy",
		"✓ uv.toml configured for proxy",
		"✓ global uv registry configured for proxy",
		"✓ pyproject.toml Python sources configured for proxy",
	} {
		if !strings.Contains(output, want) {
			t.Fatalf("doctor output missing %q:\n%s", want, output)
		}
	}
}

func writeFakeExecutable(t *testing.T, dir, name string) {
	t.Helper()
	if runtime.GOOS == "windows" {
		name += ".exe"
	}
	path := filepath.Join(dir, name)
	if err := os.WriteFile(path, []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}
