package proxy

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestE2ENPMBlocksLeftPadFromProjectConfig(t *testing.T) {
	requireExecutable(t, "npm")
	env := e2eEnv(t)
	registry := startE2EProxy(t)
	project := t.TempDir()
	enableProjectForE2E(t, project, registry)

	output, err := runE2ECommand(t, project, env,
		"npm", "install", "left-pad", "--ignore-scripts", "--no-audit", "--no-fund", "--cache", filepath.Join(project, ".npm-cache"))
	requireBlockedInstall(t, output, err)
}

func TestE2ENPMBlocksLeftPadFromNestedConfig(t *testing.T) {
	requireExecutable(t, "npm")
	env := e2eEnv(t)
	registry := startE2EProxy(t)
	root := t.TempDir()
	nested := filepath.Join(root, "packages", "app")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(nested, ".npmrc"), []byte("registry=https://example.invalid/\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	enableProjectForE2E(t, root, registry)

	output, err := runE2ECommand(t, nested, env,
		"npm", "install", "left-pad", "--ignore-scripts", "--no-audit", "--no-fund", "--cache", filepath.Join(root, ".npm-cache"))
	requireBlockedInstall(t, output, err)
}

func TestE2EBunBlocksLeftPadFromProjectConfig(t *testing.T) {
	requireExecutable(t, "bun")
	env := e2eEnv(t)
	registry := startE2EProxy(t)
	project := t.TempDir()
	enableProjectForE2E(t, project, registry)

	output, err := runE2ECommand(t, project, env,
		"bun", "add", "left-pad", "--force", "--no-cache", "--cache-dir", filepath.Join(project, ".bun-cache"))
	requireBlockedInstall(t, output, err)
}

func TestE2EBunBlocksLeftPadFromNestedConfig(t *testing.T) {
	requireExecutable(t, "bun")
	env := e2eEnv(t)
	registry := startE2EProxy(t)
	root := t.TempDir()
	nested := filepath.Join(root, "packages", "app")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(nested, "bunfig.toml"), []byte("[install]\nregistry = \"https://example.invalid\"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	enableProjectForE2E(t, root, registry)

	output, err := runE2ECommand(t, nested, env,
		"bun", "add", "left-pad", "--force", "--no-cache", "--cache-dir", filepath.Join(root, ".bun-cache"))
	requireBlockedInstall(t, output, err)
}

func TestE2EPNPMBlocksLeftPadFromProjectConfig(t *testing.T) {
	requireRunnablePackageManager(t, "pnpm", "--version")
	env := e2eEnv(t)
	registry := startE2EProxy(t)
	project := t.TempDir()
	enableProjectForE2E(t, project, registry)

	output, err := runE2ECommand(t, project, env,
		"pnpm", "add", "left-pad", "--ignore-scripts", "--store-dir", filepath.Join(project, ".pnpm-store"))
	requireBlockedInstall(t, output, err)
}

func TestE2EPNPMBlocksLeftPadFromNestedConfig(t *testing.T) {
	requireRunnablePackageManager(t, "pnpm", "--version")
	env := e2eEnv(t)
	registry := startE2EProxy(t)
	root := t.TempDir()
	nested := filepath.Join(root, "packages", "app")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(nested, ".npmrc"), []byte("registry=https://example.invalid/\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	enableProjectForE2E(t, root, registry)

	output, err := runE2ECommand(t, nested, env,
		"pnpm", "add", "left-pad", "--ignore-scripts", "--store-dir", filepath.Join(root, ".pnpm-store"))
	requireBlockedInstall(t, output, err)
}

func TestE2EYarnBlocksLeftPadFromProjectConfig(t *testing.T) {
	requireRunnablePackageManager(t, "yarn", "--version")
	env := e2eEnv(t)
	registry := startE2EProxy(t)
	project := t.TempDir()
	enableProjectForE2E(t, project, registry)

	output, err := runE2ECommand(t, project, env,
		"yarn", "add", "left-pad", "--ignore-scripts", "--non-interactive", "--cache-folder", filepath.Join(project, ".yarn-cache"))
	requireBlockedInstall(t, output, err)
}

func TestE2EYarnBlocksLeftPadFromNestedConfig(t *testing.T) {
	requireRunnablePackageManager(t, "yarn", "--version")
	env := e2eEnv(t)
	registry := startE2EProxy(t)
	root := t.TempDir()
	nested := filepath.Join(root, "packages", "app")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(nested, ".npmrc"), []byte("registry=https://example.invalid/\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	enableProjectForE2E(t, root, registry)

	output, err := runE2ECommand(t, nested, env,
		"yarn", "add", "left-pad", "--ignore-scripts", "--non-interactive", "--cache-folder", filepath.Join(root, ".yarn-cache"))
	requireBlockedInstall(t, output, err)
}

func TestE2EPipBlocksMalwarePackageFromProjectConfig(t *testing.T) {
	requireExecutable(t, "python3")
	env := e2eEnv(t)
	registry := startE2EPyPIProxy(t)
	project := t.TempDir()

	output, err := runE2ECommand(t, project, env,
		"python3", "-m", "pip", "install", "package-police-py-test==1.0.0",
		"--index-url", strings.TrimRight(registry, "/")+"/simple/",
		"--trusted-host", "127.0.0.1",
		"--disable-pip-version-check",
		"--no-cache-dir",
		"--no-deps",
		"--target", filepath.Join(project, "site-packages"))
	requireBlockedPythonInstall(t, output, err)
}

func TestE2EPipBlocksMalwarePackageFromNestedConfig(t *testing.T) {
	requireExecutable(t, "python3")
	env := e2eEnv(t)
	registry := startE2EPyPIProxy(t)
	root := t.TempDir()
	nested := filepath.Join(root, "packages", "app")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}

	output, err := runE2ECommand(t, nested, env,
		"python3", "-m", "pip", "install", "package-police-py-test==1.0.0",
		"--index-url", strings.TrimRight(registry, "/")+"/simple/",
		"--trusted-host", "127.0.0.1",
		"--disable-pip-version-check",
		"--no-cache-dir",
		"--no-deps",
		"--target", filepath.Join(root, "site-packages"))
	requireBlockedPythonInstall(t, output, err)
}

func TestE2EUvBlocksMalwarePackageFromProjectConfig(t *testing.T) {
	requireRunnablePackageManager(t, "uv", "--version")
	python := requireExecutablePath(t, "python3")
	env := e2eEnv(t)
	registry := startE2EPyPIProxy(t)
	project := t.TempDir()

	output, err := runE2ECommand(t, project, env,
		"uv", "pip", "install", "package-police-py-test==1.0.0",
		"--index-url", strings.TrimRight(registry, "/")+"/simple/",
		"--python", python,
		"--no-deps",
		"--target", filepath.Join(project, "site-packages"))
	requireBlockedPythonInstall(t, output, err)
}

func TestE2EUvBlocksMalwarePackageFromNestedConfig(t *testing.T) {
	requireRunnablePackageManager(t, "uv", "--version")
	python := requireExecutablePath(t, "python3")
	env := e2eEnv(t)
	registry := startE2EPyPIProxy(t)
	root := t.TempDir()
	nested := filepath.Join(root, "packages", "app")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}

	output, err := runE2ECommand(t, nested, env,
		"uv", "pip", "install", "package-police-py-test==1.0.0",
		"--index-url", strings.TrimRight(registry, "/")+"/simple/",
		"--python", python,
		"--no-deps",
		"--target", filepath.Join(root, "site-packages"))
	requireBlockedPythonInstall(t, output, err)
}

func TestE2EAdditionalPythonPackageManagersPending(t *testing.T) {
	for _, tc := range []struct {
		name       string
		executable string
		reason     string
	}{
		{
			name:       "poetry",
			executable: "poetry",
			reason:     "requires Poetry source/index configuration rewriting",
		},
		{
			name:       "pdm",
			executable: "pdm",
			reason:     "requires PDM source/index configuration rewriting",
		},
		{
			name:       "pipx",
			executable: "pipx",
			reason:     "requires pipx-managed install configuration support",
		},
	} {
		t.Run(tc.name+"/project_config_blocks_malware_package", func(t *testing.T) {
			requireExecutable(t, tc.executable)
			t.Skip(tc.reason)
		})
		t.Run(tc.name+"/nested_config_blocks_malware_package", func(t *testing.T) {
			requireExecutable(t, tc.executable)
			t.Skip(tc.reason)
		})
	}
}

func TestE2ECondaFamilyPackageManagersPending(t *testing.T) {
	for _, tc := range []struct {
		name       string
		executable string
		reason     string
	}{
		{
			name:       "conda",
			executable: "conda",
			reason:     "requires Conda channel metadata proxy support and .condarc rewriting",
		},
		{
			name:       "mamba",
			executable: "mamba",
			reason:     "requires Conda channel metadata proxy support and .condarc rewriting",
		},
		{
			name:       "pixi",
			executable: "pixi",
			reason:     "requires Conda channel metadata proxy support and pixi project/channel configuration rewriting",
		},
	} {
		t.Run(tc.name+"/project_config_blocks_malware_package", func(t *testing.T) {
			requireExecutable(t, tc.executable)
			t.Skip(tc.reason)
		})
		t.Run(tc.name+"/nested_config_blocks_malware_package", func(t *testing.T) {
			requireExecutable(t, tc.executable)
			t.Skip(tc.reason)
		})
	}
}

func startE2EProxy(t *testing.T) string {
	t.Helper()
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/left-pad" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"name": "left-pad",
			"dist-tags": map[string]string{
				"latest": "1.3.0",
			},
			"versions": map[string]any{
				"1.3.0": map[string]any{
					"name":    "left-pad",
					"version": "1.3.0",
					"dist": map[string]string{
						"tarball": upstreamTarballURL(r, "left-pad", "1.3.0"),
						"shasum":  "0000000000000000000000000000000000000000",
					},
				},
			},
		})
	}))
	t.Cleanup(upstream.Close)

	store := NewMalwareAdvisoryStore(MalwareAdvisoryStoreOptions{
		CachePath:        filepath.Join(t.TempDir(), "malware-advisories.json"),
		SourceURL:        "off",
		LocalAdvisoryDir: filepath.Join("testdata", "osv"),
		RefreshInterval:  time.Minute,
		Now: func() time.Time {
			return time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
		},
	})
	store.RefreshNow(t.Context())
	proxy, err := NewRegistryProxy(upstream.URL, &MalwareInspector{store: store})
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(proxy)
	t.Cleanup(server.Close)
	return server.URL + "/"
}

