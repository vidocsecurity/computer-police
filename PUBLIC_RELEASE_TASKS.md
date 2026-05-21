# Public Release Task List

This file is the short, opinionated version of the public-release plan. The
goal is to make it obvious what is already shipped, what is the next thing
worth doing, and what is far-future scope. Each epic has a one-line scope and
a small concrete checklist — not 30 sub-tickets.

Status legend:

- **Shipped** — implemented in the repo and exercised by tests or smoke test.
- **Partial** — code exists but has a real gap that blocks the public claim.
- **Next** — not started; this is the candidate work.

---

## What's already shipped (do not re-do)

Verified against `cmd/computer-police`, `internal/proxy`, `desktop/ComputerPolice`,
`scripts/install.sh`, `scripts/test-public-installer.sh`, `.github/workflows/`,
and `docs/RELEASING.md`:

- **Local registry proxy.** `/api/health`, `/api/events`, `/api/stats`,
  `/api/advisories`; NDJSON ledger; backgrounded `proxy start`.
- **Install-time blocking.** Current-year OSV `MAL-*` advisories from cached
  npm and PyPI snapshots, including packument rewriting and PyPI metadata
  link removal.
- **npm-family coverage.** `npm`, `yarn`, `pnpm`, `bun` — all routed via
  `.npmrc` / `bunfig.toml` with reversible backups.
- **PyPI proxy coverage.** Proxy serves `pip`, `uv`, `poetry`, `pdm`, `pipx`
  traffic and is e2e-tested for each. **Gap below**: the CLI does not yet
  rewrite Python registry config.
- **macOS menu-bar app.** Toggle protection, status lights, recent events,
  install bundled CLI, repair config.
- **Public installer.** One-liner entrypoint, OS/arch detect, GitHub Release
  artifact selection, SHA-256 verification, Linux/Windows CLI-only paths,
  macOS app + bundled CLI install, `self update`, `self uninstall`,
  unsupported-platform error.
- **Release workflow.** GitHub Actions builds cross-platform CLI archives
  and an ad-hoc-signed macOS app zip with checksums.
- **Docs already updated.** README installer flow, supported package
  managers, update path, uninstall path, checksum verification in
  `docs/RELEASING.md`. Linux installer smoke test (`scripts/test-public-installer.sh`).

---

## P0 — what is actually blocking a credible public 0.1.0

These are the items where shipping without them would either embarrass us or
mislead users. Suggested order top-down.

### 1. Make `install` configure Python package managers — **Partial**

The README claims `pip`, `uv`, `poetry`, `pdm`, `pipx` are supported, but
`internal/proxy/config.go` only configures npm and bun. Today users have to
set `--index-url` themselves; e2e tests do this manually.

- [ ] Detect installed Python package managers in `detectedSupportedManagers`.
- [ ] Write/restore `pip.conf` (`index-url`, `extra-index-url`) with backup.
- [ ] Write/restore `uv` config (`UV_INDEX_URL` via `uv.toml`).
- [ ] Write/restore `pyproject.toml` `[[tool.poetry.source]]` / `[[tool.pdm.source]]`
      or use `poetry config repositories` / `pdm config pypi.url` global settings.
- [ ] Mirror coverage in `computer-police doctor`.

### 2. macOS code signing + notarization — **Next**

Without Developer ID + notarization the macOS app shows a scary Gatekeeper
warning on first run. Sparkle auto-updates can wait; signing cannot.

- [ ] Add Developer ID signing to `scripts/release/package_macos_app.sh`.
- [ ] Notarize the macOS app zip in the release workflow.
- [ ] Add Apple release secrets to the repo
      (`APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_SPECIFIC_PASSWORD`,
       `DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64`,
       `DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD`).
- [ ] Have the installer prefer the signed/notarized zip on macOS.

### 3. Installer smoke tests for macOS and Windows — **Next**

Linux has `scripts/test-public-installer.sh`. We need the same shape for the
other two platforms before claiming cross-platform install.

