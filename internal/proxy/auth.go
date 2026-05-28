package proxy

import (
	"encoding/base64"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
)

func applyUpstreamAuth(req *http.Request, upstream *url.URL) {
	if req.Header.Get("Authorization") != "" {
		return
	}
	if auth := npmAuthorizationForUpstream(upstream); auth != "" {
		req.Header.Set("Authorization", auth)
	}
}

func npmAuthorizationForUpstream(upstream *url.URL) string {
	if upstream == nil {
		return ""
	}
	target := normalizeRegistryHost(upstream.Host)
	var fallbackToken, fallbackAuth, fallbackUser, fallbackPassword string
	for _, path := range npmAuthConfigPaths() {
		content, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		for _, line := range splitLines(string(content)) {
			key, value, ok := parseNPMRCKeyValue(line)
			if !ok {
				continue
			}
			host, name := splitNPMAuthKey(key)
			if host != "" && host != target {
				continue
			}
			switch name {
			case "_authToken":
				if host != "" {
					return "Bearer " + value
				}
				fallbackToken = value
			case "_auth":
				if host != "" {
					return "Basic " + value
				}
				fallbackAuth = value
			case "username":
				if host == "" {
					fallbackUser = value
				}
			case "_password":
				if host == "" {
					fallbackPassword = value
				}
			}
		}
	}
	if fallbackToken != "" {
		return "Bearer " + fallbackToken
	}
	if fallbackAuth != "" {
		return "Basic " + fallbackAuth
	}
	if fallbackUser != "" && fallbackPassword != "" {
		decoded, err := base64.StdEncoding.DecodeString(fallbackPassword)
		if err != nil {
			return ""
		}
		return "Basic " + base64.StdEncoding.EncodeToString([]byte(fallbackUser+":"+string(decoded)))
	}
	if token := os.Getenv("NPM_TOKEN"); token != "" {
		return "Bearer " + token
	}
	return ""
}

func npmAuthConfigPaths() []string {
	var paths []string
	if path := os.Getenv("NPM_CONFIG_USERCONFIG"); path != "" {
		paths = append(paths, path)
	}
	if home, err := os.UserHomeDir(); err == nil {
		paths = append(paths, filepath.Join(home, ".npmrc"))
	}
	if cwd, err := os.Getwd(); err == nil {
		paths = append(paths, filepath.Join(cwd, ".npmrc"))
	}
	return uniquePaths(paths)
}

func parseNPMRCKeyValue(line string) (string, string, bool) {
	trimmed := strings.TrimSpace(line)
	if trimmed == "" || strings.HasPrefix(trimmed, "#") || strings.HasPrefix(trimmed, ";") {
		return "", "", false
	}
	key, value, ok := strings.Cut(trimmed, "=")
	if !ok {
		return "", "", false
	}
	key = strings.TrimSpace(key)
	value = os.ExpandEnv(strings.Trim(strings.TrimSpace(value), `"'`))
	if key == "" || value == "" {
		return "", "", false
	}
	return key, value, true
}

func splitNPMAuthKey(key string) (host string, name string) {
	if !strings.HasPrefix(key, "//") {
		return "", key
	}
	withoutPrefix := strings.TrimPrefix(key, "//")
	index := strings.LastIndex(withoutPrefix, ":")
	if index < 0 {
		return "", key
	}
	return normalizeRegistryHost(withoutPrefix[:index]), withoutPrefix[index+1:]
}

func normalizeRegistryHost(host string) string {
	host = strings.TrimSpace(host)
	host = strings.TrimPrefix(host, "http://")
	host = strings.TrimPrefix(host, "https://")
	host = strings.Trim(host, "/")
	if before, _, ok := strings.Cut(host, "/"); ok {
		host = before
	}
	return strings.ToLower(host)
}
