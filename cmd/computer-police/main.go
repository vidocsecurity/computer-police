package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"

	"computer-police/internal/proxy"
)

var version = "0.1.0"

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) == 0 || args[0] == "help" || args[0] == "--help" || args[0] == "-h" {
		printHelp()
		return nil
	}

	switch args[0] {
	case "--version", "version":
		fmt.Println(version)
		return nil
	case "doctor":
		return proxy.Doctor(os.Stdout)
	case "install":
		return runInstall(args[1:])
	case "uninstall":
		return runUninstall(args[1:])
	case "self":
		return runSelf(args[1:])
	case "proxy":
		return runProxy(args[1:])
	case "ledger":
		return runLedger(args[1:])
	default:
		return fmt.Errorf("unknown command %q", args[0])
	}
}

func runSelf(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("self requires update or uninstall")
	}
	switch args[0] {
	case "update":
		installerArgs, err := argsWithCurrentInstallDir(args[1:])
		if err != nil {
			return err
		}
		return runPublicInstaller(installerArgs)
	case "uninstall":
		installerArgs, err := argsWithCurrentInstallDir(args[1:])
		if err != nil {
			return err
		}
		return runPublicInstaller(append([]string{"--uninstall"}, installerArgs...))
	default:
		return fmt.Errorf("unknown self command %q", args[0])
	}
}

func argsWithCurrentInstallDir(args []string) ([]string, error) {
	if hasFlag(args, "--install-dir") || os.Getenv("COMPUTER_POLICE_INSTALL_DIR") != "" {
		return args, nil
	}
	executable, err := os.Executable()
	if err != nil {
		return nil, fmt.Errorf("resolve current install dir: %w", err)
	}
	withInstallDir := append([]string{}, args...)
	withInstallDir = append(withInstallDir, "--install-dir", filepath.Dir(executable))
	return withInstallDir, nil
}

func runPublicInstaller(args []string) error {
	script, cleanup, err := publicInstallerScript()
	if err != nil {
		return err
	}
	defer cleanup()

	cmd := exec.Command("bash", append([]string{script}, args...)...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("public installer failed: %w", err)
	}
	return nil
}

func publicInstallerScript() (string, func(), error) {
	if script := os.Getenv("COMPUTER_POLICE_INSTALL_SCRIPT"); script != "" {
		return script, func() {}, nil
	}

	url := os.Getenv("COMPUTER_POLICE_INSTALLER_URL")
	if url == "" {
		url = "https://raw.githubusercontent.com/vidocsecurity/computer-police/main/scripts/install.sh"
	}

	resp, err := http.Get(url)
	if err != nil {
		return "", func() {}, fmt.Errorf("download installer: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", func() {}, fmt.Errorf("download installer: %s", resp.Status)
	}

	file, err := os.CreateTemp("", "computer-police-install-*.sh")
	if err != nil {
		return "", func() {}, err
	}
	cleanup := func() {
		_ = os.Remove(file.Name())
	}
	if _, err := io.Copy(file, resp.Body); err != nil {
		_ = file.Close()
		cleanup()
		return "", func() {}, err
	}
	if err := file.Close(); err != nil {
		cleanup()
		return "", func() {}, err
	}
	if err := os.Chmod(file.Name(), 0o755); err != nil {
		cleanup()
		return "", func() {}, err
	}
	return file.Name(), cleanup, nil
}

func runInstall(args []string) error {
	if err := proxy.StartBackground(os.Stdout, proxyOptions(args)); err != nil {
		return err
	}
	return proxy.EnableProject(os.Stdout, proxy.EnableOptions{
		RegistryURL: registryURL(args),
		Global:      !hasFlag(args, "--project"),
	})
}

func runUninstall(args []string) error {
	if err := proxy.DisableProject(os.Stdout, proxy.DisableOptions{
		Global: !hasFlag(args, "--project"),
	}); err != nil {
		return err
	}
	return proxy.Stop(os.Stdout)
}

func runProxy(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("proxy requires start, stop, enable, disable, doctor, events, or serve")
	}
	switch args[0] {
	case "start":
		return proxy.StartBackground(os.Stdout, proxyOptions(args[1:]))
	case "serve":
		return proxy.RunForeground(os.Stdout, proxyOptions(args[1:]))
	case "stop":
		return proxy.Stop(os.Stdout)
	case "enable":
		if err := proxy.StartBackground(os.Stdout, proxyOptions(args[1:])); err != nil {
			return err
		}
		return proxy.EnableProject(os.Stdout, proxy.EnableOptions{
			RegistryURL: registryURL(args[1:]),
			Global:      !hasFlag(args[1:], "--project"),
		})
	case "disable":
		return proxy.DisableProject(os.Stdout, proxy.DisableOptions{
			Global: !hasFlag(args[1:], "--project"),
		})
	case "doctor":
		return proxy.Doctor(os.Stdout)
	case "events":
		return proxy.ListEvents(os.Stdout, proxy.ListOptions{Limit: intFlag(args[1:], "--limit", 20)})
	default:
		return fmt.Errorf("unknown proxy command %q", args[0])
	}
}

