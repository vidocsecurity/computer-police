package agentdist

import (
	"os"
	"path/filepath"
	"strings"
)

const SectionMarker = "## Package Police Agent Guard"
const PassiveSectionMarker = "## Package Police Passive Dependency Observer"

type Options struct {
	Claude bool
}

func Install(root string, opts Options) ([]string, error) {
	var changed []string
	if path, ok, err := ensureAgents(root); err != nil {
		return changed, err
	} else if ok {
		changed = append(changed, path)
	}
	for _, writer := range []func(string) (string, bool, error){ensureCursorRule, ensureSkill} {
		path, ok, err := writer(root)
		if err != nil {
			return changed, err
		}
		if ok {
			changed = append(changed, path)
		}
	}
	if opts.Claude {
		path, ok, err := ensureClaude(root)
		if err != nil {
			return changed, err
		}
		if ok {
			changed = append(changed, path)
		}
	}
	return changed, nil
}

func InstallPassive(root string, opts Options) ([]string, error) {
	var changed []string
	for _, writer := range []func(string) (string, bool, error){ensurePassiveAgents, ensurePassiveCursorRule, ensurePassiveSkill} {
		path, ok, err := writer(root)
		if err != nil {
			return changed, err
		}
		if ok {
			changed = append(changed, path)
		}
	}
	return changed, nil
}

func ensurePassiveAgents(root string) (string, bool, error) {
	path := filepath.Join(root, "AGENTS.md")
	section := PassiveSectionMarker + `

When working in this repository, run:

` + "```bash" + `
package-police observe here
` + "```" + `

before making dependency changes.

Do not wrap or replace package-manager commands. Use normal commands such as:

` + "```bash" + `
npm install
pnpm add <package>
yarn add <package>
bun add <package>
` + "```" + `

After dependency changes, run:

` + "```bash" + `
package-police snapshot collect
` + "```" + `

Package Police records dependency file changes for supply-chain incident response. It does not collect source code, secrets, environment variables, or terminal output.
`
	return appendOnce(path, PassiveSectionMarker, section)
}

func ensurePassiveCursorRule(root string) (string, bool, error) {
	path := filepath.Join(root, ".cursor", "rules", "package-police-passive-dependency-observer.mdc")
	body := `---
description: Record JavaScript dependency state changes with Package Police without wrapping package managers
globs:
  - "package.json"
  - "package-lock.json"
  - "npm-shrinkwrap.json"
  - "pnpm-lock.yaml"
  - "yarn.lock"
  - "bun.lock"
  - "bun.lockb"
alwaysApply: true
---

Before modifying dependencies, run ` + "`package-police observe here`" + `.

Use normal package-manager commands. Do not use wrapper commands.

After dependency changes, run ` + "`package-police snapshot collect`" + ` if the passive watcher is not active.
`
	return writeIfDifferent(path, body)
}

func ensurePassiveSkill(root string) (string, bool, error) {
	path := filepath.Join(root, ".agents", "skills", "package-police-passive-dependency-observer", "SKILL.md")
	body := `---
name: package-police-passive-dependency-observer
description: ensure javascript and typescript dependency changes are recorded by package-police without wrapping npm, pnpm, yarn, or bun. use when working in repositories with package.json, lockfiles, dependency installation, dependency updates, package-manager commands, or supply-chain security workflows.
---

# Package Police Passive Dependency Observer

When working in a JavaScript or TypeScript repository:

1. Run ` + "`package-police observe here`" + ` before dependency changes.
2. Use normal package-manager commands.
3. Do not wrap, replace, alias, or bypass package managers.
4. After dependency changes, run ` + "`package-police snapshot collect`" + ` unless ` + "`package-police doctor`" + ` reports that passive watcher mode is active.
5. Package Police records dependency file changes only. It does not collect source code, secrets, environment variables, or terminal output.
`
	return writeIfDifferent(path, body)
}

func ensureAgents(root string) (string, bool, error) {
	path := filepath.Join(root, "AGENTS.md")
	section := SectionMarker + `

Before running package-manager install/update/add/remove commands, check whether Package Police Agent Guard is active:

` + "```bash" + `
package-police doctor
` + "```" + `

If package-manager shims are missing, run:

` + "```bash" + `
package-police agent-guard init
` + "```" + `

Use normal package-manager commands after Vidoc is active:

` + "```bash" + `
npm install
pnpm add <package>
yarn add <package>
bun add <package>
` + "```" + `

Do not bypass Package Police shims unless the user explicitly asks.
`
	return appendOnce(path, SectionMarker, section)
}

