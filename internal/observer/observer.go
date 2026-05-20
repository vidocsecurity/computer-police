package observer

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"time"

	"github.com/vidoc/package-police/internal/agentdist"
	"github.com/vidoc/package-police/internal/collector"
	"github.com/vidoc/package-police/internal/paths"
)

var DependencyFiles = map[string]string{
	"package-lock.json":   "npm",
	"npm-shrinkwrap.json": "npm",
	"pnpm-lock.yaml":      "pnpm",
	"yarn.lock":           "yarn",
	"bun.lock":            "bun",
	"bun.lockb":           "bun",
}

var IgnoredDirs = map[string]bool{
	"node_modules": true, ".git": true, ".next": true, "dist": true, "build": true,
	"coverage": true, ".cache": true, ".turbo": true, ".nx": true, "vendor": true,
	"tmp": true, "temp": true,
}

type State struct {
	SchemaVersion string         `json:"schema_version"`
	ObservedRoots []ObservedRoot `json:"observed_roots"`
	Projects      []ProjectRef   `json:"projects"`
}

type ObservedRoot struct {
	Path      string    `json:"path"`
	Recursive bool      `json:"recursive"`
	MaxDepth  int       `json:"max_depth"`
	AddedAt   time.Time `json:"added_at"`
	Active    bool      `json:"active"`
}

type ProjectRef struct {
	ProjectID string    `json:"project_id"`
	RepoRoot  string    `json:"repo_root"`
	AddedAt   time.Time `json:"added_at"`
	Active    bool      `json:"active"`
}

type Snapshot struct {
	SchemaVersion     string                  `json:"schema_version"`
	ProjectID         string                  `json:"project_id"`
	RepoRoot          string                  `json:"repo_root"`
	CreatedAt         time.Time               `json:"created_at"`
	UpdatedAt         time.Time               `json:"updated_at"`
	Files             map[string]FileSnapshot `json:"files"`
	DependencyGraph   DependencyGraph         `json:"dependency_graph"`
	PackageManager    PackageManagerInference `json:"package_manager"`
	ResolvedSupported bool                    `json:"resolved_supported"`
}

type FileSnapshot struct {
	Exists bool      `json:"exists"`
	Hash   string    `json:"hash,omitempty"`
	MTime  time.Time `json:"mtime,omitempty"`
}

type DependencyGraph struct {
	Direct   map[string]collector.Package `json:"direct"`
	Resolved map[string]collector.Package `json:"resolved"`
}

type PackageManagerInference struct {
	Inferred   string   `json:"inferred"`
	Candidates []string `json:"candidates,omitempty"`
	Confidence string   `json:"confidence"`
}

type DependencyEvent struct {
	SchemaVersion       string                  `json:"schema_version"`
	EventType           string                  `json:"event_type"`
	EventID             string                  `json:"event_id"`
	Timestamp           string                  `json:"timestamp"`
	Source              string                  `json:"source"`
	Confidence          string                  `json:"confidence"`
	Project             EventProject            `json:"project"`
	ChangedFiles        []string                `json:"changed_files"`
	PackageManager      PackageManagerInference `json:"package_manager"`
	ResolvedDiffSupport string                  `json:"resolved_diff_support,omitempty"`
	Changes             collector.Changes       `json:"changes"`
	Collection          PassiveCollection       `json:"collection"`
}

type EventProject struct {
	ProjectID     string `json:"project_id"`
	RepoRootHash  string `json:"repo_root_hash"`
	RepoRootLocal string `json:"repo_root_local"`
	GitRemoteHash string `json:"git_remote_hash,omitempty"`
	GitRemoteHost string `json:"git_remote_host,omitempty"`
	Branch        string `json:"branch,omitempty"`
	Commit        string `json:"commit,omitempty"`
	Dirty         bool   `json:"dirty"`
}

type PassiveCollection struct {
	Mode                    string `json:"mode"`
	SourceCodeCollected     bool   `json:"source_code_collected"`
	EnvCollected            bool   `json:"env_collected"`
	TerminalOutputCollected bool   `json:"terminal_output_collected"`
}

