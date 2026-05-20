package doctor

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/vidoc/package-police/internal/observer"
	"github.com/vidoc/package-police/internal/paths"
)

type Report struct {
	Mode                string    `json:"mode"`
	PassiveWatcher      string    `json:"passive_watcher"`
	ObservedRoots       int       `json:"observed_roots"`
	CurrentRepoObserved bool      `json:"current_repo_observed"`
	CurrentProjectID    string    `json:"current_project_id,omitempty"`
	CurrentRepo         string    `json:"current_repo,omitempty"`
	LastSnapshot        time.Time `json:"last_snapshot,omitempty"`
	LedgerWritable      bool      `json:"ledger_writable"`
	AgentsMD            bool      `json:"agents_md"`
	CursorRule          bool      `json:"cursor_rule"`
	AgentSkill          bool      `json:"agent_skill"`
	Privacy             Privacy   `json:"privacy"`
}

type Privacy struct {
	Mode                    string `json:"mode"`
	SourceCodeCollected     bool   `json:"source_code_collected"`
	EnvCollected            bool   `json:"env_collected"`
	TerminalOutputCollected bool   `json:"terminal_output_collected"`
}

func Run(out io.Writer, jsonOut bool) error {
	report := buildReport()
	if jsonOut {
		enc := json.NewEncoder(out)
		enc.SetIndent("", "  ")
		return enc.Encode(report)
	}
	fmt.Fprintln(out, "Package Police Passive Dependency Observer")
	fmt.Fprintln(out)
	fmt.Fprintln(out, "Observer:")
	fmt.Fprintf(out, "✓ mode: %s\n", report.Mode)
	fmt.Fprintf(out, "• passive watcher: %s\n", report.PassiveWatcher)
	fmt.Fprintf(out, "• observed roots: %d\n", report.ObservedRoots)
	printBool(out, "current repo observed", report.CurrentRepoObserved)
	if report.CurrentRepo != "" {
		fmt.Fprintf(out, "• current repo: %s\n", report.CurrentRepo)
	}
	if !report.LastSnapshot.IsZero() {
		fmt.Fprintf(out, "• last snapshot: %s\n", report.LastSnapshot.Format(time.RFC3339))
	}
	fmt.Fprintln(out)
	if report.LedgerWritable {
		fmt.Fprintf(out, "Ledger:\n✓ writable: %s\n", paths.LedgerPath())
	} else {
		fmt.Fprintf(out, "Ledger:\n✗ not writable: %s\n", paths.LedgerPath())
	}
	fmt.Fprintln(out)
	fmt.Fprintln(out, "Privacy:")
	fmt.Fprintln(out, "✓ local-only")
	fmt.Fprintln(out, "✓ source code collected: false")
	fmt.Fprintln(out, "✓ environment collected: false")
	fmt.Fprintln(out, "✓ terminal output collected: false")
	fmt.Fprintln(out)
	fmt.Fprintln(out, "Agent distribution:")
	printBool(out, "AGENTS.md contains passive observer instructions", report.AgentsMD)
	printBool(out, "Cursor passive observer rule installed", report.CursorRule)
	printBool(out, "Agent Skill installed", report.AgentSkill)
	return nil
}

func buildReport() Report {
	observed, projectID, repo := observer.ReportCurrentRepoObserved()
	report := Report{
		Mode:                "agent-assisted",
		PassiveWatcher:      watcherStatus(),
		ObservedRoots:       observer.ObservedRootCount(),
		CurrentRepoObserved: observed,
		CurrentProjectID:    projectID,
		CurrentRepo:         repo,
		LastSnapshot:        observer.LastSnapshotTime(repo),
		LedgerWritable:      ledgerWritable(),
		AgentsMD:            fileContains("AGENTS.md", "Package Police Passive Dependency Observer"),
		CursorRule:          exists(filepath.Join(".cursor", "rules", "package-police-passive-dependency-observer.mdc")),
		AgentSkill:          exists(filepath.Join(".agents", "skills", "package-police-passive-dependency-observer", "SKILL.md")),
		Privacy: Privacy{
			Mode:                    "local-only",
			SourceCodeCollected:     false,
			EnvCollected:            false,
			TerminalOutputCollected: false,
		},
	}
	return report
}

func watcherStatus() string {
	if observer.WatcherActive() {
		return "active"
	}
	return "inactive"
}

func ledgerWritable() bool {
	if err := os.MkdirAll(filepath.Dir(paths.LedgerPath()), 0o755); err != nil {
		return false
	}
	f, err := os.OpenFile(paths.LedgerPath(), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return false
	}
	return f.Close() == nil
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func fileContains(path, needle string) bool {
	data, err := os.ReadFile(path)
	return err == nil && strings.Contains(string(data), needle)
}

func printBool(out io.Writer, label string, ok bool) {
	if ok {
		fmt.Fprintf(out, "✓ %s\n", label)
	} else {
		fmt.Fprintf(out, "✗ %s\n", label)
	}
}
