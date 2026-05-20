package collector

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

func FileHash(path string) string {
	info, err := os.Stat(path)
	if err != nil || info.IsDir() || info.Size() > 50*1024*1024 {
		return ""
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	sum := sha256.Sum256(data)
	return "sha256:" + hex.EncodeToString(sum[:])
}

func fileHash(path string) string {
	return FileHash(path)
}

func ReadPackageJSON(path string) map[string]Package {
	data, err := os.ReadFile(path)
	if err != nil {
		return map[string]Package{}
	}
	var doc map[string]any
	if err := json.Unmarshal(data, &doc); err != nil {
		return map[string]Package{}
	}
	out := map[string]Package{}
	for _, depType := range []string{"dependencies", "devDependencies", "peerDependencies", "optionalDependencies", "bundleDependencies"} {
		raw, ok := doc[depType].(map[string]any)
		if !ok {
			if names, ok := doc[depType].([]any); ok {
				for _, nameAny := range names {
					name, _ := nameAny.(string)
					if name == "" {
						continue
					}
					out[depType+":"+name] = Package{Name: name, DependencyType: depType, Direct: true}
				}
			}
			continue
		}
		for name, specAny := range raw {
			spec, _ := specAny.(string)
			out[depType+":"+name] = Package{
				Name:           name,
				Specifier:      spec,
				DependencyType: depType,
				Direct:         true,
			}
		}
	}
	return out
}

func readPackageJSON(path string) map[string]Package {
	return ReadPackageJSON(path)
}

func DetectLockfile(cwd, pm string) string {
	return detectLockfile(cwd, pm)
}

func detectLockfile(cwd, pm string) string {
	candidates := map[string][]string{
		"npm":  {"package-lock.json", "npm-shrinkwrap.json"},
		"pnpm": {"pnpm-lock.yaml"},
		"yarn": {"yarn.lock"},
		"bun":  {"bun.lock", "bun.lockb"},
	}
	for _, name := range candidates[pm] {
		path := filepath.Join(cwd, name)
		if info, err := os.Stat(path); err == nil && !info.IsDir() {
			return path
		}
	}
	return ""
}

func ReadLockfile(path, pm string) map[string]Package {
	switch pm {
	case "npm":
		return readPackageLock(path)
	case "pnpm":
		return readPnpmLock(path)
	case "yarn":
		return readYarnLock(path)
	case "bun":
		if filepath.Base(path) == "bun.lockb" {
			return map[string]Package{}
		}
		return readBunLock(path)
	default:
		return map[string]Package{}
	}
}

func readLockfile(path, pm string) map[string]Package {
	return ReadLockfile(path, pm)
}

func readPackageLock(path string) map[string]Package {
	data, err := os.ReadFile(path)
	if err != nil {
		return map[string]Package{}
	}
	var doc struct {
		Packages map[string]struct {
			Name      string `json:"name"`
			Version   string `json:"version"`
			Resolved  string `json:"resolved"`
			Integrity string `json:"integrity"`
		} `json:"packages"`
		Dependencies map[string]struct {
			Version   string `json:"version"`
			Resolved  string `json:"resolved"`
			Integrity string `json:"integrity"`
		} `json:"dependencies"`
	}
	if err := json.Unmarshal(data, &doc); err != nil {
		return map[string]Package{}
	}
	out := map[string]Package{}
	for pkgPath, entry := range doc.Packages {
		if pkgPath == "" {
			continue
		}
		name := entry.Name
		if name == "" {
			name = strings.TrimPrefix(pkgPath, "node_modules/")
		}
		if name == "" || entry.Version == "" {
			continue
		}
		out[name+"@"+entry.Version] = Package{Name: name, Version: entry.Version, Resolved: entry.Resolved, Integrity: entry.Integrity, Direct: !strings.Contains(strings.TrimPrefix(pkgPath, "node_modules/"), "node_modules/")}
	}
	if len(out) == 0 {
		for name, entry := range doc.Dependencies {
			out[name+"@"+entry.Version] = Package{Name: name, Version: entry.Version, Resolved: entry.Resolved, Integrity: entry.Integrity}
		}
	}
	return out
}

func readPnpmLock(path string) map[string]Package {
	data, err := os.ReadFile(path)
	if err != nil {
		return map[string]Package{}
	}
	text := string(data)
	out := map[string]Package{}
	re := regexp.MustCompile(`(?m)^\s{2}(/(?:@[^/]+/)?[^/@\s]+)@([^:\s]+):\s*$`)
	integrityRe := regexp.MustCompile(`(?m)^\s{4,}integrity:\s*(\S+)`)
	for _, match := range re.FindAllStringSubmatchIndex(text, -1) {
		name := text[match[2]:match[3]]
		version := text[match[4]:match[5]]
		blockEnd := len(text)
		if next := re.FindStringSubmatchIndex(text[match[1]:]); next != nil && next[0] > 0 {
			blockEnd = match[1] + next[0]
		}
		block := text[match[1]:blockEnd]
		integrity := ""
		if im := integrityRe.FindStringSubmatch(block); len(im) == 2 {
			integrity = im[1]
		}
		out[name+"@"+version] = Package{Name: name, Version: version, Integrity: integrity}
	}
	return out
}

func readYarnLock(path string) map[string]Package {
	data, err := os.ReadFile(path)
	if err != nil {
		return map[string]Package{}
	}
	lines := strings.Split(string(data), "\n")
	out := map[string]Package{}
	var names []string
	version, resolved, integrity := "", "", ""
	flush := func() {
		if version == "" {
			return
		}
		for _, name := range names {
			out[name+"@"+version] = Package{Name: name, Version: version, Resolved: resolved, Integrity: integrity}
		}
	}
	for _, line := range lines {
		if strings.TrimSpace(line) == "" {
			continue
		}
		if !strings.HasPrefix(line, " ") && strings.HasSuffix(strings.TrimSpace(line), ":") {
			flush()
			names = parseYarnNames(strings.TrimSuffix(strings.TrimSpace(line), ":"))
			version, resolved, integrity = "", "", ""
			continue
		}
		trim := strings.TrimSpace(line)
		switch {
		case strings.HasPrefix(trim, "version "):
			version = trimQuoted(strings.TrimPrefix(trim, "version "))
		case strings.HasPrefix(trim, "resolved "):
			resolved = trimQuoted(strings.TrimPrefix(trim, "resolved "))
		case strings.HasPrefix(trim, "integrity "):
			integrity = strings.TrimSpace(strings.TrimPrefix(trim, "integrity "))
		}
	}
	flush()
	return out
}

func parseYarnNames(header string) []string {
	parts := strings.Split(header, ",")
	seen := map[string]bool{}
	var out []string
	for _, part := range parts {
		token := trimQuoted(strings.TrimSpace(part))
		name := yarnPackageName(token)
		if name != "" && !seen[name] {
			seen[name] = true
			out = append(out, name)
		}
	}
	return out
}

func yarnPackageName(token string) string {
	if strings.HasPrefix(token, "@") {
		parts := strings.SplitN(token, "@", 3)
		if len(parts) >= 3 {
			return "@" + parts[1]
		}
		return token
	}
	if idx := strings.Index(token, "@"); idx > 0 {
		return token[:idx]
	}
	return token
}

func readBunLock(path string) map[string]Package {
	data, err := os.ReadFile(path)
	if err != nil {
		return map[string]Package{}
	}
	out := map[string]Package{}
	re := regexp.MustCompile(`["']((?:@[^/]+/)?[^@"'\s]+)@([^"'\s]+)["']`)
	for _, m := range re.FindAllStringSubmatch(string(data), -1) {
		out[m[1]+"@"+m[2]] = Package{Name: m[1], Version: m[2]}
	}
	return out
}

func trimQuoted(value string) string {
	value = strings.TrimSpace(value)
	value = strings.Trim(value, `"`)
	return strings.Trim(value, `'`)
}