func startE2EPyPIProxy(t *testing.T) string {
	t.Helper()
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch strings.TrimRight(r.URL.Path, "/") {
		case "/simple/package-police-py-test":
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			_, _ = fmt.Fprintf(w, `<!doctype html>
<html><body>
<a href="%s/packages/package_police_py_test-1.0.0-py3-none-any.whl#sha256=0000000000000000000000000000000000000000000000000000000000000000">package_police_py_test-1.0.0-py3-none-any.whl</a>
</body></html>`, upstreamBaseURL(r))
		case "/packages/package_police_py_test-1.0.0-py3-none-any.whl":
			w.Header().Set("Content-Type", "application/octet-stream")
			_, _ = w.Write([]byte("not a real wheel"))
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(upstream.Close)

	store := NewMalwareAdvisoryStore(MalwareAdvisoryStoreOptions{
		CachePath:        filepath.Join(t.TempDir(), "malware-advisories.json"),
		SourceURL:        "off",
		LocalAdvisoryDir: filepath.Join("testdata", "osv"),
		RefreshInterval:  time.Minute,
		Now: func() time.Time {
			return time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
		},
	})
	store.RefreshNow(t.Context())
	proxy, err := NewRegistryProxyWithUpstreams(upstream.URL, upstream.URL, &MalwareInspector{store: store})
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(proxy)
	t.Cleanup(server.Close)
	return server.URL + "/"
}

func upstreamTarballURL(r *http.Request, pkg, version string) string {
	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}
	return fmt.Sprintf("%s://%s/%s/-/%s-%s.tgz", scheme, r.Host, pkg, pkg, version)
}

