package collector

import "time"

type Capture struct {
	TimestampStart time.Time `json:"timestamp_start"`
	TimestampEnd   time.Time `json:"timestamp_end"`
	CWD            string    `json:"cwd"`
	PackageManager string    `json:"package_manager"`
	Argv           []string  `json:"argv"`
	ExitCode       int       `json:"exit_code"`
	Before         State     `json:"before"`
}

type State struct {
	PackageJSONHash string             `json:"package_json_hash,omitempty"`
	LockfilePath    string             `json:"lockfile_path,omitempty"`
	LockfileHash    string             `json:"lockfile_hash,omitempty"`
	Direct          map[string]Package `json:"direct,omitempty"`
	Resolved        map[string]Package `json:"resolved,omitempty"`
}

type Package struct {
	Name           string `json:"name"`
	Version        string `json:"version,omitempty"`
	Specifier      string `json:"specifier,omitempty"`
	DependencyType string `json:"dependency_type,omitempty"`
	Resolved       string `json:"resolved,omitempty"`
	Integrity      string `json:"integrity,omitempty"`
	Direct         bool   `json:"direct"`
	ManifestPath   string `json:"manifest_path,omitempty"`
	LockfilePath   string `json:"lockfile_path,omitempty"`
}

type Event struct {
	SchemaVersion  string         `json:"schema_version"`
	EventID        string         `json:"event_id"`
	TimestampStart string         `json:"timestamp_start"`
	TimestampEnd   string         `json:"timestamp_end"`
	DurationMS     int64          `json:"duration_ms"`
	Actor          Actor          `json:"actor"`
	Project        Project        `json:"project"`
	PackageManager PackageManager `json:"package_manager"`
	State          EventState     `json:"state"`
	Changes        Changes        `json:"changes"`
	Collection     Collection     `json:"collection"`
}

type Actor struct {
	LocalUser     string `json:"local_user,omitempty"`
	MachineIDHash string `json:"machine_id_hash,omitempty"`
	AgentDetected bool   `json:"agent_detected"`
	AgentName     string `json:"agent_name,omitempty"`
}

type Project struct {
	CWD           string `json:"cwd"`
	RepoRoot      string `json:"repo_root,omitempty"`
	GitRemoteHash string `json:"git_remote_hash,omitempty"`
	GitRemoteHost string `json:"git_remote_host,omitempty"`
	Branch        string `json:"branch,omitempty"`
	Commit        string `json:"commit,omitempty"`
	Dirty         bool   `json:"dirty"`
}

type PackageManager struct {
	Name     string   `json:"name"`
	Version  string   `json:"version,omitempty"`
	Command  string   `json:"command"`
	Argv     []string `json:"argv"`
	ExitCode int      `json:"exit_code"`
}

type EventState struct {
	PackageJSONBeforeHash string `json:"package_json_before_hash,omitempty"`
	PackageJSONAfterHash  string `json:"package_json_after_hash,omitempty"`
	LockfilePath          string `json:"lockfile_path,omitempty"`
	LockfileBeforeHash    string `json:"lockfile_before_hash,omitempty"`
	LockfileAfterHash     string `json:"lockfile_after_hash,omitempty"`
	ResolvedDiffSupport   string `json:"resolved_diff_support,omitempty"`
}

type Changes struct {
	DirectAdded     []Package `json:"direct_added"`
	DirectRemoved   []Package `json:"direct_removed"`
	DirectUpdated   []Package `json:"direct_updated"`
	ResolvedAdded   []Package `json:"resolved_added"`
	ResolvedRemoved []Package `json:"resolved_removed"`
	ResolvedUpdated []Package `json:"resolved_updated"`
}

type Collection struct {
	Mode             string `json:"mode"`
	SourceUpload     bool   `json:"source_upload"`
	EnvUpload        bool   `json:"env_upload"`
	TerminalUpload   bool   `json:"terminal_output_upload"`
	CollectorVersion string `json:"collector_version"`
}
