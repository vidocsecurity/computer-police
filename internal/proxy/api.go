package proxy

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"package-police/internal/paths"
)

const apiVersion = "0.1.0"

type apiHealthResponse struct {
	Status   string `json:"status"`
	Version  string `json:"version"`
	PID      int    `json:"pid"`
	Address  string `json:"address"`
	Upstream string `json:"upstream"`
}

type apiEventsResponse struct {
	Events []Event `json:"events"`
}

type apiStatsResponse struct {
	Window        string          `json:"window"`
	WindowStart   string          `json:"window_start"`
	WindowEnd     string          `json:"window_end"`
	Installs      int             `json:"installs"`
	Unique        int             `json:"unique_packages"`
	Blocked       int             `json:"blocked"`
	ByManager     map[string]int  `json:"by_manager"`
	TopPackages   []apiTopPackage `json:"top_packages"`
	LedgerPath    string          `json:"ledger_path"`
	LastUpdatedAt string          `json:"last_updated_at,omitempty"`
}

type apiAdvisoriesResponse struct {
	Malware MalwareAdvisoryStatus `json:"malware"`
}

type apiTopPackage struct {
	Package string `json:"package"`
	Version string `json:"version,omitempty"`
	Count   int    `json:"count"`
}

func mountAPIHandlers(mux *http.ServeMux, advisoryStore *MalwareAdvisoryStore) {
	mux.HandleFunc("/api/health", apiLoopbackOnly(apiMethod(http.MethodGet, apiHealth)))
	mux.HandleFunc("/api/events", apiLoopbackOnly(apiMethod(http.MethodGet, apiEvents)))
	mux.HandleFunc("/api/events/stream", apiLoopbackOnly(apiMethod(http.MethodGet, apiEventStream)))
	mux.HandleFunc("/api/stats", apiLoopbackOnly(apiMethod(http.MethodGet, apiStats)))
	if advisoryStore != nil {
		mux.HandleFunc("/api/advisories", apiLoopbackOnly(apiMethod(http.MethodGet, apiAdvisories(advisoryStore))))
	}
}

func apiMethod(method string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != method {
			w.Header().Set("Allow", method)
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		next(w, r)
	}
}

func apiLoopbackOnly(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !requestFromLoopback(r.RemoteAddr) {
			http.Error(w, "api is only available from loopback", http.StatusForbidden)
			return
		}
		next(w, r)
	}
}

func requestFromLoopback(remoteAddr string) bool {
	host := remoteAddr
	if h, _, err := net.SplitHostPort(remoteAddr); err == nil {
		host = h
	}
	if host == "" || host == "localhost" {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

func apiHealth(w http.ResponseWriter, _ *http.Request) {
	status := readStatusFile()
	if status.PID == 0 {
		status.PID = os.Getpid()
	}
	writeJSON(w, http.StatusOK, apiHealthResponse{
		Status:   "ok",
		Version:  apiVersion,
		PID:      status.PID,
		Address:  status.Address,
		Upstream: status.Upstream,
	})
}

func apiEvents(w http.ResponseWriter, r *http.Request) {
	limit := boundedIntQuery(r, "limit", 50, 1, 500)
	since, err := parseSince(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	events, err := readEvents(paths.RegistryProxyEventsPath(), since, limit)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			writeJSON(w, http.StatusOK, apiEventsResponse{Events: []Event{}})
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, apiEventsResponse{Events: events})
}

func apiEventStream(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}
	events := subscribeEvents()
	defer unsubscribeEvents(events)

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Connection", "keep-alive")
	_, _ = fmt.Fprint(w, ": connected\n\n")
	flusher.Flush()

	for {
		select {
		case <-r.Context().Done():
			return
		case event := <-events:
			data, err := json.Marshal(event)
			if err != nil {
				continue
			}
			_, _ = fmt.Fprintf(w, "event: package-event\nid: %s\ndata: %s\n\n", sseID(event.EventID), data)
			flusher.Flush()
		}
	}
}

func sseID(id string) string {
	id = strings.ReplaceAll(id, "\n", "")
	id = strings.ReplaceAll(id, "\r", "")
	return id
}

func apiStats(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	if etag, ok := ledgerETag(paths.RegistryProxyEventsPath()); ok {
		w.Header().Set("ETag", etag)
		if r.Header.Get("If-None-Match") == etag {
			w.WriteHeader(http.StatusNotModified)
			return
		}
	}
	window := r.URL.Query().Get("window")
	start, end, windowName, err := statsWindow(window, time.Now().UTC())
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	stats, err := buildStatsFromLedger(paths.RegistryProxyEventsPath(), start, end, windowName)
	if err != nil {
		if !errors.Is(err, os.ErrNotExist) {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		stats = emptyStats(start, end, windowName)
	}
	writeJSON(w, http.StatusOK, stats)
}

func apiAdvisories(store *MalwareAdvisoryStore) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, apiAdvisoriesResponse{Malware: store.Status()})
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func boundedIntQuery(r *http.Request, name string, fallback, min, max int) int {
	value := r.URL.Query().Get(name)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	if parsed < min {
		return min
	}
	if parsed > max {
		return max
	}
	return parsed
}

func parseSince(r *http.Request) (time.Time, error) {
	raw := r.URL.Query().Get("since")
	if raw == "" {
		return time.Time{}, nil
	}
	parsed, err := time.Parse(time.RFC3339, raw)
	if err != nil {
		parsed, err = time.Parse(time.RFC3339Nano, raw)
	}
	if err != nil {
		return time.Time{}, fmt.Errorf("invalid since timestamp %q", raw)
	}
	return parsed, nil
}

func readEvents(path string, since time.Time, limit int) ([]Event, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var events []Event
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		var event Event
		if err := json.Unmarshal(scanner.Bytes(), &event); err != nil {
			continue
		}
		if !since.IsZero() && eventTime(event).Before(since) {
			continue
		}
		events = append(events, event)
		if limit > 0 && len(events) > limit {
			events = events[1:]
		}
	}
	return events, scanner.Err()
}