func ensureCursorRule(root string) (string, bool, error) {
	path := filepath.Join(root, ".cursor", "rules", "package-police-agent-guard.mdc")
	body := `---
description: Ensure JavaScript package installs are recorded by Package Police Agent Guard
globs:
  - "package.json"
  - "package-lock.json"
  - "pnpm-lock.yaml"
  - "yarn.lock"
  - "bun.lock"
  - "bun.lockb"
alwaysApply: true
---

Before running npm, pnpm, yarn, or bun install/update/add/remove commands, run ` + "`package-police doctor`" + ` if unsure whether Package Police Agent Guard is active.

If shims are missing, run ` + "`package-police agent-guard init`" + `.

After Vidoc is active, use normal package-manager commands. Do not bypass Package Police shims unless explicitly instructed by the user.
`
	return writeIfDifferent(path, body)
}

func ensureSkill(root string) (string, bool, error) {
	path := filepath.Join(root, ".agents", "skills", "package-police-agent-guard", "SKILL.md")
	body := `---
name: package-police-agent-guard
description: Ensure JavaScript dependency install commands are recorded by Package Police Agent Guard. Use when working in repositories with package.json, npm, pnpm, yarn, bun, lockfiles, dependency installation, dependency updates, or supply-chain security workflows.
---

# Package Police Agent Guard

When working in a JavaScript or TypeScript project:

1. Check whether Package Police Agent Guard is active before package install/update/add/remove commands.
2. Use ` + "`package-police doctor`" + ` to inspect status.
3. If shims are missing, ask to run ` + "`package-police agent-guard init`" + `.
4. After Vidoc is active, use normal package-manager commands.
5. Do not bypass Package Police shims unless the user explicitly asks.

Package Police Agent Guard records package names and versions installed during package-manager commands for future supply-chain incident response. It does not block installs or scan malware in the MVP.
`
	return writeIfDifferent(path, body)
}

func ensureClaude(root string) (string, bool, error) {
	hookPath := filepath.Join(root, ".package-police", "hooks", "claude-post-bash-package-install.sh")
	hook := `#!/bin/sh
case "$*" in
  *"npm install"*|*"npm i"*|*"npm update"*|*"pnpm add"*|*"pnpm install"*|*"yarn add"*|*"bun add"*)
    package-police doctor >/dev/null 2>&1 || echo "Package Police Agent Guard shims may be missing. Run: package-police agent-guard init"
    ;;
esac
exit 0
`
	if err := os.MkdirAll(filepath.Dir(hookPath), 0o755); err != nil {
		return hookPath, false, err
	}
	changed := false
	if existing, err := os.ReadFile(hookPath); err != nil || string(existing) != hook {
		if err := os.WriteFile(hookPath, []byte(hook), 0o755); err != nil {
			return hookPath, false, err
		}
		changed = true
	}
	settingsPath := filepath.Join(root, ".claude", "settings.json")
	settings := `{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".package-police/hooks/claude-post-bash-package-install.sh"
          }
        ]
      }
    ]
  }
}
`
	if _, ok, err := writeIfDifferent(settingsPath, settings); err != nil {
		return settingsPath, changed, err
	} else if ok {
		changed = true
	}
	return settingsPath, changed, nil
}

func appendOnce(path, marker, section string) (string, bool, error) {
	data, _ := os.ReadFile(path)
	if strings.Contains(string(data), marker) {
		return path, false, nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return path, false, err
	}
	prefix := strings.TrimRight(string(data), "\n")
	if prefix != "" {
		prefix += "\n\n"
	}
	return path, true, os.WriteFile(path, []byte(prefix+section), 0o644)
}

func writeIfDifferent(path, body string) (string, bool, error) {
	if existing, err := os.ReadFile(path); err == nil && string(existing) == body {
		return path, false, nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return path, false, err
	}
	return path, true, os.WriteFile(path, []byte(body), 0o644)
}