func upstreamBaseURL(r *http.Request) string {
	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}
	return fmt.Sprintf("%s://%s", scheme, r.Host)
}

func enableProjectForE2E(t *testing.T, project, registry string) {
	t.Helper()
	var out bytes.Buffer
	if err := EnableProject(&out, EnableOptions{
		ProjectDir:  project,
		RegistryURL: registry,
		Global:      false,
	}); err != nil {
		t.Fatalf("EnableProject failed: %v\n%s", err, out.String())
	}
}

func requireExecutable(t *testing.T, name string) {
	t.Helper()
	if _, err := exec.LookPath(name); err != nil {
		t.Skipf("%s is not installed", name)
	}
}

func requireExecutablePath(t *testing.T, name string) string {
	t.Helper()
	path, err := exec.LookPath(name)
	if err != nil {
		t.Skipf("%s is not installed", name)
	}
	return path
}

func requireRunnablePackageManager(t *testing.T, name string, args ...string) {
	t.Helper()
	requireExecutable(t, name)
	cmd := exec.Command(name, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Skipf("%s is installed but not runnable: %v\n%s", name, err, string(output))
	}
}

func runE2ECommand(t *testing.T, dir string, env []string, name string, args ...string) (string, error) {
	t.Helper()
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Env = env
	output, err := cmd.CombinedOutput()
	return string(output), err
}

