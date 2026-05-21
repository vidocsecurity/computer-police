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
	"sync/atomic"
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
	python := requirePythonExecutablePath(t)
	env := e2eEnv(t)
	registry, blocked := startE2EPyPIProxy(t)
	project := t.TempDir()

	output, err := runE2ECommand(t, project, env,
		python, "-m", "pip", "install", "computer-police-py-test==1.0.0",
		"--index-url", strings.TrimRight(registry, "/")+"/simple/",
		"--trusted-host", "127.0.0.1",
		"--disable-pip-version-check",
		"--no-cache-dir",
		"--no-deps",
		"--target", filepath.Join(project, "site-packages"))
	requireBlockedPythonInstall(t, output, err, blocked)
}

func TestE2EPipBlocksMalwarePackageFromNestedConfig(t *testing.T) {
	python := requirePythonExecutablePath(t)
	env := e2eEnv(t)
	registry, blocked := startE2EPyPIProxy(t)
	root := t.TempDir()
	nested := filepath.Join(root, "packages", "app")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}

	output, err := runE2ECommand(t, nested, env,
		python, "-m", "pip", "install", "computer-police-py-test==1.0.0",
		"--index-url", strings.TrimRight(registry, "/")+"/simple/",
		"--trusted-host", "127.0.0.1",
		"--disable-pip-version-check",
		"--no-cache-dir",
		"--no-deps",
		"--target", filepath.Join(root, "site-packages"))
	requireBlockedPythonInstall(t, output, err, blocked)
}

func TestE2EUvBlocksMalwarePackageFromProjectConfig(t *testing.T) {
	requireRunnablePackageManager(t, "uv", "--version")
	python := requirePythonExecutablePath(t)
	env := e2eEnv(t)
	registry, blocked := startE2EPyPIProxy(t)
	project := t.TempDir()

	output, err := runE2ECommand(t, project, env,
		"uv", "pip", "install", "computer-police-py-test==1.0.0",
		"--index-url", strings.TrimRight(registry, "/")+"/simple/",
		"--python", python,
		"--no-deps",
		"--target", filepath.Join(project, "site-packages"))
	requireBlockedPythonInstall(t, output, err, blocked)
}

func TestE2EUvBlocksMalwarePackageFromNestedConfig(t *testing.T) {
	requireRunnablePackageManager(t, "uv", "--version")
	python := requirePythonExecutablePath(t)
	env := e2eEnv(t)
	registry, blocked := startE2EPyPIProxy(t)
	root := t.TempDir()
	nested := filepath.Join(root, "packages", "app")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}

	output, err := runE2ECommand(t, nested, env,
		"uv", "pip", "install", "computer-police-py-test==1.0.0",
		"--index-url", strings.TrimRight(registry, "/")+"/simple/",
		"--python", python,
		"--no-deps",
		"--target", filepath.Join(root, "site-packages"))
	requireBlockedPythonInstall(t, output, err, blocked)
}

func TestE2EPoetryBlocksMalwarePackageFromProjectConfig(t *testing.T) {
	requireRunnablePackageManager(t, "poetry", "--version")
	env := e2eEnv(t)
	registry, blocked := startE2EPyPIProxy(t)
	project := t.TempDir()
	writePoetryProject(t, project, registry)

	output, err := runE2ECommand(t, project, env,
		"poetry", "add", "computer-police-py-test==1.0.0",
		"--source", "computer-police",
		"--no-interaction",
		"--no-ansi")
	requireBlockedPythonInstall(t, output, err, blocked)
}

func TestE2EPoetryBlocksMalwarePackageFromNestedConfig(t *testing.T) {
	requireRunnablePackageManager(t, "poetry", "--version")
	env := e2eEnv(t)
	registry, blocked := startE2EPyPIProxy(t)
	root := t.TempDir()
	nested := filepath.Join(root, "packages", "app")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}
	writePoetryProject(t, nested, registry)

	output, err := runE2ECommand(t, nested, env,
		"poetry", "add", "computer-police-py-test==1.0.0",
		"--source", "computer-police",
		"--no-interaction",
		"--no-ansi")
	requireBlockedPythonInstall(t, output, err, blocked)
}

func TestE2EPDMBlocksMalwarePackageFromProjectConfig(t *testing.T) {
	requireRunnablePackageManager(t, "pdm", "--version")
	env := e2eEnv(t)
	registry, blocked := startE2EPyPIProxy(t)
	project := t.TempDir()
	writePDMProject(t, project, registry)

	output, err := runE2ECommand(t, project, env,
		"pdm", "add", "computer-police-py-test==1.0.0",
		"--no-sync")
	requireBlockedPythonInstall(t, output, err, blocked)
}