type DiscoveredEvent struct {
	SchemaVersion   string       `json:"schema_version"`
	EventType       string       `json:"event_type"`
	EventID         string       `json:"event_id"`
	Timestamp       string       `json:"timestamp"`
	Source          string       `json:"source"`
	Project         EventProject `json:"project"`
	DiscoveredFiles []string     `json:"discovered_files"`
}

func ObserveHere(out io.Writer) error {
	cwd, _ := os.Getwd()
	root := repoRoot(cwd)
	if root == "" {
		root = projectRoot(cwd)
	}
	if err := registerProject(out, root, "observe_here", false); err != nil {
		return err
	}
	return StartWatcher(out)
}

func InitRepo(out io.Writer) error {
	if err := ObserveHere(out); err != nil {
		return err
	}
	changed, err := agentdist.InstallPassive(".", agentdist.Options{})
	if err != nil {
		return err
	}
	for _, path := range changed {
		fmt.Fprintf(out, "Updated agent distribution file: %s\n", path)
	}
	return nil
}

func Add(out io.Writer, path string, recursive bool, maxDepth int) error {
	abs, err := filepath.Abs(expandHome(path))
	if err != nil {
		return err
	}
	if maxDepth <= 0 {
		maxDepth = 8
	}
	st := loadState()
	now := time.Now().UTC()
	found := false
	for i := range st.ObservedRoots {
		if samePath(st.ObservedRoots[i].Path, abs) {
			st.ObservedRoots[i].Recursive = recursive
			st.ObservedRoots[i].MaxDepth = maxDepth
			st.ObservedRoots[i].Active = true
			found = true
		}
	}
	if !found {
		st.ObservedRoots = append(st.ObservedRoots, ObservedRoot{Path: abs, Recursive: recursive, MaxDepth: maxDepth, AddedAt: now, Active: true})
	}
	projects, err := Discover(abs, recursive, maxDepth)
	if err != nil {
		return err
	}
	for _, project := range projects {
		if err := registerProjectRef(&st, project, now); err != nil {
			return err
		}
	}
	if err := saveState(st); err != nil {
		return err
	}
	for _, project := range projects {
		if err := createSnapshot(project); err != nil {
			return err
		}
		_ = appendLedger(discoveredEvent(project, "observe_add_scan"))
		fmt.Fprintf(out, "Observed project: %s\n", project)
	}
	fmt.Fprintf(out, "Observed root: %s\n", abs)
	return StartWatcher(out)
}

func List(out io.Writer) error {
	st := loadState()
	fmt.Fprintln(out, "Observed roots:")
	for _, root := range st.ObservedRoots {
		fmt.Fprintf(out, "- %s recursive=%v max_depth=%d active=%v\n", root.Path, root.Recursive, root.MaxDepth, root.Active)
	}
	fmt.Fprintln(out, "Projects:")
	for _, project := range st.Projects {
		fmt.Fprintf(out, "- %s %s active=%v\n", project.ProjectID, project.RepoRoot, project.Active)
	}
	return nil
}

func Remove(out io.Writer, target string) error {
	abs, _ := filepath.Abs(expandHome(target))
	st := loadState()
	var roots []ObservedRoot
	for _, root := range st.ObservedRoots {
		if samePath(root.Path, abs) || root.Path == target {
			continue
		}
		roots = append(roots, root)
	}
	var projects []ProjectRef
	for _, project := range st.Projects {
		if samePath(project.RepoRoot, abs) || project.ProjectID == target {
			continue
		}
		projects = append(projects, project)
	}
	st.ObservedRoots = roots
	st.Projects = projects
	if err := saveState(st); err != nil {
		return err
	}
	fmt.Fprintf(out, "Removed observation target: %s\n", target)
	return nil
}

func SnapshotCreate(out io.Writer) error {
	root := currentRegisteredRoot()
	if err := createSnapshot(root); err != nil {
		return err
	}
	fmt.Fprintf(out, "Snapshot created: %s\n", root)
	return nil
}

func SnapshotCollect(out io.Writer) error {
	root := currentRegisteredRoot()
	event, changed, err := collectProject(root, "agent_assisted_collect", "high")
	if err != nil {
		return err
	}
	if !changed {
		fmt.Fprintf(out, "No dependency state changes: %s\n", root)
		return nil
	}
	if err := appendLedger(event); err != nil {
		return err
	}
	if err := createSnapshot(root); err != nil {
		return err
	}
	fmt.Fprintf(out, "Recorded dependency state change: %s\n", root)
	return nil
}