- [ ] macOS smoke test (CLI-only via `--no-launch`; verify checksum-fail path).
- [ ] Windows smoke test in CI (Git Bash on `windows-latest`).
- [ ] Add an app+CLI version consistency check across release artifacts.

### 4. Security + privacy docs — **Next**

README has paragraphs on this but no standalone docs. We are a security tool;
this is table stakes.

- [ ] `docs/SECURITY-MODEL.md`: what we block, what we do not block, how the
      proxy decides, threat model assumptions.
- [ ] `docs/PRIVACY.md`: data residency, ledger contents, what leaves the
      machine (OSV snapshot only), what `--github`/`--org` would touch later.
- [ ] README "Supported OSes" section (light — currently in badges only).

### 5. Troubleshooting docs — **Next**

One short page, five sections. Each section is one paragraph and one command.

- [ ] `docs/TROUBLESHOOTING.md` covering: proxy startup failure, port conflict,
      registry config repair, advisory sync failure, restoring package-manager
      config by hand.

---

## P1 — first major features after public launch

These are the actual product bets. Each is a real epic; they are listed in
the order I'd build them in, not parallel.

### 6. `computer-police harden` — **Next**

Repo-level hardening — the most valuable thing we can add on top of install-time
blocking. Spec in `FEATURE_IDEAS.md` §1.

- [ ] `harden` (report only): inspect repo, produce findings.
- [ ] `harden --apply`: low-risk mechanical fixes (pin direct deps, generate
      shrinkwrap, restrict lifecycle scripts on self-update).
- [ ] `harden --policy`: generate agent, pre-commit, and CI policy files.
- [ ] `harden --review-deps`: interactive review for lifecycle scripts,
      lockfile changes, new transitive dependencies.
- [ ] Scheduled GitHub checks (`npm audit`, signature verification,
      vuln-triggered dep updates) and a 2FA release requirements doc.

### 7. `computer-police compromise-check` — **Next**

"Was I already hit?" — also doubles as the engine behind the onboarding
compromise check. Spec in `FEATURE_IDEAS.md` §3.

- [ ] `compromise-check` (local-first): scan local projects, lockfiles,
      install history, ledger, and package-manager caches against the
      OSV MAL corpus.
- [ ] `--github`: connected GitHub repos (deps, lockfiles, workflows,
      releases, deploy keys, secrets usage).
- [ ] `--org`: organization-wide where permissions allow.
- [ ] `--since <date>`: window-scoped investigation.
- [ ] Incident-response report: affected projects, suspicious packages,
      commits/branches, affected users, recommended next actions.
- [ ] Machine-readable report format for later audit and support.

### 8. Onboarding flow (depends on 6 + 7) — **Next**

Today there is no first-run flow in either the app or the CLI. Build it on
top of `compromise-check` + `harden` so it has something useful to show.

- [ ] First-run flow in CLI and macOS app with explicit consent and a clear
      explanation of what is inspected and where results are stored.
- [ ] Detect installed package managers, active config files, and local
      projects.
- [ ] Run a `compromise-check`-powered scan with progress UI in both
      surfaces; show clear result states (clean / suspicious / blocked).
- [ ] Optional hardening step (`harden --apply`-powered) with per-PM
      backups and a one-click rollback.
- [ ] Minimum package-age policy, surfaced in onboarding and applied by the
      proxy at install time.
- [ ] Rerun, skip, and resume affordances; tests for state transitions,
      report generation, and hardening rollback.

### 9. OSV expansion beyond cached `MAL-*` — **Partial**

Today we only consume current-year MAL entries from the OSV snapshot zip.
Spec in `FEATURE_IDEAS.md` §4.

- [ ] `check-package <name>@<version>` CLI.
- [ ] `scan-lockfile` CLI (npm, pnpm, yarn, bun, Python lockfiles → OSV
      ecosystem + purl).
- [ ] `scan-ledger` CLI.
- [ ] `watch-osv` CLI / scheduled refresh of newly disclosed advisories.
- [ ] Live OSV API support alongside cached snapshots, with purl queries
      and `next_page_token` pagination.
