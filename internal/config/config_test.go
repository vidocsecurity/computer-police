package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestFindRealBinarySkipsVidocShims(t *testing.T) {
	home := t.TempDir()
	t.Setenv("VIDOC_HOME", home)
	realDir := filepath.Join(t.TempDir(), "bin")
	shimDir := filepath.Join(home, "shims")
	if err := os.MkdirAll(realDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(shimDir, 0o755); err != nil {
		t.Fatal(err)
	}
	mustExecutable(t, filepath.Join(shimDir, "npm"))
	mustExecutable(t, filepath.Join(realDir, "npm"))
	t.Setenv("PATH", shimDir+string(os.PathListSeparator)+realDir)

	if got := FindRealBinary("npm"); got != filepath.Join(realDir, "npm") {
		t.Fatalf("FindRealBinary = %q, want real binary", got)
	}
}

func mustExecutable(t *testing.T, path string) {
	t.Helper()
	if err := os.WriteFile(path, []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
}