func Reconcile(out io.Writer, source string) error {
	st := loadState()
	now := time.Now().UTC()
	known := map[string]bool{}
	for _, project := range st.Projects {
		known[project.RepoRoot] = true
	}
	for _, root := range st.ObservedRoots {
		if !root.Active {
			continue
		}
		projects, err := Discover(root.Path, root.Recursive, root.MaxDepth)
		if err != nil {
			return err
		}
		for _, project := range projects {
			if known[project] {
				continue
			}
			if err := registerProjectRef(&st, project, now); err != nil {
				return err
			}
			if err := createSnapshot(project); err != nil {
				return err
			}
			if err := appendLedger(discoveredEvent(project, source)); err != nil {
				return err
			}
			known[project] = true
			fmt.Fprintf(out, "Discovered project: %s\n", project)
		}
	}
	if err := saveState(st); err != nil {
		return err
	}
	for _, project := range st.Projects {
		if !project.Active {
			continue
		}
		event, changed, err := collectProject(project.RepoRoot, source, "medium")
		if err != nil {
			return err
		}
		if changed {
			if err := appendLedger(event); err != nil {
				return err
			}
			if err := createSnapshot(project.RepoRoot); err != nil {
				return err
			}
			fmt.Fprintf(out, "Recorded dependency state change: %s\n", project.RepoRoot)
		}
	}
	return nil
}

func StartWatcher(out io.Writer) error {
	if os.Getenv("PACKAGE_POLICE_NO_WATCH") == "1" || os.Getenv("VIDOC_NO_WATCH") == "1" {
		fmt.Fprintln(out, "Passive watcher not started: PACKAGE_POLICE_NO_WATCH=1")
		return nil
	}
	if WatcherActive() {
		fmt.Fprintln(out, "Passive watcher already active.")
		return nil
	}
	if err := os.MkdirAll(paths.ObserverDir(), 0o755); err != nil {
		return err
	}
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	cmd := exec.Command(exe, "__watch")
	cmd.Stdin = nil
	cmd.Stdout = nil
	cmd.Stderr = nil
	cmd.Env = os.Environ()
	if err := cmd.Start(); err != nil {
		return err
	}
	pid := cmd.Process.Pid
	if err := os.WriteFile(paths.ObserverPIDPath(), []byte(fmt.Sprintf("%d\n", pid)), 0o644); err != nil {
		_ = cmd.Process.Kill()
		return err
	}
	if err := cmd.Process.Release(); err != nil {
		return err
	}
	fmt.Fprintf(out, "Passive watcher started: pid %d\n", pid)
	return nil
}

func RunWatcher() error {
	if err := os.MkdirAll(paths.ObserverDir(), 0o755); err != nil {
		return err
	}
	_ = os.WriteFile(paths.ObserverPIDPath(), []byte(fmt.Sprintf("%d\n", os.Getpid())), 0o644)
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()
	for {
		_ = Reconcile(io.Discard, "file_watcher")
		<-ticker.C
	}
}

func WatcherActive() bool {
	data, err := os.ReadFile(paths.ObserverPIDPath())
	if err != nil {
		return false
	}
	var pid int
	if _, err := fmt.Sscanf(strings.TrimSpace(string(data)), "%d", &pid); err != nil || pid <= 0 {
		return false
	}
	return syscall.Kill(pid, 0) == nil
}

func ReportCurrentRepoObserved() (bool, string, string) {
	cwd, _ := os.Getwd()
	root := repoRoot(cwd)
	if root == "" {
		root = projectRoot(cwd)
	}
	st := loadState()
	for _, project := range st.Projects {
		if samePath(project.RepoRoot, root) {
			return true, project.ProjectID, root
		}
	}
	return false, "", root
}

func ObservedRootCount() int {
	return len(loadState().ObservedRoots)
}

func LastSnapshotTime(root string) time.Time {
	snap, err := loadSnapshot(projectID(root))
	if err != nil {
		return time.Time{}
	}
	return snap.UpdatedAt
}