- [ ] Policy-controlled block-vs-warn for non-MAL OSV IDs (`GHSA-*`,
      `CVE-*`, `OSV-*`).

### 10. macOS auto-updates via Sparkle — **Next**

Useful once signing/notarization (P0 §2) is in.

- [ ] Add Sparkle as a SwiftPM dependency.
- [ ] `SUFeedURL` + `SUPublicEDKey` in `Info.plist`.
- [ ] Check for Updates menu action.
- [ ] Sparkle signatures on release artifacts; publish `appcast.xml`.

### 11. Agent workflow surface — **Next**

We market this as agent-aware; we should actually have agent-specific
commands and UI. Spec in `FEATURE_IDEAS.md` §2 and §5.

- [ ] CLI: agent init, readiness check, policy status.
- [ ] Generate agent instruction files (safe install rules + approved flows).
- [ ] Detect agent-driven dep additions, lockfile changes, lifecycle scripts.
- [ ] App + CLI warnings; app shortcuts to policy / ledger / hardening /
      agent status; per-agent trust profiles.
- [ ] Ship two agent-installable skills (spec in `FEATURE_IDEAS.md` §5):
      a **Harden Repository** skill that wraps `harden` (§6 above), and an
      **Add Computer Police to CI/CD** skill that injects install + enable
      steps into existing GitHub Actions workflows via a PR.
- [ ] Back the CI skill with a `computer-police ci install --provider github`
      command so the skill is a thin wrapper, not the source of truth.

### 12. Conda family — **Next**

Conda is the most-requested missing ecosystem and is currently optional in
e2e tests for that reason.

- [ ] Implement `conda`, `mamba`, `micromamba`, `pixi` proxy support
      (conda-forge, Anaconda, custom channels).
- [ ] Rewrite `.condarc` / mamba / micromamba / pixi project + channel config.
- [ ] Handle hybrid pixi projects (Conda + PyPI).
- [ ] Promote conda-family e2e from optional to strict CI coverage.

---

## P2 — ecosystem breadth (after the product is usable)

One bullet per ecosystem; each is a real implementation epic but the scope
is similar to npm/PyPI today.

- [ ] **Ruby** — RubyGems metadata + downloads; `.gemrc` and Bundler config.
- [ ] **PHP** — Composer + Packagist proxying; project and global config.
- [ ] **Rust** — Cargo sparse registry + index + crate download blocking.
- [ ] **Go** — Module proxy protocol; `GOPROXY` config.
- [ ] **JVM** — Maven repo + artifact proxying; Gradle and Maven config.
- [ ] **.NET** — NuGet v3 feed proxying; `nuget.config`; `dotnet restore`.

---

## P3 — long tail (gated on demand)

Tracked but not scheduled. Group → ecosystems:

- **Scala / Clojure** — `sbt`, `coursier`, `mill`, Clojure CLI, `leiningen`,
  `boot`, Clojars.
- **Dart / Flutter / Swift / iOS legacy** — `dart pub`, `flutter pub`, Swift
  package registry + Git deps, CocoaPods, Carthage.
- **R / Julia** — CRAN, Bioconductor, RSPM, `renv`, `pak`, Julia registry +
  package server.
- **Elixir / Erlang / Haskell / OCaml / Perl / Lua** — Hex, `mix`, `rebar3`,
  Hackage, Stackage, `cabal`, `stack`, opam, CPAN, `cpan`, `cpanm`, Carton,
  Carmel, LuaRocks.
- **C/C++ / D / Nim / Zig** — Conan, vcpkg (Git-aware), DUB, Nimble, Zig
  URL/archive blocking once conventions stabilize.

---

## Recommended next two weeks

If you only do one thing per week, do these:

1. **Close P0.** Land items 1–5 above (Python registry config, signing/notarization,
   macOS + Windows smoke tests, security/privacy docs, troubleshooting docs).
   This is what unblocks a public 0.1.0 announcement.
2. **Pick one P1 epic** (probably `harden` or `compromise-check`) and ship
   the minimal viable command. Everything else in P1/P2/P3 is post-launch
   and does not need to block the announcement.