func runLedger(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("ledger requires list")
	}
	switch args[0] {
	case "list":
		return proxy.ListEvents(os.Stdout, proxy.ListOptions{Limit: intFlag(args[1:], "--limit", 20)})
	default:
		return fmt.Errorf("unknown ledger command %q", args[0])
	}
}

func printHelp() {
	fmt.Println(`Computer Police Local Registry Proxy
Made by Vidoc Security Lab — https://www.vidocsecurity.com

Usage:
  computer-police install [--project]
  computer-police uninstall [--project]
  computer-police self update [--version v0.1.0]
  computer-police self uninstall
  computer-police doctor
  computer-police ledger list [--limit N]
  computer-police proxy start [--host 127.0.0.1] [--port 4873]
  computer-police proxy enable [--project]
  computer-police proxy disable [--project]
  computer-police proxy doctor
  computer-police proxy events [--limit N]

Local-only MVP: routes npm-compatible registry traffic through a local pass-through proxy and records request metadata.

When the proxy is running, read-only JSON endpoints are available on the same loopback listener:
  GET /api/health
  GET /api/events?limit=50
  GET /api/stats?window=week`)
}

func hasFlag(args []string, flag string) bool {
	for _, arg := range args {
		if arg == flag {
			return true
		}
	}
	return false
}

func intFlag(args []string, flag string, fallback int) int {
	for i := 0; i < len(args)-1; i++ {
		if args[i] == flag {
			var value int
			if _, err := fmt.Sscanf(args[i+1], "%d", &value); err == nil && value > 0 {
				return value
			}
		}
	}
	return fallback
}

func stringFlag(args []string, flag string) string {
	for i := 0; i < len(args)-1; i++ {
		if args[i] == flag {
			return args[i+1]
		}
	}
	return ""
}

func proxyOptions(args []string) proxy.ServerOptions {
	return proxy.ServerOptions{
		Host:         stringFlagDefault(args, "--host", proxy.DefaultHost),
		Port:         portFlag(args, "--port", proxy.DefaultPort),
		Upstream:     stringFlagDefault(args, "--upstream", proxy.DefaultUpstream),
		PyPIUpstream: stringFlagDefault(args, "--pypi-upstream", proxy.DefaultPyPIUpstream),
	}
}

func registryURL(args []string) string {
	opts := proxyOptions(args)
	return fmt.Sprintf("http://%s:%d/", opts.Host, opts.Port)
}

func stringFlagDefault(args []string, flag, fallback string) string {
	if value := stringFlag(args, flag); value != "" {
		return value
	}
	return fallback
}

func portFlag(args []string, flag string, fallback int) int {
	for i := 0; i < len(args)-1; i++ {
		if args[i] == flag {
			value, err := strconv.Atoi(args[i+1])
			if err == nil && value >= 0 {
				return value
			}
		}
	}
	return fallback
}
