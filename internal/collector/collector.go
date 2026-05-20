package collector

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/vidoc/package-police/internal/config"
	"github.com/vidoc/package-police/internal/paths"
)

func Collect(capturePath, version string) error {
	defer os.Remove(capturePath)
	data, err := os.ReadFile(capturePath)
	if err != nil {
		return err
	}
	var capture Capture
	if err := json.Unmarshal(data, &capture); err != nil {
		return err
	}
	after := CaptureState(capture.CWD, capture.PackageManager)
	event := BuildEvent(capture, after, version)
	if err := appendEvent(event); err != nil {
		Debugf("append event failed: %v", err)
		return err
	}
	return nil
}

func CaptureState(cwd, pm string) State {
	state := State{Direct: map[string]Package{}, Resolved: map[string]Package{}}
	state.PackageJSONHash = fileHash(filepath.Join(cwd, "package.json"))
	state.Direct = readPackageJSON(filepath.Join(cwd, "package.json"))
	lock := detectLockfile(cwd, pm)
	if lock != "" {
		state.LockfilePath = filepath.Base(lock)
		state.LockfileHash = fileHash(lock)
		state.Resolved = readLockfile(lock, pm)
	}
	return state
}

func BuildEvent(capture Capture, after State, version string) Event {
	changes := Changes{
		DirectAdded:     diffAdded(capture.Before.Direct, after.Direct),
		DirectRemoved:   diffRemoved(capture.Before.Direct, after.Direct),
		DirectUpdated:   diffUpdated(capture.Before.Direct, after.Direct),
		ResolvedAdded:   diffAdded(capture.Before.Resolved, after.Resolved),
		ResolvedRemoved: diffRemoved(capture.Before.Resolved, after.Resolved),
		ResolvedUpdated: diffUpdated(capture.Before.Resolved, after.Resolved),
	}
	enrichDirectVersions(changes.DirectAdded, after.Resolved)
	enrichDirectVersions(changes.DirectUpdated, after.Resolved)
	enrichDirectVersionsFromSpecifiers(changes.DirectAdded)
	enrichDirectVersionsFromSpecifiers(changes.DirectUpdated)
	changes.normalize()
	command := strings.TrimSpace(capture.PackageManager + " " + strings.Join(capture.Argv, " "))
	state := EventState{
		PackageJSONBeforeHash: capture.Before.PackageJSONHash,
		PackageJSONAfterHash:  after.PackageJSONHash,
		LockfilePath:          after.LockfilePath,
		LockfileBeforeHash:    capture.Before.LockfileHash,
		LockfileAfterHash:     after.LockfileHash,
	}
	if capture.PackageManager == "bun" && after.LockfilePath == "bun.lockb" {
		state.ResolvedDiffSupport = "unsupported-binary-lockfile"
	}
	return Event{
		SchemaVersion:  "1.0",
		EventID:        "evt_" + randomHex(16),
		TimestampStart: capture.TimestampStart.Format(time.RFC3339Nano),
		TimestampEnd:   capture.TimestampEnd.Format(time.RFC3339Nano),
		DurationMS:     capture.TimestampEnd.Sub(capture.TimestampStart).Milliseconds(),
		Actor:          actor(),
		Project:        project(capture.CWD),
		PackageManager: PackageManager{
			Name:     capture.PackageManager,
			Version:  packageManagerVersion(capture.PackageManager),
			Command:  command,
			Argv:     capture.Argv,
			ExitCode: capture.ExitCode,
		},
		State:   state,
		Changes: changes,
		Collection: Collection{
			Mode:             "local-only",
			SourceUpload:     false,
			EnvUpload:        false,
			TerminalUpload:   false,
			CollectorVersion: version,
		},
	}
}

