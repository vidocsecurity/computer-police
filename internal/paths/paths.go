package paths

import (
	"os"
	"path/filepath"
)

func Home() string {
	if home := os.Getenv("PACKAGE_POLICE_HOME"); home != "" {
		return home
	}
	if home, err := os.UserHomeDir(); err == nil {
		return filepath.Join(home, ".package-police")
	}
	return ".package-police"
}

func ShimsDir() string { return filepath.Join(Home(), "shims") }

func LedgerPath() string {
	if path := os.Getenv("PACKAGE_POLICE_LEDGER_PATH"); path != "" {
		return path
	}
	return filepath.Join(Home(), "install-ledger", "events.ndjson")
}

func ConfigPath() string { return filepath.Join(Home(), "config.yml") }

func DebugLogPath() string { return filepath.Join(Home(), "logs", "debug.log") }

func ObserverDir() string { return filepath.Join(Home(), "observer") }

func ObserverStatePath() string { return filepath.Join(ObserverDir(), "state.json") }

func SnapshotsDir() string { return filepath.Join(ObserverDir(), "snapshots") }

func RecentDirsPath() string { return filepath.Join(Home(), "state", "recent-dirs.json") }

func ObserverPIDPath() string { return filepath.Join(ObserverDir(), "watcher.pid") }

func RegistryProxyDir() string { return filepath.Join(Home(), "registry-proxy") }

func RegistryProxyPIDPath() string { return filepath.Join(RegistryProxyDir(), "proxy.pid") }

func RegistryProxyEventsPath() string { return filepath.Join(RegistryProxyDir(), "events.ndjson") }

func RegistryProxyLogPath() string { return filepath.Join(RegistryProxyDir(), "proxy.log") }
