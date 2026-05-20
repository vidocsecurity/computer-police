package agentdist

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestInstallRepoArtifactsIsIdempotent(t *testing.T) {
	dir := t.TempDir()
	changed, err := Install(dir, Options{})
	if err != nil {
		t.Fatal(err)
	}
	if len(changed) != 3 {
		t.Fatalf("changed %d files, want 3: %v", len(changed), changed)
	}
	changed, err = Install(dir, Options{})
	if err != nil {
		t.Fatal(err)
	}
	if len(changed) != 0 {
		t.Fatalf("second install changed files: %v", changed)
	}
	agents, err := os.ReadFile(filepath.Join(dir, "AGENTS.md"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Count(string(agents), SectionMarker) != 1 {
		t.Fatalf("AGENTS section duplicated:\n%s", agents)
	}
	if _, err := os.Stat(filepath.Join(dir, ".cursor", "rules", "package-police-agent-guard.mdc")); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, ".agents", "skills", "package-police-agent-guard", "SKILL.md")); err != nil {
		t.Fatal(err)
	}
}
