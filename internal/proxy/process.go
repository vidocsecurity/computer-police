package proxy

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/vidoc/package-police/internal/paths"
)

type Status struct {
	Running  bool
	PID      int
	Address  string
	Upstream string
}

func StartBackground(out io.Writer, opts ServerOptions) error {
	opts = opts.withDefaults()
	status := ReadStatus()
	if status.Running {
		fmt.Fprintf(out, "Package Police registry proxy already running at http://%s\n", status.Address)
		return nil
	}
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(paths.RegistryProxyDir(), 0o755); err != nil {
		return err
	}
	logFile, err := os.OpenFile(paths.RegistryProxyLogPath(), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	args := []string{"proxy", "serve", "--host", opts.Host, "--port", strconv.Itoa(opts.Port), "--upstream", opts.Upstream}
	cmd := exec.Command(exe, args...)
	cmd.Stdout = logFile
	cmd.Stderr = logFile
	cmd.Stdin = nil
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := cmd.Start(); err != nil {
		_ = logFile.Close()
		return err
	}
	_ = logFile.Close()
	if err := waitUntilReachable(opts.Host, opts.Port, 5*time.Second); err != nil {
		return fmt.Errorf("proxy process started with pid %d but did not become reachable: %w", cmd.Process.Pid, err)
	}
	_ = cmd.Process.Release()
	fmt.Fprintf(out, "Started Package Police registry proxy at http://%s:%d\n", opts.Host, opts.Port)
	return nil
}

func Stop(out io.Writer) error {
	status := readStatusFile()
	if status.PID == 0 {
		fmt.Fprintln(out, "Package Police registry proxy is not running.")
		return nil
	}
	process, err := os.FindProcess(status.PID)
	if err != nil {
		return err
	}
	_ = process.Signal(syscall.SIGTERM)
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if !pidAlive(status.PID) {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	if pidAlive(status.PID) {
		_ = process.Kill()
	}
	_ = os.Remove(paths.RegistryProxyPIDPath())
	fmt.Fprintln(out, "Stopped Package Police registry proxy.")
	return nil
}

func ReadStatus() Status {
	status := readStatusFile()
	if status.PID == 0 || !pidAlive(status.PID) || status.Address == "" {
		return Status{}
	}
	conn, err := net.DialTimeout("tcp", status.Address, 300*time.Millisecond)
	if err != nil {
		return Status{}
	}
	_ = conn.Close()
	status.Running = true
	return status
}

func Doctor(out io.Writer) error {
	status := ReadStatus()
	fmt.Fprintln(out, "Package Police Local Registry Proxy")
	if status.Running {
		fmt.Fprintf(out, "✓ proxy running: http://%s (pid %d)\n", status.Address, status.PID)
	} else {
		fmt.Fprintln(out, "✗ proxy running: false")
	}
	registry := fmt.Sprintf("http://%s:%d/", DefaultHost, DefaultPort)
	if status.Address != "" {
		registry = "http://" + status.Address + "/"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if reachable(ctx, registry) {
		fmt.Fprintf(out, "✓ proxy ping reachable: %s\n", registry)
	} else {
		fmt.Fprintf(out, "✗ proxy ping reachable: %s\n", registry)
	}
	if projectConfigured(".npmrc", registry) {
		fmt.Fprintln(out, "✓ .npmrc configured for proxy")
	} else {
		fmt.Fprintln(out, "✗ .npmrc configured for proxy")
	}
	if projectConfigured("bunfig.toml", strings.TrimRight(registry, "/")) {
		fmt.Fprintln(out, "✓ bunfig.toml configured for proxy")
	} else {
		fmt.Fprintln(out, "• bunfig.toml configured for proxy: no")
	}
	events, err := readLastEvents(5)
	if err == nil && len(events) > 0 {
		fmt.Fprintf(out, "✓ recent proxy events: %d shown by `package-police proxy events`\n", len(events))
	} else {
		fmt.Fprintln(out, "• recent proxy events: none")
	}
	return nil
}

func readStatusFile() Status {
	f, err := os.Open(paths.RegistryProxyPIDPath())
	if err != nil {
		return Status{}
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	var lines []string
	for scanner.Scan() {
		lines = append(lines, strings.TrimSpace(scanner.Text()))
	}
	if len(lines) == 0 {
		return Status{}
	}
	pid, _ := strconv.Atoi(lines[0])
	status := Status{PID: pid}
	if len(lines) > 1 {
		status.Address = lines[1]
	}
	if len(lines) > 2 {
		status.Upstream = lines[2]
	}
	return status
}

func pidAlive(pid int) bool {
	if pid <= 0 {
		return false
	}
	process, err := os.FindProcess(pid)
	if err != nil {
		return false
	}
	return process.Signal(syscall.Signal(0)) == nil
}

func waitUntilReachable(host string, port int, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	addr := net.JoinHostPort(host, strconv.Itoa(port))
	var lastErr error
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("tcp", addr, 200*time.Millisecond)
		if err == nil {
			_ = conn.Close()
			return nil
		}
		lastErr = err
		time.Sleep(100 * time.Millisecond)
	}
	return lastErr
}

func projectConfigured(name, registry string) bool {
	data, err := os.ReadFile(filepath.Clean(name))
	if err != nil {
		return false
	}
	return strings.Contains(string(data), registry)
}

func HealthcheckURL() string {
	status := ReadStatus()
	if status.Address == "" {
		return fmt.Sprintf("http://%s:%d/-/ping", DefaultHost, DefaultPort)
	}
	return "http://" + status.Address + "/-/ping"
}

func Ping(ctx context.Context) bool {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, HealthcheckURL(), nil)
	if err != nil {
		return false
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode < 500
}
