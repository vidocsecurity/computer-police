package ledger

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"

	"github.com/vidoc/package-police/internal/collector"
	"github.com/vidoc/package-police/internal/paths"
)

type ListOptions struct {
	Limit   int
	Repo    string
	Package string
}

type eventRecord struct {
	SchemaVersion  string               `json:"schema_version"`
	EventType      string               `json:"event_type"`
	EventID        string               `json:"event_id"`
	Timestamp      string               `json:"timestamp"`
	TimestampStart string               `json:"timestamp_start"`
	Source         string               `json:"source"`
	Confidence     string               `json:"confidence"`
	Project        recordProject        `json:"project"`
	PackageManager recordPackageManager `json:"package_manager"`
	Changes        collector.Changes    `json:"changes"`
}

type recordProject struct {
	RepoRoot      string `json:"repo_root"`
	CWD           string `json:"cwd"`
	RepoRootLocal string `json:"repo_root_local"`
	ProjectID     string `json:"project_id"`
}

type recordPackageManager struct {
	Name       string `json:"name"`
	Command    string `json:"command"`
	ExitCode   int    `json:"exit_code"`
	Inferred   string `json:"inferred"`
	Confidence string `json:"confidence"`
}

func List(out io.Writer, opts ListOptions) error {
	loadLimit := opts.Limit
	if opts.Package != "" || opts.Repo == "current" {
		loadLimit = 0
	}
	events, err := load(loadLimit)
	if err != nil {
		return err
	}
	repoRoot := ""
	if opts.Repo == "current" {
		repoRoot = currentRepoRoot()
	}
	count := 0
	for i := len(events) - 1; i >= 0; i-- {
		if opts.Package != "" && !eventHasPackage(events[i], opts.Package) {
			continue
		}
		if repoRoot != "" && eventRepo(events[i]) != repoRoot {
			continue
		}
		printEvent(out, events[i])
		count++
		if opts.Limit > 0 && count >= opts.Limit {
			break
		}
	}
	return nil
}

func Search(out io.Writer, pkg string, opts ListOptions) error {
	events, err := load(0)
	if err != nil {
		return err
	}
	count := 0
	for i := len(events) - 1; i >= 0; i-- {
		if eventHasPackage(events[i], pkg) {
			printEvent(out, events[i])
			count++
			if opts.Limit > 0 && count >= opts.Limit {
				break
			}
		}
	}
	if count == 0 {
		fmt.Fprintf(out, "No local ledger events found for %s\n", pkg)
	}
	return nil
}

func load(limit int) ([]eventRecord, error) {
	f, err := os.Open(paths.LedgerPath())
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	defer f.Close()
	var events []eventRecord
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 0, 64*1024), 10*1024*1024)
	for scanner.Scan() {
		var event eventRecord
		if err := json.Unmarshal(scanner.Bytes(), &event); err == nil {
			events = append(events, event)
		}
		if limit > 0 && len(events) > limit {
			events = events[1:]
		}
	}
	return events, scanner.Err()
}

func printEvent(out io.Writer, event eventRecord) {
	timestamp := event.Timestamp
	if timestamp == "" {
		timestamp = event.TimestampStart
	}
	eventType := event.EventType
	if eventType == "" {
		eventType = "package_manager_command"
	}
	pm := event.PackageManager.Inferred
	if pm == "" {
		pm = event.PackageManager.Name
	}
	if event.PackageManager.Command != "" {
		fmt.Fprintf(out, "%s %s %s exit=%d repo=%s\n", timestamp, eventType, event.PackageManager.Command, event.PackageManager.ExitCode, eventRepo(event))
	} else {
		fmt.Fprintf(out, "%s %s source=%s pm=%s repo=%s\n", timestamp, eventType, event.Source, pm, eventRepo(event))
	}
	for _, pkg := range append(append(event.Changes.DirectAdded, event.Changes.DirectUpdated...), event.Changes.DirectRemoved...) {
		fmt.Fprintf(out, "  direct %s %s %s %s %s\n", pkg.Name, pkg.Version, pkg.Specifier, pkg.DependencyType, pkg.ManifestPath)
	}
	for _, pkg := range append(append(event.Changes.ResolvedAdded, event.Changes.ResolvedUpdated...), event.Changes.ResolvedRemoved...) {
		fmt.Fprintf(out, "  resolved %s %s %s\n", pkg.Name, pkg.Version, pkg.LockfilePath)
	}
}

func eventHasPackage(event eventRecord, name string) bool {
	groups := [][]collector.Package{
		event.Changes.DirectAdded, event.Changes.DirectRemoved, event.Changes.DirectUpdated,
		event.Changes.ResolvedAdded, event.Changes.ResolvedRemoved, event.Changes.ResolvedUpdated,
	}
	for _, group := range groups {
		for _, pkg := range group {
			if strings.EqualFold(pkg.Name, name) {
				return true
			}
		}
	}
	return false
}

func eventRepo(event eventRecord) string {
	if event.Project.RepoRootLocal != "" {
		return event.Project.RepoRootLocal
	}
	if event.Project.RepoRoot != "" {
		return event.Project.RepoRoot
	}
	return event.Project.CWD
}

func currentRepoRoot() string {
	out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	if err == nil {
		return strings.TrimSpace(string(out))
	}
	cwd, _ := os.Getwd()
	return cwd
}
