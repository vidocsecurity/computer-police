package proxy

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestBuildStatsFromLedger(t *testing.T) {
	t.Setenv("PACKAGE_POLICE_HOME", t.TempDir())
	start := time.Date(2026, 5, 13, 12, 0, 0, 0, time.UTC)
	end := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
	path := filepath.Join(t.TempDir(), "events.ndjson")
	events := []Event{
		fixtureEvent("old", start.Add(-time.Hour), "tarball", "ignored", "1.0.0", http.StatusOK, "npm"),
		fixtureEvent("metadata", start.Add(time.Hour), "metadata", "left-pad", "", http.StatusOK, "npm"),
		fixtureEvent("install-1", start.Add(2*time.Hour), "tarball", "left-pad", "1.3.0", http.StatusOK, "npm"),
		fixtureEvent("install-2", start.Add(3*time.Hour), "tarball", "left-pad", "1.3.0", http.StatusOK, "pnpm"),
		fixtureEvent("install-3", start.Add(4*time.Hour), "tarball", "ua-parser-js", "0.7.29", http.StatusForbidden, "bun"),
		fixtureEvent("outside-future", end.Add(time.Hour), "tarball", "future", "1.0.0", http.StatusOK, "npm"),
	}
	writeFixtureEvents(t, path, events)

	stats, err := buildStatsFromLedger(path, start, end, "week")
	if err != nil {
		t.Fatal(err)
	}
	if stats.Installs != 3 {
		t.Fatalf("Installs = %d, want 3", stats.Installs)
	}
	if stats.Unique != 2 {
		t.Fatalf("Unique = %d, want 2", stats.Unique)
	}
	if stats.Blocked != 1 {
		t.Fatalf("Blocked = %d, want 1", stats.Blocked)
	}
	if stats.ByManager["npm"] != 1 || stats.ByManager["pnpm"] != 1 || stats.ByManager["bun"] != 1 {
		t.Fatalf("ByManager = %#v, want npm/pnpm/bun each 1", stats.ByManager)
	}
	if len(stats.TopPackages) == 0 || stats.TopPackages[0].Package != "left-pad" || stats.TopPackages[0].Count != 2 {
		t.Fatalf("TopPackages = %#v, want left-pad count 2 first", stats.TopPackages)
	}
}

func TestReadEventsHonorsSinceAndLimit(t *testing.T) {
	path := filepath.Join(t.TempDir(), "events.ndjson")
	base := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
	writeFixtureEvents(t, path, []Event{
		fixtureEvent("a", base, "tarball", "a", "1.0.0", http.StatusOK, "npm"),
		fixtureEvent("b", base.Add(time.Minute), "tarball", "b", "1.0.0", http.StatusOK, "npm"),
		fixtureEvent("c", base.Add(2*time.Minute), "tarball", "c", "1.0.0", http.StatusOK, "npm"),
	})

	events, err := readEvents(path, base.Add(30*time.Second), 1)
	if err != nil {
		t.Fatal(err)
	}
	if len(events) != 1 || events[0].EventID != "c" {
		t.Fatalf("events = %#v, want only newest event c", events)
	}
}

func TestAppendEventBroadcastsToSubscribers(t *testing.T) {
	t.Setenv("PACKAGE_POLICE_HOME", t.TempDir())
	events := subscribeEvents()
	defer unsubscribeEvents(events)

	event := fixtureEvent("blocked-1", time.Now().UTC(), "metadata", "left-pad", "1.3.0", http.StatusForbidden, "npm")
	event.Request.BlockedBy = "MAL-2026-PACKAGE-POLICE-LEFT-PAD"
	event.Request.BlockReason = "blocked for test"
	if err := appendEvent(event); err != nil {
		t.Fatal(err)
	}

	select {
	case got := <-events:
		if got.EventID != event.EventID || got.Request.BlockedBy != event.Request.BlockedBy {
			t.Fatalf("broadcast event = %#v, want %#v", got, event)
		}
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for broadcast event")
	}
}

func fixtureEvent(id string, ts time.Time, requestType, pkg, version string, status int, manager string) Event {
	return Event{
		SchemaVersion: "1.0",
		EventType:     "registry_request_observed",
		EventID:       id,
		Timestamp:     ts.Format(time.RFC3339Nano),
		Source:        "local_registry_proxy",
		Request: EventRequest{
			Method:     http.MethodGet,
			Path:       "/" + pkg,
			Type:       requestType,
			Package:    pkg,
			Version:    version,
			StatusCode: status,
			DurationMS: 12,
		},
		Upstream: EventUpstream{Registry: DefaultUpstream},
		Client: EventClient{
			UserAgent:           manager + "/test",
			PackageManagerGuess: manager,
			RemoteAddr:          "127.0.0.1",
		},
		Privacy: EventPrivacy{AuthHeadersLogged: false, BodyLogged: false},
	}
}

func writeFixtureEvents(t *testing.T, path string, events []Event) {
	t.Helper()
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	enc := json.NewEncoder(f)
	for _, event := range events {
		if err := enc.Encode(event); err != nil {
			t.Fatal(err)
		}
	}
}