func Discover(root string, recursive bool, maxDepth int) ([]string, error) {
	seen := map[string]bool{}
	var projects []string
	if maxDepth <= 0 {
		maxDepth = 8
	}
	err := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			name := d.Name()
			if IgnoredDirs[name] {
				return filepath.SkipDir
			}
			if !recursive && path != root {
				return filepath.SkipDir
			}
			if depth(root, path) > maxDepth {
				return filepath.SkipDir
			}
			return nil
		}
		if !isDependencyFile(d.Name()) {
			return nil
		}
		project := projectRoot(filepath.Dir(path))
		if !seen[project] {
			seen[project] = true
			projects = append(projects, project)
		}
		return nil
	})
	sort.Strings(projects)
	return projects, err
}

func createSnapshot(root string) error {
	snap, err := buildSnapshot(root)
	if err != nil {
		return err
	}
	old, err := loadSnapshot(snap.ProjectID)
	if err == nil && !old.CreatedAt.IsZero() {
		snap.CreatedAt = old.CreatedAt
	}
	return saveSnapshot(snap)
}

func collectProject(root, source, confidence string) (DependencyEvent, bool, error) {
	before, err := loadSnapshot(projectID(root))
	if err != nil {
		return DependencyEvent{}, false, err
	}
	after, err := buildSnapshot(root)
	if err != nil {
		return DependencyEvent{}, false, err
	}
	changedFiles := changedFiles(before.Files, after.Files)
	changes := collector.Changes{
		DirectAdded:     diffAdded(before.DependencyGraph.Direct, after.DependencyGraph.Direct),
		DirectRemoved:   diffRemoved(before.DependencyGraph.Direct, after.DependencyGraph.Direct),
		DirectUpdated:   diffUpdated(before.DependencyGraph.Direct, after.DependencyGraph.Direct),
		ResolvedAdded:   diffAdded(before.DependencyGraph.Resolved, after.DependencyGraph.Resolved),
		ResolvedRemoved: diffRemoved(before.DependencyGraph.Resolved, after.DependencyGraph.Resolved),
		ResolvedUpdated: diffUpdated(before.DependencyGraph.Resolved, after.DependencyGraph.Resolved),
	}
	enrichDirectVersions(changes.DirectAdded, after.DependencyGraph.Resolved)
	enrichDirectVersions(changes.DirectUpdated, after.DependencyGraph.Resolved)
	normalizeChanges(&changes)
	changed := len(changedFiles) > 0 || hasChanges(changes)
	return DependencyEvent{
		SchemaVersion:       "1.0",
		EventType:           "dependency_state_changed",
		EventID:             "evt_" + randomHex(16),
		Timestamp:           time.Now().UTC().Format(time.RFC3339Nano),
		Source:              source,
		Confidence:          confidence,
		Project:             eventProject(root),
		ChangedFiles:        changedFiles,
		PackageManager:      after.PackageManager,
		ResolvedDiffSupport: resolvedDiffSupport(after),
		Changes:             changes,
		Collection: PassiveCollection{
			Mode:                    "local-only",
			SourceCodeCollected:     false,
			EnvCollected:            false,
			TerminalOutputCollected: false,
		},
	}, changed, nil
}

func resolvedDiffSupport(snapshot Snapshot) string {
	if snapshot.ResolvedSupported {
		return ""
	}
	return "unsupported-binary-lockfile"
}

func buildSnapshot(root string) (Snapshot, error) {
	now := time.Now().UTC()
	files := map[string]FileSnapshot{}
	direct := map[string]collector.Package{}
	resolved := map[string]collector.Package{}
	lockfiles := []string{}
	err := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			if IgnoredDirs[d.Name()] {
				return filepath.SkipDir
			}
			return nil
		}
		if !isDependencyFile(d.Name()) {
			return nil
		}
		rel := relPath(root, path)
		info, statErr := d.Info()
		file := FileSnapshot{Exists: true, Hash: collector.FileHash(path)}
		if statErr == nil {
			file.MTime = info.ModTime().UTC()
		}
		files[rel] = file
		if d.Name() == "package.json" {
			for key, pkg := range collector.ReadPackageJSON(path) {
				pkg.ManifestPath = rel
				direct[rel+":"+key] = pkg
			}
		} else {
			lockfiles = append(lockfiles, rel)
			pm := DependencyFiles[d.Name()]
			for key, pkg := range collector.ReadLockfile(path, pm) {
				pkg.LockfilePath = rel
				resolved[rel+":"+key] = pkg
			}
		}
		return nil
	})
	if err != nil {
		return Snapshot{}, err
	}
	return Snapshot{
		SchemaVersion: "1.0",
		ProjectID:     projectID(root),
		RepoRoot:      root,
		CreatedAt:     now,
		UpdatedAt:     now,
		Files:         files,
		DependencyGraph: DependencyGraph{
			Direct:   direct,
			Resolved: resolved,
		},
		PackageManager:    inferPackageManager(lockfiles),
		ResolvedSupported: !hasBunLockB(lockfiles),
	}, nil
}