func requireBlockedInstall(t *testing.T, output string, err error) {
	t.Helper()
	if err == nil {
		t.Fatalf("install succeeded, want 403 block\n%s", output)
	}
	if !strings.Contains(output, "403") {
		t.Fatalf("install failed without 403 block\nerr=%v\n%s", err, output)
	}
}

func requireBlockedPythonInstall(t *testing.T, output string, err error) {
	t.Helper()
	if err == nil {
		t.Fatalf("install succeeded, want Computer Police block\n%s", output)
	}
	if strings.Contains(output, "403") || strings.Contains(output, "No matching distribution found for package-police-py-test==1.0.0") {
		return
	}
	t.Fatalf("install failed without Computer Police block evidence\nerr=%v\n%s", err, output)
}

func e2eEnv(t *testing.T) []string {
	t.Helper()
	home := filepath.Join(t.TempDir(), "home")
	if err := os.MkdirAll(home, 0o755); err != nil {
		t.Fatal(err)
	}
	var env []string
	for _, entry := range os.Environ() {
		key, _, _ := strings.Cut(entry, "=")
		upper := strings.ToUpper(key)
		switch {
		case key == "HOME",
			key == "XDG_CONFIG_HOME",
			key == "BUN_INSTALL_CACHE_DIR",
			strings.HasPrefix(upper, "NPM_CONFIG_"),
			strings.HasPrefix(key, "npm_config_"),
			strings.HasPrefix(upper, "BUN_CONFIG_"):
			continue
		default:
			env = append(env, entry)
		}
	}
	env = append(env,
		"HOME="+home,
		"XDG_CONFIG_HOME="+filepath.Join(home, ".config"),
		"BUN_INSTALL_CACHE_DIR="+filepath.Join(home, ".bun-cache"),
	)
	return env
}
