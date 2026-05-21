# Feature Ideas

This file captures early product ideas to revisit later. These are intentionally rough notes, not committed roadmap.

## 1. Auto Harden Project

Build an automated project hardening flow inspired by the manual dependency hardening described in this post:

https://x.com/badlogicgames/status/2057108413113340039?s=20

Goal: let Computer Police inspect a project and apply or recommend the same kind of defensive supply-chain posture that `pi.dev` appears to have done manually.

Potential capabilities:

- Cut dependencies down to the absolute minimum.
- Identify heavy or risky SDKs that bring large transitive trees, such as Amazon Bedrock or Google GenAI SDKs.
- Ensure direct external dependencies are pinned.
- Generate or enforce an npm shrinkwrap for shipped CLI transitive dependencies.
- Disable lifecycle scripts for self-update flows, similar to `pi update --self`.
- Require explicit review when newly added dependencies introduce lifecycle scripts.
- Block lockfile changes in pre-commit unless explicitly allowed.
- Add scheduled GitHub checks for:
  - `npm audit`
  - npm registry signature verification
  - dependency updates when vulnerabilities are detected
- Support or document 2FA release requirements.

Possible product shape:

- `computer-police harden`: inspect the current repo and produce a hardening report.
- `computer-police harden --apply`: make low-risk mechanical changes automatically.
- `computer-police harden --policy`: generate repo policy files for agents, pre-commit, and CI.
- `computer-police harden --review-deps`: open an interactive dependency review focused on lifecycle scripts, lockfile changes, and new transitive exposure.

Open questions:

- Which hardening steps should be automatic versus advisory?
- How do we avoid breaking legitimate package-manager workflows?
- Should policies be repo-local, user-global, or organization-managed?
- How should this integrate with existing agent instructions and Computer Police install ledger data?

## 2. Agent Police

Explore a broader product called **Agent Police**.

Initial idea: a native macOS application that lives in the menu bar and monitors agent-related security posture. Start with a small test implementation using the existing work from CodexBar as a reference for the macOS menu-bar shell:

https://github.com/steipete/CodexBar

Possible initial scope:

- A macOS menu-bar app that shows Computer Police / Agent Police status.
- Quick visibility into whether agent guardrails are installed and active.
- Recent package-install events from the local ledger.
- Warnings when agents add new dependencies, change lockfiles, or trigger lifecycle scripts.
- Shortcuts to open project policy, ledger, and hardening reports.

Possible later scope:

- Agent activity timeline across local repos.
- Per-agent trust and policy profiles.
- Native notifications for risky package or lockfile events.
- One-click approval flow for dependency lifecycle scripts.
- Integration with `Auto Harden Project` checks.
- Organization-managed policy distribution.

Open questions:

- Should Agent Police be a separate product or the desktop surface for Computer Police?
- What should the menu-bar app do while no project is active?
- How much local data should be shown directly in the app versus opened in a report?
- Can CodexBar provide enough reusable structure for a quick prototype?

## 3. Compromise Check

Build an agentic tool that helps answer: **Was I already compromised?**

The tool would inspect a developer's local filesystem and connected GitHub account to look for signs that they, their repositories, or colleagues at their company may have been affected by a supply-chain attack.

Possible capabilities:

- Scan local projects for known malicious packages, versions, lockfile entries, and install history.
- Inspect Computer Police / Vidoc install ledger events for risky package-install timelines.
- Check GitHub repositories for suspicious dependency additions, lockfile changes, workflow edits, or release changes.
- Compare local findings against organization repositories to identify whether colleagues may have installed or committed the same risky package.
- Look for signs of credential exposure, such as suspicious GitHub Actions changes, new deploy keys, changed secrets usage, or unexpected automation.
- Produce an incident-response style report with:
  - affected projects
  - suspicious packages or versions
  - relevant commits and branches
  - potentially affected users or machines
  - recommended next actions

Possible product shape:

- `computer-police compromise-check`: run a local-first investigation.
- `computer-police compromise-check --github`: include GitHub account and repository checks.
- `computer-police compromise-check --org`: include organization-wide repository analysis where permissions allow.
- `computer-police compromise-check --since <date>`: focus on a suspicious time window.

Open questions:

- What GitHub permissions are needed without making the tool feel invasive?
- How do we distinguish real compromise signals from normal dependency churn?
- Should colleague/company checks require explicit organization admin approval?
- How should sensitive local findings be stored, redacted, or shared?

## 4. OSV Package Impact Detection

Use OSV.dev as a vulnerability and malicious-package intelligence source to detect whether a given package/version is affected.

Example supply-chain attack record:

https://osv.dev/vulnerability/MAL-2026-3841

Implementation references:

- Trivy OSV parser: https://github.com/aquasecurity/trivy-db/blob/main/pkg/vulnsrc/osv/osv.go
- OSV API `POST /v1/query`: https://google.github.io/osv.dev/post-v1-query/

Core idea:

- Given a package name, ecosystem, and version, query OSV to determine whether it is affected by a known vulnerability or malicious package advisory.
- Use this for install-time checks, retrospective ledger scans, hardening reports, and compromise checks.

API shape to consider:

- Query by package name plus ecosystem:
  - `package.name`
  - `package.ecosystem`
  - top-level `version`
- Query by package URL (`purl`) when available.
- Support pagination via `next_page_token` when OSV returns large result sets.
- Preserve OSV advisory IDs such as `MAL-*`, `GHSA-*`, `CVE-*`, and `OSV-*`.

Possible product shape:

- `computer-police check-package <name>@<version>`: check one package.
- `computer-police scan-lockfile`: check all resolved packages in a lockfile against OSV.
- `computer-police scan-ledger`: check previously observed install events against OSV.
- `computer-police watch-osv`: scheduled or cached OSV sync for newly disclosed advisories.

Open questions:

- Should Computer Police call OSV live, maintain a local cache, or support both?
- How should we map npm, pnpm, yarn, and bun lockfile entries into OSV ecosystems and purls?
- How do we distinguish malicious-package advisories from normal vulnerabilities in the UI and reports?
- Should OSV checks block installs, warn only, or be policy-controlled?
