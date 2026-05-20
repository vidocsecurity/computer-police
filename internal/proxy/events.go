package proxy

import (
	"bufio"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"package-police/internal/paths"
)

type Event struct {
	SchemaVersion string        `json:"schema_version"`
	EventType     string        `json:"event_type"`
	EventID       string        `json:"event_id"`
	Timestamp     string        `json:"timestamp"`
	Source        string        `json:"source"`
	Request       EventRequest  `json:"request"`
	Upstream      EventUpstream `json:"upstream"`
	Client        EventClient   `json:"client"`
	Privacy       EventPrivacy  `json:"privacy"`
}

type EventRequest struct {
	Method      string `json:"method"`
	Path        string `json:"path"`
	Type        string `json:"type"`
	Ecosystem   string `json:"ecosystem,omitempty"`
	Package     string `json:"package,omitempty"`
	Version     string `json:"version,omitempty"`
	StatusCode  int    `json:"status_code"`
	DurationMS  int64  `json:"duration_ms"`
	BlockedBy   string `json:"blocked_by,omitempty"`
	BlockReason string `json:"block_reason,omitempty"`
}

type EventUpstream struct {
	Registry string `json:"registry"`
}

type EventClient struct {
	UserAgent           string `json:"user_agent,omitempty"`
	PackageManagerGuess string `json:"package_manager_guess,omitempty"`
	RemoteAddr          string `json:"remote_addr,omitempty"`
}

type EventPrivacy struct {
	AuthHeadersLogged bool `json:"auth_headers_logged"`
	BodyLogged        bool `json:"body_logged"`
}

type RequestInfo struct {
	Type      string
	Ecosystem string
	Package   string
	Version   string
}

var tarballVersionRE = regexp.MustCompile(`^(.+)-([0-9][A-Za-z0-9.+~_-]*(?:-[A-Za-z0-9.+~_-]+)?)\.tgz$`)

func classifyRequest(rawPath string) RequestInfo {
	cleaned := strings.TrimPrefix(rawPath, "/")
	if cleaned == "" || strings.HasPrefix(cleaned, "-/") {
		return RequestInfo{Type: "other"}
	}
	decoded, err := url.PathUnescape(cleaned)
	if err != nil {
		decoded = cleaned
	}
	if info, ok := classifyPyPIRequest(decoded); ok {
		return info
	}
	parts := strings.Split(decoded, "/")
	if len(parts) >= 3 && parts[len(parts)-2] == "-" && strings.HasSuffix(parts[len(parts)-1], ".tgz") {
		pkg := parts[0]
		if strings.HasPrefix(pkg, "@") && len(parts) >= 4 {
			pkg = parts[0] + "/" + parts[1]
		}
		return RequestInfo{Type: "tarball", Ecosystem: "npm", Package: pkg, Version: tarballVersion(parts[len(parts)-1])}
	}
	if strings.HasPrefix(decoded, "@") {
		if strings.Contains(decoded, "/") {
			parts := strings.Split(decoded, "/")
			if len(parts) >= 2 {
				info := RequestInfo{Type: "metadata", Ecosystem: "npm", Package: parts[0] + "/" + parts[1]}
				if len(parts) >= 3 && parts[2] != "" {
					info.Version = parts[2]
				}
				return info
			}
		}
	}
	parts = strings.Split(decoded, "/")
	info := RequestInfo{Type: "metadata", Ecosystem: "npm", Package: parts[0]}
	if len(parts) >= 2 && parts[1] != "" {
		info.Version = parts[1]
	}
	return info
}

func classifyPyPIRequest(decoded string) (RequestInfo, bool) {
	parts := strings.Split(strings.Trim(decoded, "/"), "/")
	if len(parts) >= 2 && parts[0] == "simple" && parts[1] != "" {
		return RequestInfo{
			Type:      "pypi_metadata",
			Ecosystem: "PyPI",
			Package:   normalizePyPIName(parts[1]),
		}, true
	}
	if len(parts) >= 2 && parts[0] == "packages" {
		pkg, version := pypiFilenameCoordinate(path.Base(decoded))
		if pkg != "" && version != "" {
			return RequestInfo{Type: "pypi_file", Ecosystem: "PyPI", Package: pkg, Version: version}, true
		}
	}
	return RequestInfo{}, false
}

func tarballVersion(filename string) string {
	base := strings.TrimSuffix(path.Base(filename), ".tgz")
	matches := tarballVersionRE.FindStringSubmatch(path.Base(filename))
	if len(matches) == 3 {
		return matches[2]
	}
	idx := strings.LastIndex(base, "-")
	if idx < 0 || idx == len(base)-1 {
		return ""
	}
	return base[idx+1:]
}

func guessPackageManager(userAgent string) string {
	ua := strings.ToLower(userAgent)
	switch {
	case strings.Contains(ua, "pip/"):
		return "pip"
	case strings.Contains(ua, "uv/"):
		return "uv"
	case strings.Contains(ua, "bun/"):
		return "bun"
	case strings.Contains(ua, "pnpm/"):
		return "pnpm"
	case strings.Contains(ua, "yarn/"):
		return "yarn"
	case strings.Contains(ua, "npm/"):
		return "npm"
	default:
		return ""
	}
}

func appendEvent(event Event) error {
	if err := os.MkdirAll(filepath.Dir(paths.RegistryProxyEventsPath()), 0o755); err != nil {
		return err
	}
	f, err := os.OpenFile(paths.RegistryProxyEventsPath(), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
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

type ListOptions struct {
	Limit int
}

func ListEvents(out io.Writer, opts ListOptions) error {
	if opts.Limit <= 0 {
		opts.Limit = 20
	}
	events, err := readLastEvents(opts.Limit)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			fmt.Fprintln(out, "No proxy events recorded yet.")
			return nil
		}
		return err
	}
	for _, event := range events {
		version := ""
		if event.Request.Version != "" {
			version = "@" + event.Request.Version
		}
		pkg := event.Request.Package
		if pkg == "" {
			pkg = "-"
		}
		fmt.Fprintf(out, "%s %-8s %-30s %-3d %4dms %s\n",
			event.Timestamp,
			event.Request.Type,
			pkg+version,
			event.Request.StatusCode,
			event.Request.DurationMS,
			event.Request.Path,
		)
	}
	return nil
}

func readLastEvents(limit int) ([]Event, error) {
	f, err := os.Open(paths.RegistryProxyEventsPath())
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var events []Event
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		var event Event
		if err := json.Unmarshal(scanner.Bytes(), &event); err == nil {
			events = append(events, event)
			if len(events) > limit {
				events = events[1:]
			}
		}
	}
	return events, scanner.Err()
}

func eventID() string {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		sum := sha256.Sum256([]byte(time.Now().String()))
		return "evt_" + hex.EncodeToString(sum[:8])
	}
	return "evt_" + hex.EncodeToString(b)
}

func hostPort(addr string) string {
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return addr
	}
	return host
}