func appendEvent(event Event) error {
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

func Debugf(format string, args ...any) {
	_ = os.MkdirAll(filepath.Dir(paths.DebugLogPath()), 0o755)
	f, err := os.OpenFile(paths.DebugLogPath(), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, time.Now().UTC().Format(time.RFC3339)+" "+format+"\n", args...)
}

func actor() Actor {
	u, _ := user.Current()
	host, _ := os.Hostname()
	agent := detectedAgent()
	return Actor{
		LocalUser:     username(u),
		MachineIDHash: "sha256:" + sha256Hex(host+"|"+username(u)),
		AgentDetected: agent != "",
		AgentName:     agent,
	}
}

func project(cwd string) Project {
	root := git(cwd, "rev-parse", "--show-toplevel")
	remote := git(cwd, "config", "--get", "remote.origin.url")
	host := remoteHost(remote)
	return Project{
		CWD:           cwd,
		RepoRoot:      root,
		GitRemoteHash: hashMaybe(remote),
		GitRemoteHost: host,
		Branch:        git(cwd, "branch", "--show-current"),
		Commit:        git(cwd, "rev-parse", "--short", "HEAD"),
		Dirty:         strings.TrimSpace(git(cwd, "status", "--porcelain")) != "",
	}
}

func packageManagerVersion(pm string) string {
	real := config.Load().RealBinaries[pm]
	if real == "" {
		real = config.FindRealBinary(pm)
	}
	if real == "" {
		return ""
	}
	out, err := exec.Command(real, "--version").Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
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

func username(u *user.User) string {
	if u == nil {
		return ""
	}
	if u.Username != "" {
		parts := strings.Split(u.Username, "\\")
		return parts[len(parts)-1]
	}
	return u.Name
}

func detectedAgent() string {
	keys := map[string]string{
		"CLAUDECODE":       "claude-code",
		"CURSOR_TRACE_ID":  "cursor",
		"CODEX_SANDBOX":    "codex",
		"OPENAI_AGENT":     "openai-agent",
		"OPENCODE_SESSION": "opencode",
		"GITHUB_COPILOT":   "github-copilot",
	}
	for key, name := range keys {
		if os.Getenv(key) != "" {
			return name
		}
	}
	return ""
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

func hashMaybe(value string) string {
	if value == "" {
		return ""
	}
	return "sha256:" + sha256Hex(value)
}

func sha256Hex(value string) string {
	sum := sha256.Sum256([]byte(value))
	return hex.EncodeToString(sum[:])
}

func randomHex(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return sha256Hex(time.Now().String())[:n*2]
	}
	return hex.EncodeToString(b)
}

func diffAdded(before, after map[string]Package) []Package {
	var out []Package
	for key, pkg := range after {
		if _, ok := before[key]; !ok {
			out = append(out, pkg)
		}
	}
	sortPackages(out)
	return out
}

func diffRemoved(before, after map[string]Package) []Package {
	var out []Package
	for key, pkg := range before {
		if _, ok := after[key]; !ok {
			out = append(out, pkg)
		}
	}
	sortPackages(out)
	return out
}

func diffUpdated(before, after map[string]Package) []Package {
	var out []Package
	for key, next := range after {
		prev, ok := before[key]
		if !ok {
			continue
		}
		if prev.Version != next.Version || prev.Specifier != next.Specifier || prev.Integrity != next.Integrity || prev.Resolved != next.Resolved {
			out = append(out, next)
		}
	}
	sortPackages(out)
	return out
}

func sortPackages(pkgs []Package) {
	sort.Slice(pkgs, func(i, j int) bool {
		if pkgs[i].Name == pkgs[j].Name {
			return pkgs[i].Version < pkgs[j].Version
		}
		return pkgs[i].Name < pkgs[j].Name
	})
}

func enrichDirectVersions(pkgs []Package, resolved map[string]Package) {
	byName := map[string]Package{}
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
		}
	}
}

func enrichDirectVersionsFromSpecifiers(pkgs []Package) {
	for i := range pkgs {
		if pkgs[i].Version != "" {
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

func (changes *Changes) normalize() {
	if changes.DirectAdded == nil {
		changes.DirectAdded = []Package{}
	}
	if changes.DirectRemoved == nil {
		changes.DirectRemoved = []Package{}
	}
	if changes.DirectUpdated == nil {
		changes.DirectUpdated = []Package{}
	}
	if changes.ResolvedAdded == nil {
		changes.ResolvedAdded = []Package{}
	}
	if changes.ResolvedRemoved == nil {
		changes.ResolvedRemoved = []Package{}
	}
	if changes.ResolvedUpdated == nil {
		changes.ResolvedUpdated = []Package{}
	}
}
