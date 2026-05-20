package collector

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestCaptureStateAndBuildEventDetectDirectAndResolvedAdds(t *testing.T) {
	dir := t.TempDir()
	mustWrite(t, filepath.Join(dir, "package.json"), `{"dependencies":{}}`)
	mustWrite(t, filepath.Join(dir, "package-lock.json"), `{"lockfileVersion":3,"packages":{"":{"dependencies":{}}}}`)
	before := CaptureState(dir, "npm")

	mustWrite(t, filepath.Join(dir, "package.json"), `{"dependencies":{"zod":"^3.25.1"}}`)
	mustWrite(t, filepath.Join(dir, "package-lock.json"), `{
  "lockfileVersion": 3,
  "packages": {
    "": {"dependencies": {"zod": "^3.25.1"}},
    "node_modules/zod": {
      "version": "3.25.1",
      "resolved": "https://registry.npmjs.org/zod/-/zod-3.25.1.tgz",
      "integrity": "sha512-test"
    }
  }
}`)
	after := CaptureState(dir, "npm")

	event := BuildEvent(Capture{
		TimestampStart: time.Date(2026, 5, 1, 12, 0, 0, 0, time.UTC),
		TimestampEnd:   time.Date(2026, 5, 1, 12, 0, 1, 0, time.UTC),
		CWD:            dir,
		PackageManager: "npm",
		Argv:           []string{"install", "zod"},
		ExitCode:       0,
		Before:         before,
	}, after, "test")

	if len(event.Changes.DirectAdded) != 1 || event.Changes.DirectAdded[0].Name != "zod" {
		t.Fatalf("direct add not recorded: %#v", event.Changes.DirectAdded)
	}
	if event.Changes.DirectAdded[0].Specifier != "^3.25.1" {
		t.Fatalf("specifier not recorded: %#v", event.Changes.DirectAdded[0])
	}
	if event.Changes.DirectAdded[0].Version != "3.25.1" {
		t.Fatalf("direct version not enriched: %#v", event.Changes.DirectAdded[0])
	}
	if len(event.Changes.ResolvedAdded) != 1 || event.Changes.ResolvedAdded[0].Version != "3.25.1" {
		t.Fatalf("resolved add not recorded: %#v", event.Changes.ResolvedAdded)
	}
	if event.Collection.SourceUpload || event.Collection.EnvUpload || event.Collection.TerminalUpload {
		t.Fatalf("privacy upload flags must be false: %#v", event.Collection)
	}
	if event.Changes.DirectRemoved == nil || event.Changes.ResolvedUpdated == nil {
		t.Fatalf("empty change slices should be JSON arrays, not null: %#v", event.Changes)
	}
}

func TestYarnLockParserHandlesScopedNames(t *testing.T) {
	path := filepath.Join(t.TempDir(), "yarn.lock")
	mustWrite(t, path, `"@scope/pkg@^1.0.0":
  version "1.2.3"
  resolved "https://registry.yarnpkg.com/@scope/pkg/-/pkg-1.2.3.tgz"
  integrity sha512-test
`)
	got := readYarnLock(path)
	pkg, ok := got["@scope/pkg@1.2.3"]
	if !ok {
		t.Fatalf("missing scoped package parse: %#v", got)
	}
	if pkg.Name != "@scope/pkg" || pkg.Version != "1.2.3" {
		t.Fatalf("bad parsed package: %#v", pkg)
	}
}

func TestBuildEventForBunLockBStillRecordsDirectPackage(t *testing.T) {
	dir := t.TempDir()
	mustWrite(t, filepath.Join(dir, "package.json"), `{"dependencies":{}}`)
	mustWrite(t, filepath.Join(dir, "bun.lockb"), "binary-ish")
	before := CaptureState(dir, "bun")

	mustWrite(t, filepath.Join(dir, "package.json"), `{"dependencies":{"xxx":"^0.0.1"}}`)
	after := CaptureState(dir, "bun")
	event := BuildEvent(Capture{
		TimestampStart: time.Date(2026, 5, 1, 12, 0, 0, 0, time.UTC),
		TimestampEnd:   time.Date(2026, 5, 1, 12, 0, 1, 0, time.UTC),
		CWD:            dir,
		PackageManager: "bun",
		Argv:           []string{"add", "xxx"},
		ExitCode:       0,
		Before:         before,
	}, after, "test")

	if len(event.Changes.DirectAdded) != 1 {
		t.Fatalf("direct bun package not recorded: %#v", event.Changes.DirectAdded)
	}
	if event.Changes.DirectAdded[0].Name != "xxx" || event.Changes.DirectAdded[0].Version != "0.0.1" {
		t.Fatalf("bad bun direct package: %#v", event.Changes.DirectAdded[0])
	}
	if event.State.ResolvedDiffSupport != "unsupported-binary-lockfile" {
		t.Fatalf("missing bun.lockb support marker: %#v", event.State)
	}
}

func TestVersionFromSpecifier(t *testing.T) {
	tests := map[string]string{
		"^7.0.0":      "7.0.0",
		"~1.2.3":      "1.2.3",
		">=2.0.0":     "2.0.0",
		"workspace:*": "",
		"*":           "",
	}
	for spec, want := range tests {
		if got := versionFromSpecifier(spec); got != want {
			t.Fatalf("versionFromSpecifier(%q) = %q, want %q", spec, got, want)
		}
	}
}

func mustWrite(t *testing.T, path, body string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}
