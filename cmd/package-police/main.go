package main

import (
	"fmt"
	"os"
	"strconv"

	"github.com/vidoc/package-police/internal/agentdist"
	"github.com/vidoc/package-police/internal/collector"
	"github.com/vidoc/package-police/internal/config"
	"github.com/vidoc/package-police/internal/doctor"
	"github.com/vidoc/package-police/internal/ledger"
	"github.com/vidoc/package-police/internal/observer"
	"github.com/vidoc/package-police/internal/proxy"
	"github.com/vidoc/package-police/internal/shim"
)

const version = "0.1.0"

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
	case "agent-guard":
		return runAgentGuard(args[1:])
	case "doctor":
		jsonOut := hasFlag(args[1:], "--json")
		return doctor.Run(os.Stdout, jsonOut)
	case "onboard", "install":
		return runInstall(args[1:])
	case "uninstall":
		return runUninstall(args[1:])
	case "proxy":
		return runProxy(args[1:])
	case "observe":
		return runObserve(args[1:])
	case "snapshot":
		return runSnapshot(args[1:])
	case "ledger":
		return runLedger(args[1:])
	case "__shim":
		if len(args) < 2 {
			return fmt.Errorf("__shim requires a package manager name")
		}
		code := shim.Run(args[1], args[2:], version)
		os.Exit(code)
		return nil
	case "__collect":
		if len(args) != 2 {
			return fmt.Errorf("__collect requires a capture file")
		}
		return collector.Collect(args[1], version)
	case "__watch":
		return observer.RunWatcher()
	default:
		return fmt.Errorf("unknown command %q", args[0])
	}
}

func runInstall(args []string) error {
	if err := proxy.StartBackground(os.Stdout, proxyOptions(args)); err != nil {
		return err
	}
	return proxy.EnableProject(os.Stdout, proxy.EnableOptions{
		RegistryURL: registryURL(args),
		Bun:         hasFlag(args, "--bun"),
	})
}

func runUninstall(args []string) error {
	if err := proxy.DisableProject(os.Stdout, proxy.DisableOptions{Bun: hasFlag(args, "--bun")}); err != nil {
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
			Bun:         hasFlag(args[1:], "--bun"),
		})
	case "disable":
		return proxy.DisableProject(os.Stdout, proxy.DisableOptions{Bun: hasFlag(args[1:], "--bun")})
	case "doctor":
		return proxy.Doctor(os.Stdout)
	case "events":
		return proxy.ListEvents(os.Stdout, proxy.ListOptions{Limit: intFlag(args[1:], "--limit", 20)})
	default:
		return fmt.Errorf("unknown proxy command %q", args[0])
	}
}

func runObserve(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("observe requires here, init, add, list, remove, or reconcile")
	}
	switch args[0] {
	case "here":
		return observer.ObserveHere(os.Stdout)
	case "init":
		if hasFlag(args[1:], "--repo") {
			return observer.InitRepo(os.Stdout)
		}
		return observer.ObserveHere(os.Stdout)
	case "add":
		if len(args) < 2 {
			return fmt.Errorf("observe add requires a path")
		}
		return observer.Add(os.Stdout, args[1], hasFlag(args[2:], "--recursive"), intFlag(args[2:], "--max-depth", 8))
	case "list":
		return observer.List(os.Stdout)
	case "remove":
		if len(args) < 2 {
			return fmt.Errorf("observe remove requires a path or project id")
		}
		return observer.Remove(os.Stdout, args[1])
	case "reconcile":
		return observer.Reconcile(os.Stdout, "periodic_scan")
	default:
		return fmt.Errorf("unknown observe command %q", args[0])
	}
}

func runSnapshot(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("snapshot requires create or collect")
	}
	switch args[0] {
	case "create":
		return observer.SnapshotCreate(os.Stdout)
	case "collect":
		return observer.SnapshotCollect(os.Stdout)
	default:
		return fmt.Errorf("unknown snapshot command %q", args[0])
	}
}

func runAgentGuard(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("agent-guard requires init or uninstall")
	}
	switch args[0] {
	case "init":
		fmt.Fprintln(os.Stdout, "Package Police Agent Guard shims are superseded by the passive dependency observer.")
		fmt.Fprintln(os.Stdout, "No package-manager wrappers or PATH changes will be installed.")
		if hasFlag(args[1:], "--repo") {
			return observer.InitRepo(os.Stdout)
		}
		return observer.ObserveHere(os.Stdout)
	case "uninstall":
		return config.Uninstall(os.Stdout, config.UninstallOptions{
			DeleteLedger: hasFlag(args[1:], "--delete-ledger"),
		})
	default:
		return fmt.Errorf("unknown agent-guard command %q", args[0])
	}
}

func runLedger(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("ledger requires list or search")
	}
	switch args[0] {
	case "list":
		opts := ledger.ListOptions{Limit: intFlag(args[1:], "--limit", 20)}
		if hasFlag(args[1:], "--repo") {
			opts.Repo = "current"
		}
		opts.Package = stringFlag(args[1:], "--package")
		return ledger.List(os.Stdout, opts)
	case "search":
		if len(args) < 2 {
			return fmt.Errorf("ledger search requires a package name")
		}
		return ledger.Search(os.Stdout, args[1], ledger.ListOptions{Limit: intFlag(args[2:], "--limit", 50)})
	default:
		return fmt.Errorf("unknown ledger command %q", args[0])
	}
}

func printHelp() {
	fmt.Println(`Package Police Passive Dependency Observer

Usage:
  package-police onboard [--bun]
  package-police install [--bun]
  package-police uninstall [--bun]
  package-police proxy start [--host 127.0.0.1] [--port 4873]
  package-police proxy enable --project [--bun]
  package-police proxy disable --project [--bun]
  package-police proxy doctor
  package-police proxy events [--limit N]
  package-police observe here
  package-police observe init --repo
  package-police observe add <path> [--recursive] [--max-depth N]
  package-police observe list
  package-police observe remove <path-or-id>
  package-police snapshot create
  package-police snapshot collect
  package-police doctor [--json]
  package-police ledger list [--limit N] [--repo current] [--package NAME]
  package-police ledger search <package>

Local-only MVP: records JavaScript dependency file state changes and can route npm-compatible registry traffic through a local pass-through proxy without wrapping package managers.`)
	_ = agentdist.SectionMarker
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
		Host:     stringFlagDefault(args, "--host", proxy.DefaultHost),
		Port:     portFlag(args, "--port", proxy.DefaultPort),
		Upstream: stringFlagDefault(args, "--upstream", proxy.DefaultUpstream),
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
