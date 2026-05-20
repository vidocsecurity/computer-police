package observer

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSnapshotCollectRecordsDependencyChange(t *testing.T) {
	home := t.TempDir()
	t.Setenv("PACKAGE_POLICE_HOME", filepath.Join(home, ".package-police"))
	t.Setenv("PACKAGE_POLICE_NO_WATCH", "1")
	project := t.TempDir()
	chdir(t, project)
	write(t, "package.json", `{"name":"app","version":"1.0.0","dependencies":{}}`)
	write(t, "package-lock.json", `{"lockfileVersion":3,"packages":{"":{}}}`)

	if err := ObserveHere(discard{}); err != nil {
		t.Fatal(err)
	}
	write(t, "package.json", `{"name":"app","version":"1.0.0","dependencies":{"zod":"^3.25.1"}}`)
	write(t, "package-lock.json", `{"lockfileVersion":3,"packages":{"":{"dependencies":{"zod":"^3.25.1"}},"node_modules/zod":{"version":"3.25.1","resolved":"https://registry.npmjs.org/zod/-/zod-3.25.1.tgz","integrity":"sha512-test"}}}`)

	if err := SnapshotCollect(discard{}); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(home, ".package-police", "install-ledger", "events.ndjson"))
	if err != nil {
		t.Fatal(err)
	}
	if !contains(string(data), `"event_type":"dependency_state_changed"`) || !contains(string(data), `"name":"zod"`) {
		t.Fatalf("ledger missing dependency event:\n%s", data)
	}
	if !contains(string(data), `"version":"3.25.1"`) {
		t.Fatalf("ledger missing direct/resolved version:\n%s", data)
	}
}

func TestDiscoverIgnoresNodeModules(t *testing.T) {
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "node_modules", "dep"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(root, "app"), 0o755); err != nil {
		t.Fatal(err)
	}
	writePath(t, filepath.Join(root, "node_modules", "dep", "package.json"), `{}`)
	writePath(t, filepath.Join(root, "app", "package.json"), `{}`)
	projects, err := Discover(root, true, 8)
	if err != nil {
		t.Fatal(err)
	}
	if len(projects) != 1 || projects[0] != filepath.Join(root, "app") {
		t.Fatalf("projects = %#v", projects)
	}
}

func TestReconcileDiscoversNewProjectUnderObservedRoot(t *testing.T) {
	home := t.TempDir()
	t.Setenv("PACKAGE_POLICE_HOME", filepath.Join(home, ".package-police"))
	t.Setenv("PACKAGE_POLICE_NO_WATCH", "1")
	root := t.TempDir()
	if err := Add(discard{}, root, true, 8); err != nil {
		t.Fatal(err)
	}
	app := filepath.Join(root, "new-app")
	if err := os.MkdirAll(app, 0o755); err != nil {
		t.Fatal(err)
	}
	writePath(t, filepath.Join(app, "package.json"), `{"name":"new-app"}`)
	if err := Reconcile(discard{}, "periodic_scan"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(home, ".package-police", "install-ledger", "events.ndjson"))
	if err != nil {
		t.Fatal(err)
	}
	if !contains(string(data), `"event_type":"project_discovered"`) || !contains(string(data), `new-app`) {
		t.Fatalf("ledger missing discovery event:\n%s", data)
	}
}

type discard struct{}

func (discard) Write(p []byte) (int, error) { return len(p), nil }

func chdir(t *testing.T, dir string) {
	t.Helper()
	old, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chdir(old) })
}

func write(t *testing.T, name, body string) {
	t.Helper()
	writePath(t, name, body)
}

func writePath(t *testing.T, path, body string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func contains(s, substr string) bool {
	return len(substr) == 0 || (len(s) >= len(substr) && index(s, substr) >= 0)
}

func index(s, substr string) int {
	for i := 0; i+len(substr) <= len(s); i++ {
		if s[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}