func registerProject(out io.Writer, root, source string, emitDiscovery bool) error {
	st := loadState()
	now := time.Now().UTC()
	if err := registerProjectRef(&st, root, now); err != nil {
		return err
	}
	if err := saveState(st); err != nil {
		return err
	}
	if err := createSnapshot(root); err != nil {
		return err
	}
	if emitDiscovery {
		_ = appendLedger(discoveredEvent(root, source))
	}
	fmt.Fprintf(out, "Observed project: %s\n", root)
	fmt.Fprintf(out, "Snapshot created: %s\n", snapshotPath(projectID(root)))
	return nil
}

func registerProjectRef(st *State, root string, now time.Time) error {
	abs, err := filepath.Abs(root)
	if err != nil {
		return err
	}
	for i := range st.Projects {
		if samePath(st.Projects[i].RepoRoot, abs) {
			st.Projects[i].Active = true
			return nil
		}
	}
	st.Projects = append(st.Projects, ProjectRef{ProjectID: projectID(abs), RepoRoot: abs, AddedAt: now, Active: true})
	return nil
}

func discoveredEvent(root, source string) DiscoveredEvent {
	snap, _ := buildSnapshot(root)
	var files []string
	for path := range snap.Files {
		files = append(files, path)
	}
	sort.Strings(files)
	return DiscoveredEvent{
		SchemaVersion:   "1.0",
		EventType:       "project_discovered",
		EventID:         "evt_" + randomHex(16),
		Timestamp:       time.Now().UTC().Format(time.RFC3339Nano),
		Source:          source,
		Project:         eventProject(root),
		DiscoveredFiles: files,
	}
}

func eventProject(root string) EventProject {
	remote := git(root, "config", "--get", "remote.origin.url")
	return EventProject{
		ProjectID:     projectID(root),
		RepoRootHash:  "sha256:" + sha256Hex(root),
		RepoRootLocal: root,
		GitRemoteHash: hashMaybe(remote),
		GitRemoteHost: remoteHost(remote),
		Branch:        git(root, "branch", "--show-current"),
		Commit:        git(root, "rev-parse", "--short", "HEAD"),
		Dirty:         strings.TrimSpace(git(root, "status", "--porcelain")) != "",
	}
}

func loadState() State {
	st := State{SchemaVersion: "1.0"}
	data, err := os.ReadFile(paths.ObserverStatePath())
	if err != nil {
		return st
	}
	if err := json.Unmarshal(data, &st); err != nil {
		return State{SchemaVersion: "1.0"}
	}
	return st
}