func TestE2EPDMBlocksMalwarePackageFromNestedConfig(t *testing.T) {
	requireRunnablePackageManager(t, "pdm", "--version")
	env := e2eEnv(t)
	registry, blocked := startE2EPyPIProxy(t)
	root := t.TempDir()
	nested := filepath.Join(root, "packages", "app")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}
	writePDMProject(t, nested, registry)

	output, err := runE2ECommand(t, nested, env,
		"pdm", "add", "computer-police-py-test==1.0.0",
		"--no-sync")
	requireBlockedPythonInstall(t, output, err, blocked)
}

func TestE2EPipxBlocksMalwarePackageFromProjectConfig(t *testing.T) {
	requireRunnablePackageManager(t, "pipx", "--version")
	env := e2eEnv(t)
	registry, blocked := startE2EPyPIProxy(t)
	project := t.TempDir()

	output, err := runE2ECommand(t, project, env,
		"pipx", "install", "computer-police-py-test==1.0.0",
		"--index-url", strings.TrimRight(registry, "/")+"/simple/",
		"--pip-args", "--trusted-host 127.0.0.1 --no-deps --no-cache-dir")
	requireBlockedPythonInstall(t, output, err, blocked)
}

func TestE2EPipxBlocksMalwarePackageFromNestedConfig(t *testing.T) {
	requireRunnablePackageManager(t, "pipx", "--version")
	env := e2eEnv(t)
	registry, blocked := startE2EPyPIProxy(t)
	root := t.TempDir()
	nested := filepath.Join(root, "packages", "app")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}

	output, err := runE2ECommand(t, nested, env,
		"pipx", "install", "computer-police-py-test==1.0.0",
		"--index-url", strings.TrimRight(registry, "/")+"/simple/",
		"--pip-args", "--trusted-host 127.0.0.1 --no-deps --no-cache-dir")
	requireBlockedPythonInstall(t, output, err, blocked)
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
			requireOptionalExecutable(t, tc.executable)
			pendingE2E(t, tc.reason)
		})
		t.Run(tc.name+"/nested_config_blocks_malware_package", func(t *testing.T) {
			requireOptionalExecutable(t, tc.executable)
			pendingE2E(t, tc.reason)
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

func startE2EPyPIProxy(t *testing.T) (string, func() int64) {
	t.Helper()
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch strings.TrimRight(r.URL.Path, "/") {
		case "/simple/computer-police-py-test":
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			_, _ = fmt.Fprintf(w, `<!doctype html>
<html><body>
<a href="%s/packages/computer_police_py_test-1.0.0-py3-none-any.whl#sha256=0000000000000000000000000000000000000000000000000000000000000000">computer_police_py_test-1.0.0-py3-none-any.whl</a>
</body></html>`, upstreamBaseURL(r))
		case "/packages/computer_police_py_test-1.0.0-py3-none-any.whl":
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
	inspector := &blockRecordingInspector{inner: &MalwareInspector{store: store}}
	proxy, err := NewRegistryProxyWithUpstreams(upstream.URL, upstream.URL, inspector)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(proxy)
	t.Cleanup(server.Close)
	return server.URL + "/", inspector.BlockedCount
}

type blockRecordingInspector struct {
	inner   *MalwareInspector
	blocked atomic.Int64
}

func (i *blockRecordingInspector) Inspect(r *http.Request, info RequestInfo) Decision {
	decision := i.inner.Inspect(r, info)
	i.record(decision)
	return decision
}

func (i *blockRecordingInspector) InspectResponse(r *http.Request, info RequestInfo, resp *http.Response, body []byte) Decision {
	decision := i.inner.InspectResponse(r, info, resp, body)
	i.record(decision)
	return decision
}

func (i *blockRecordingInspector) RewriteResponse(r *http.Request, info RequestInfo, resp *http.Response, body []byte) ResponseRewrite {
	rewrite := i.inner.RewriteResponse(r, info, resp, body)
	i.record(rewrite.Decision)
	return rewrite
}

func (i *blockRecordingInspector) BlockedCount() int64 {
	return i.blocked.Load()
}

func (i *blockRecordingInspector) record(decision Decision) {
	if !decision.Allowed {
		i.blocked.Add(1)
	}
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

func writePoetryProject(t *testing.T, dir, registry string) {
	t.Helper()
	content := fmt.Sprintf(`[tool.poetry]
name = "computer-police-e2e"
version = "0.1.0"
description = ""
authors = ["Computer Police <test@example.invalid>"]
package-mode = false

[tool.poetry.dependencies]
python = ">=3.9"

[[tool.poetry.source]]
name = "computer-police"
url = "%s"
priority = "primary"
`, strings.TrimRight(registry, "/")+"/simple/")
	if err := os.WriteFile(filepath.Join(dir, "pyproject.toml"), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func writePDMProject(t *testing.T, dir, registry string) {
	t.Helper()
	content := fmt.Sprintf(`[project]
name = "computer-police-e2e"
version = "0.1.0"
requires-python = ">=3.9"
dependencies = []

[[tool.pdm.source]]
name = "computer-police"
url = "%s"
verify_ssl = false
`, strings.TrimRight(registry, "/")+"/simple/")
	if err := os.WriteFile(filepath.Join(dir, "pyproject.toml"), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func requireExecutable(t *testing.T, name string) {
	t.Helper()
	if _, err := exec.LookPath(name); err != nil {
		if strictE2E() {
			t.Fatalf("%s is required for strict e2e but is not installed", name)
		}
		t.Skipf("%s is not installed", name)
	}
}

func requireOptionalExecutable(t *testing.T, name string) {
	t.Helper()
	if _, err := exec.LookPath(name); err != nil {
		t.Skipf("%s is not installed", name)
	}
}

func requireExecutablePath(t *testing.T, name string) string {
	t.Helper()
	path, err := exec.LookPath(name)
	if err != nil {
		if strictE2E() {
			t.Fatalf("%s is required for strict e2e but is not installed", name)
		}
		t.Skipf("%s is not installed", name)
	}
	return path
}

func requirePythonExecutablePath(t *testing.T) string {
	t.Helper()
	for _, name := range []string{"python3", "python"} {
		if path, err := exec.LookPath(name); err == nil {
			return path
		}
	}
	if strictE2E() {
		t.Fatal("python3/python is required for strict e2e but is not installed")
	}
	t.Skip("python3/python is not installed")
	return ""
}

func requireRunnablePackageManager(t *testing.T, name string, args ...string) {
	t.Helper()
	requireExecutable(t, name)
	cmd := exec.Command(name, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		if strictE2E() {
			t.Fatalf("%s is required for strict e2e but is not runnable: %v\n%s", name, err, string(output))
		}
		t.Skipf("%s is installed but not runnable: %v\n%s", name, err, string(output))
	}
}

func pendingE2E(t *testing.T, reason string) {
	t.Helper()
	if strictE2E() && os.Getenv("COMPUTER_POLICE_E2E_OPTIONAL_PENDING_STRICT") == "1" {
		t.Fatalf("strict e2e requires this package-manager case to be implemented: %s", reason)
	}
	t.Skip(reason)
}

func strictE2E() bool {
	return os.Getenv("COMPUTER_POLICE_E2E_STRICT") == "1"
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

func requireBlockedPythonInstall(t *testing.T, output string, err error, blocked func() int64) {
	t.Helper()
	if err == nil {
		t.Fatalf("install succeeded, want Computer Police block\n%s", output)
	}
	if blocked != nil && blocked() > 0 {
		return
	}
	if strings.Contains(output, "403") || strings.Contains(output, "No matching distribution found for computer-police-py-test==1.0.0") {
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
			key == "VIRTUAL_ENV",
			key == "XDG_CONFIG_HOME",
			key == "BUN_INSTALL_CACHE_DIR",
			strings.HasPrefix(upper, "PIP_"),
			strings.HasPrefix(upper, "PDM_"),
			strings.HasPrefix(upper, "PIPX_"),
			strings.HasPrefix(upper, "POETRY_"),
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
		"PIP_CACHE_DIR="+filepath.Join(home, ".cache", "pip"),
		"PIPX_BIN_DIR="+filepath.Join(home, ".local", "bin"),
		"PIPX_HOME="+filepath.Join(home, ".local", "pipx"),
		"PDM_CHECK_UPDATE=false",
		"PDM_CACHE_DIR="+filepath.Join(home, ".cache", "pdm"),
		"POETRY_CACHE_DIR="+filepath.Join(home, ".cache", "poetry"),
		"POETRY_VIRTUALENVS_IN_PROJECT=true",
	)
	return env
}
