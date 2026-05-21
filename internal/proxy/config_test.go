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