func statsWindow(window string, now time.Time) (time.Time, time.Time, string, error) {
	switch strings.ToLower(window) {
	case "", "week":
		return now.AddDate(0, 0, -7), now, "week", nil
	case "day":
		return now.Add(-24 * time.Hour), now, "day", nil
	case "month":
		return now.AddDate(0, -1, 0), now, "month", nil
	default:
		return time.Time{}, time.Time{}, "", fmt.Errorf("unsupported window %q", window)
	}
}

func buildStatsFromLedger(path string, start, end time.Time, window string) (apiStatsResponse, error) {
	events, err := readEvents(path, start, 0)
	if err != nil {
		return apiStatsResponse{}, err
	}
	stats := emptyStats(start, end, window)
	unique := map[string]struct{}{}
	top := map[string]apiTopPackage{}
	seenTarballPackage := map[string]struct{}{}
	var metadataOnly []Event
	var last time.Time
	for _, event := range events {
		ts := eventTime(event)
		if ts.IsZero() || ts.Before(start) || ts.After(end) {
			continue
		}
		if ts.After(last) {
			last = ts
		}
		if event.Request.StatusCode == http.StatusForbidden {
			stats.Blocked++
		}
		if event.Request.Package == "" || event.Request.Type == "other" {
			continue
		}
		if event.Request.Type != "tarball" {
			metadataOnly = append(metadataOnly, event)
			continue
		}
		seenTarballPackage[event.Request.Package] = struct{}{}
		addStatsEvent(&stats, unique, top, event)
	}
	for _, event := range metadataOnly {
		if _, ok := seenTarballPackage[event.Request.Package]; ok {
			continue
		}
		addStatsEvent(&stats, unique, top, event)
		seenTarballPackage[event.Request.Package] = struct{}{}
	}
	stats.Unique = len(unique)
	stats.TopPackages = sortedTopPackages(top, 10)
	if !last.IsZero() {
		stats.LastUpdatedAt = last.Format(time.RFC3339Nano)
	}
	return stats, nil
}

func addStatsEvent(stats *apiStatsResponse, unique map[string]struct{}, top map[string]apiTopPackage, event Event) {
	stats.Installs++
	unique[event.Request.Package] = struct{}{}
	manager := event.Client.PackageManagerGuess
	if manager == "" {
		manager = "unknown"
	}
	stats.ByManager[manager]++
	key := event.Request.Package + "\x00" + event.Request.Version
	current := top[key]
	current.Package = event.Request.Package
	current.Version = event.Request.Version
	current.Count++
	top[key] = current
}

func emptyStats(start, end time.Time, window string) apiStatsResponse {
	return apiStatsResponse{
		Window:      window,
		WindowStart: start.Format(time.RFC3339Nano),
		WindowEnd:   end.Format(time.RFC3339Nano),
		ByManager: map[string]int{
			"npm":     0,
			"pnpm":    0,
			"bun":     0,
			"yarn":    0,
			"unknown": 0,
		},
		TopPackages: []apiTopPackage{},
		LedgerPath:  paths.RegistryProxyEventsPath(),
	}
}

func sortedTopPackages(top map[string]apiTopPackage, limit int) []apiTopPackage {
	packages := make([]apiTopPackage, 0, len(top))
	for _, pkg := range top {
		if pkg.Package == "" {
			continue
		}
		packages = append(packages, pkg)
	}
	sort.Slice(packages, func(i, j int) bool {
		if packages[i].Count != packages[j].Count {
			return packages[i].Count > packages[j].Count
		}
		if packages[i].Package != packages[j].Package {
			return packages[i].Package < packages[j].Package
		}
		return packages[i].Version < packages[j].Version
	})
	if len(packages) > limit {
		packages = packages[:limit]
	}
	return packages
}

func eventTime(event Event) time.Time {
	if event.Timestamp == "" {
		return time.Time{}
	}
	ts, err := time.Parse(time.RFC3339Nano, event.Timestamp)
	if err != nil {
		ts, err = time.Parse(time.RFC3339, event.Timestamp)
	}
	if err != nil {
		return time.Time{}
	}
	return ts
}

func ledgerETag(path string) (string, bool) {
	info, err := os.Stat(path)
	if err != nil {
		return `"empty"`, errors.Is(err, os.ErrNotExist)
	}
	return fmt.Sprintf(`"events-%d-%d"`, info.ModTime().UnixNano(), info.Size()), true
}
