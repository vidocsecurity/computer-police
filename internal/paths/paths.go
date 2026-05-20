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

func RegistryProxyDir() string { return filepath.Join(Home(), "registry-proxy") }

func RegistryProxyPIDPath() string { return filepath.Join(RegistryProxyDir(), "proxy.pid") }

func RegistryProxyEventsPath() string { return filepath.Join(RegistryProxyDir(), "events.ndjson") }

func RegistryProxyLogPath() string { return filepath.Join(RegistryProxyDir(), "proxy.log") }

func RegistryProxyAdvisoryCachePath() string {
	return filepath.Join(RegistryProxyDir(), "malware-advisories.json")
}