func saveState(st State) error {
	if err := os.MkdirAll(filepath.Dir(paths.ObserverStatePath()), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(paths.ObserverStatePath(), append(data, '\n'), 0o644)
}

func saveSnapshot(snapshot Snapshot) error {
	if err := os.MkdirAll(filepath.Dir(snapshotPath(snapshot.ProjectID)), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(snapshot, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(snapshotPath(snapshot.ProjectID), append(data, '\n'), 0o644)
}

func loadSnapshot(id string) (Snapshot, error) {
	data, err := os.ReadFile(snapshotPath(id))
	if err != nil {
		return Snapshot{}, err
	}
	var snapshot Snapshot
	return snapshot, json.Unmarshal(data, &snapshot)
}

func snapshotPath(id string) string {
	return filepath.Join(paths.SnapshotsDir(), id, "snapshot.json")
}

func appendLedger(event any) error {
	if err := os.MkdirAll(filepath.Dir(paths.LedgerPath()), 0o755); err != nil {
		return err
	}
	f, err := os.OpenFile(paths.LedgerPath(), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	data, err := json.Marshal(event)
	if err != nil {
		return err
	}
	_, err = f.Write(append(data, '\n'))
	return err
}

func currentRegisteredRoot() string {
	cwd, _ := os.Getwd()
	root := repoRoot(cwd)
	if root == "" {
		root = projectRoot(cwd)
	}
	st := loadState()
	for _, project := range st.Projects {
		if samePath(project.RepoRoot, root) {
			return project.RepoRoot
		}
	}
	return root
}

func projectRoot(path string) string {
	if root := repoRoot(path); root != "" {
		return root
	}
	for dir := path; dir != "." && dir != string(filepath.Separator); dir = filepath.Dir(dir) {
		for name := range DependencyFiles {
			if _, err := os.Stat(filepath.Join(dir, name)); err == nil {
				return dir
			}
		}
		if _, err := os.Stat(filepath.Join(dir, "package.json")); err == nil {
			return dir
		}
		next := filepath.Dir(dir)
		if next == dir {
			break
		}
	}
	abs, _ := filepath.Abs(path)
	return abs
}

func repoRoot(cwd string) string {
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")
	cmd.Dir = cwd
	out, err := cmd.Output()
	if err == nil {
		return strings.TrimSpace(string(out))
	}
	return ""
}

func git(cwd string, args ...string) string {
	cmd := exec.Command("git", args...)
	cmd.Dir = cwd
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func inferPackageManager(lockfiles []string) PackageManagerInference {
	candidates := map[string]bool{}
	for _, path := range lockfiles {
		if pm := DependencyFiles[filepath.Base(path)]; pm != "" {
			candidates[pm] = true
		}
	}
	var names []string
	for name := range candidates {
		names = append(names, name)
	}
	sort.Strings(names)
	if len(names) == 0 {
		return PackageManagerInference{Inferred: "unknown", Confidence: "low"}
	}
	if len(names) == 1 {
		return PackageManagerInference{Inferred: names[0], Confidence: "high"}
	}
	return PackageManagerInference{Inferred: "multiple", Candidates: names, Confidence: "low"}
}

func changedFiles(before, after map[string]FileSnapshot) []string {
	seen := map[string]bool{}
	for path := range before {
		seen[path] = true
	}
	for path := range after {
		seen[path] = true
	}
	var out []string
	for path := range seen {
		if before[path].Hash != after[path].Hash || before[path].Exists != after[path].Exists {
			out = append(out, path)
		}
	}
	sort.Strings(out)
	return out
}

func diffAdded(before, after map[string]collector.Package) []collector.Package {
	var out []collector.Package
	for key, pkg := range after {
		if _, ok := before[key]; !ok {
			out = append(out, pkg)
		}
	}
	sortPackages(out)
	return out
}

func diffRemoved(before, after map[string]collector.Package) []collector.Package {
	var out []collector.Package
	for key, pkg := range before {
		if _, ok := after[key]; !ok {
			out = append(out, pkg)
		}
	}
	sortPackages(out)
	return out
}

func diffUpdated(before, after map[string]collector.Package) []collector.Package {
	var out []collector.Package
	for key, next := range after {
		prev, ok := before[key]
		if !ok {
			continue
		}
		if prev.Version != next.Version || prev.Specifier != next.Specifier || prev.Resolved != next.Resolved || prev.Integrity != next.Integrity {
			out = append(out, next)
		}
	}
	sortPackages(out)
	return out
}

func sortPackages(pkgs []collector.Package) {
	sort.Slice(pkgs, func(i, j int) bool {
		if pkgs[i].Name == pkgs[j].Name {
			return pkgs[i].Version < pkgs[j].Version
		}
		return pkgs[i].Name < pkgs[j].Name
	})
}

func enrichDirectVersions(pkgs []collector.Package, resolved map[string]collector.Package) {
	byName := map[string]collector.Package{}
	for _, pkg := range resolved {
		if existing, ok := byName[pkg.Name]; !ok || pkg.Version > existing.Version {
			byName[pkg.Name] = pkg
		}
	}
	for i := range pkgs {
		if pkgs[i].Version != "" {
			continue
		}
		if resolvedPkg, ok := byName[pkgs[i].Name]; ok {
			pkgs[i].Version = resolvedPkg.Version
			pkgs[i].Resolved = resolvedPkg.Resolved
			pkgs[i].Integrity = resolvedPkg.Integrity
			continue
		}
		if version := versionFromSpecifier(pkgs[i].Specifier); version != "" {
			pkgs[i].Version = version
		}
	}
}

func versionFromSpecifier(specifier string) string {
	specifier = strings.TrimSpace(specifier)
	specifier = strings.TrimPrefix(specifier, "npm:")
	for _, prefix := range []string{"workspace:", "catalog:", "file:", "link:", "git+", "github:", "http:", "https:"} {
		if strings.HasPrefix(specifier, prefix) {
			return ""
		}
	}
	specifier = strings.TrimLeft(specifier, "^~>=< ")
	if specifier == "" || strings.ContainsAny(specifier, " *xX|") {
		return ""
	}
	if idx := strings.IndexByte(specifier, ' '); idx >= 0 {
		specifier = specifier[:idx]
	}
	return specifier
}

func normalizeChanges(changes *collector.Changes) {
	if changes.DirectAdded == nil {
		changes.DirectAdded = []collector.Package{}
	}
	if changes.DirectRemoved == nil {
		changes.DirectRemoved = []collector.Package{}
	}
	if changes.DirectUpdated == nil {
		changes.DirectUpdated = []collector.Package{}
	}
	if changes.ResolvedAdded == nil {
		changes.ResolvedAdded = []collector.Package{}
	}
	if changes.ResolvedRemoved == nil {
		changes.ResolvedRemoved = []collector.Package{}
	}
	if changes.ResolvedUpdated == nil {
		changes.ResolvedUpdated = []collector.Package{}
	}
}

func hasChanges(changes collector.Changes) bool {
	return len(changes.DirectAdded)+len(changes.DirectRemoved)+len(changes.DirectUpdated)+len(changes.ResolvedAdded)+len(changes.ResolvedRemoved)+len(changes.ResolvedUpdated) > 0
}

func isDependencyFile(name string) bool {
	return name == "package.json" || DependencyFiles[name] != ""
}

func hasBunLockB(paths []string) bool {
	for _, path := range paths {
		if filepath.Base(path) == "bun.lockb" {
			return true
		}
	}
	return false
}

func projectID(root string) string {
	return "proj_" + sha256Hex(root)[:24]
}

func sha256Hex(value string) string {
	sum := sha256.Sum256([]byte(value))
	return hex.EncodeToString(sum[:])
}

func hashMaybe(value string) string {
	if value == "" {
		return ""
	}
	return "sha256:" + sha256Hex(value)
}

func randomHex(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return sha256Hex(time.Now().String())[:n*2]
	}
	return hex.EncodeToString(b)
}

func remoteHost(remote string) string {
	if remote == "" {
		return ""
	}
	if strings.Contains(remote, "://") {
		if parsed, err := url.Parse(remote); err == nil {
			return parsed.Host
		}
	}
	if idx := strings.Index(remote, "@"); idx >= 0 {
		rest := remote[idx+1:]
		if colon := strings.Index(rest, ":"); colon >= 0 {
			return rest[:colon]
		}
	}
	return ""
}

func expandHome(path string) string {
	if path == "~" || strings.HasPrefix(path, "~/") {
		if home, err := os.UserHomeDir(); err == nil {
			return filepath.Join(home, strings.TrimPrefix(path, "~/"))
		}
	}
	return path
}

func relPath(root, path string) string {
	rel, err := filepath.Rel(root, path)
	if err != nil {
		return filepath.Base(path)
	}
	return rel
}

func samePath(a, b string) bool {
	aa, errA := filepath.EvalSymlinks(a)
	bb, errB := filepath.EvalSymlinks(b)
	if errA != nil {
		aa = filepath.Clean(a)
	}
	if errB != nil {
		bb = filepath.Clean(b)
	}
	return aa == bb
}

func depth(root, path string) int {
	rel, err := filepath.Rel(root, path)
	if err != nil || rel == "." {
		return 0
	}
	return len(strings.Split(rel, string(filepath.Separator)))
}
