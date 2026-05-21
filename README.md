<p align="center">
  <a href="https://github.com/vidocsecurity/computer-police">
    <img src="docs/hero.png" alt="Computer Police" width="640" />
  </a>
</p>

<h1 align="center">Computer Police</h1>

<p align="center"><strong>A local supply-chain firewall for your computer — and every agent on it.</strong></p>

<p align="center">
  <a href="https://github.com/vidocsecurity/computer-police/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/vidocsecurity/computer-police?style=flat-square&color=0a0a0c" /></a>
  <a href="https://github.com/vidocsecurity/computer-police/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/vidocsecurity/computer-police/ci.yml?style=flat-square&branch=main&label=ci" /></a>
  <img alt="macOS" src="https://img.shields.io/badge/macOS-14%2B-0a0a0c?style=flat-square" />
  <img alt="Linux" src="https://img.shields.io/badge/Linux-x86__64%20%7C%20arm64-0a0a0c?style=flat-square" />
  <img alt="Windows" src="https://img.shields.io/badge/Windows-x86__64-0a0a0c?style=flat-square" />
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-6e5aff?style=flat-square" /></a>
  <a href="https://osv.dev"><img alt="Powered by OSV" src="https://img.shields.io/badge/advisories-OSV.dev-16d3b4?style=flat-square" /></a>
</p>

<p align="center">
  <img src="docs/screenshot.png" alt="Computer Police menu-bar app showing protection on and a blocked install" width="520" />
</p>

---

Computer Police is an open-source tool that stops your machine from installing malicious packages — the kind that keep showing up in `npm`, `PyPI`, and every other public registry.

It runs locally as a registry proxy that sits between your package manager and the internet. Every install request is checked against the public [OSV](https://osv.dev) malicious-package advisory feed (`MAL-*`) and blocked with an HTTP `403` before any code touches your disk. It needs no root, no kernel extension, no system-wide proxy, and nothing about your installs ever leaves your machine.

It's built for the agent era. Claude Code, Codex, OpenCode, Cursor's agent, and any custom harness install packages constantly on your behalf — and they have no idea when one of them is malware. Computer Police is the seatbelt.

## Why Computer Police

- **Designed for agents.** Any package manager an agent invokes — `npm`, `pnpm`, `yarn`, `bun`, `pip`, `uv`, `poetry`, `pdm`, `pipx` — is protected automatically as soon as Computer Police is installed. No agent-specific plugin required.
- **Works anywhere a package manager runs.** Laptops, CI/CD pipelines, ephemeral devcontainers, remote agent sandboxes. One binary, one loopback listener.
- **Local-first and private by design.** Your install events, package names, and lockfiles never leave your machine. The only outbound network call is fetching the public OSV advisory snapshot.
- **No elevated privileges.** No `sudo`, no kernel hooks, no system proxy. Just a loopback HTTP listener and reversible edits to your package-manager config.
- **Open source and auditable.** Every blocking decision, every advisory source, and every config change is in this repository.

## How it works

```
  ┌──────────────┐     ┌──────────────────────┐     ┌──────────────────────┐
  │ npm / pnpm   │     │ Computer Police      │     │ npm registry         │
  │ yarn / bun   │ ──▶ │ 127.0.0.1:4873       │ ──▶ │ pypi.org             │
  │ pip / uv ... │     │ (local proxy)        │     │ (upstream registries)│
  └──────────────┘     └──────────┬───────────┘     └──────────────────────┘
                                  │
                                  ▼
                         block if version matches
                         OSV MAL-* advisory
                                  │
                                  ▼
                         append event to local
                         NDJSON ledger
```

1. `computer-police install` starts the local proxy and points your package managers at `http://127.0.0.1:4873/`.
2. Every install request is matched against a cached snapshot of OSV malicious-package advisories.
3. Known-bad versions are blocked with an HTTP `403` before any code is downloaded.
4. The result of every request is recorded to a local NDJSON ledger so you can audit what happened.

The malware advisory cache is refreshed in the background from the public OSV snapshot every 10 minutes. Set `COMPUTER_POLICE_OSV_ADVISORY_DIR` to point at a directory of OSV-format JSON for offline use, air-gapped environments, or testing.

## Trust model

|     | Computer Police does | Computer Police does not |
| --- | --- | --- |
| 1 | Run entirely on your machine | Send install events, package names, or lockfiles anywhere |
| 2 | Block known-malicious package versions before they download | Require `sudo`, kernel extensions, or a system-wide proxy |
| 3 | Refresh malware advisories from the public OSV snapshot | Phone home, collect analytics, or contact any private endpoint |
| 4 | Edit `npmrc`, `bunfig`, and `pip.conf` to route through `127.0.0.1` | Modify package binaries, lockfiles, or installed packages |
| 5 | Verify SHA-256 checksums of its own release artifacts on install | Auto-update itself without your consent |

## Install

### One-liner (macOS, Linux, Windows via WSL/Git Bash)

```bash
curl -fsSL https://raw.githubusercontent.com/vidocsecurity/computer-police/main/scripts/install.sh | bash
```

The installer detects your OS and architecture, downloads the matching GitHub Release artifact, verifies its SHA-256 checksum, and installs the CLI to `~/.computer-police/bin/computer-police`. On macOS it also installs the `Computer Police.app` menu-bar app to `/Applications`.

Pin a version:

```bash
curl -fsSL https://raw.githubusercontent.com/vidocsecurity/computer-police/main/scripts/install.sh | bash -s -- --version v0.1.0
```

### Update and uninstall

```bash
computer-police self update
computer-police self uninstall
```

Both go through the same signed installer script, with the same checksum verification.

## Quickstart

Sixty seconds to your first block.

```bash
# 1. Start protection (also rewrites your npm/bun/pip config to use the proxy).
computer-police install

# 2. Confirm everything looks right.
computer-police doctor

# 3. Try to install a known-malicious package. You should see HTTP 403.
npm install some-known-malicious-package@1.2.3

# 4. Look at the local event ledger.
computer-police ledger list --limit 20
```

When you're done, `computer-police uninstall` stops the proxy and restores every package-manager config file it changed.

## First-party support for coding agents

Because Computer Police works at the package-manager layer, *any* agent that runs `npm install`, `pip install`, `uv add`, or any other supported package manager is protected the moment you run `computer-police install`. There is nothing to configure per-agent and no plugin to maintain.

That includes:

- **Claude Code**
- **OpenAI Codex CLI**
- **OpenCode**
- **Cursor agent**
- **Custom harnesses** (any subprocess that uses a supported package manager)

We are also building per-agent auto-detection so that fresh installations of these harnesses get a one-click "protect this agent" step in onboarding. Track progress in [`PUBLIC_RELEASE_TASKS.md`](PUBLIC_RELEASE_TASKS.md).

## CI/CD and sandboxes

Computer Police is designed to work the same way in a CI runner, a devcontainer, or a remote agent VM as it does on your laptop.

GitHub Actions:

```yaml
- name: Install Computer Police
  run: |
    curl -fsSL https://raw.githubusercontent.com/vidocsecurity/computer-police/main/scripts/install.sh | bash
    echo "$HOME/.computer-police/bin" >> "$GITHUB_PATH"

- name: Enable supply-chain protection
  run: computer-police install

- name: Install dependencies (now behind Computer Police)
  run: npm ci

- name: Export install ledger
  if: always()
  run: computer-police ledger list --limit 1000 > computer-police-ledger.json
```

Dockerfile for an agent sandbox image:

```dockerfile
RUN curl -fsSL https://raw.githubusercontent.com/vidocsecurity/computer-police/main/scripts/install.sh \
      | bash \
 && /root/.computer-police/bin/computer-police install
ENV PATH="/root/.computer-police/bin:${PATH}"
```

The ledger file is plain NDJSON — one JSON object per install request — and is safe to attach to a build artifact for later audit.

## Package manager coverage

Status legend: **Supported** — proxy blocking is implemented and covered by end-to-end tests · **Partial** — related support exists, but important install paths are still missing · **Planned** — not implemented yet.

| Priority | Ecosystem | Package managers | Registry | Status |
| --- | --- | --- | --- | --- |
| P0 | JavaScript / TypeScript / Node | `npm`, `yarn`, `pnpm`, `bun` | npm registry | **Supported** |
| P0 | Python / PyPI | `pip`, `uv`, `poetry`, `pdm`, `pipx` | PyPI | **Supported** |
| P1 | Python / Conda | `conda`, `mamba`, `micromamba`, `pixi` | conda-forge, Anaconda | Planned |
| P1 | Ruby | `gem`, `bundler` | RubyGems | Planned |
| P1 | PHP | `composer` | Packagist | Planned |
| P1 | Rust | `cargo` | crates.io | Planned |
| P1 | Go | `go mod`, `go install` | Go module proxy | Planned |
| P1 | JVM | `maven`, `gradle` | Maven Central, Google Maven | Planned |
| P1 | .NET | `nuget`, `dotnet restore` | NuGet | Planned |

<details>
<summary>P2 and P3 ecosystems (planned)</summary>

| Priority | Ecosystem | Package managers | Registry | Next work |
| --- | --- | --- | --- | --- |
| P2 | Scala | `sbt`, `coursier`, `mill` | Maven repos, Ivy, Coursier cache | Reuse Maven proxy, add Coursier/sbt config coverage. |
| P2 | Clojure | Clojure CLI, `leiningen`, `boot` | Maven Central, Clojars | Reuse Maven proxy, add Clojars config coverage. |
| P2 | Dart / Flutter | `dart pub`, `flutter pub` | pub.dev | Add pub.dev hosted package metadata/download proxying. |
| P2 | Swift | Swift Package Manager | Git URLs, Swift package registries | Support Swift package registry flows; evaluate Git dependency blocking. |
| P2 | iOS / macOS legacy | `cocoapods`, `carthage` | CocoaPods Specs, Git | Add CocoaPods specs/source; evaluate Git-aware blocking for Carthage. |
| P2 | R | `install.packages`, `renv`, `pak` | CRAN, Bioconductor, RSPM | Add CRAN-like repository proxying and R repo config support. |
| P2 | Julia | `Pkg` | General registry, Julia package servers | Add Julia package server/registry proxying. |
| P3 | Elixir / Erlang | `mix`, `rebar3` | Hex.pm | Add Hex metadata/download proxying. |
| P3 | Haskell | `cabal`, `stack` | Hackage, Stackage | Add Hackage/Stackage metadata and tarball proxying. |
| P3 | OCaml | `opam` | opam repository | Add opam repository metadata/archive proxying. |
| P3 | Perl | `cpan`, `cpanm`, `Carton`, `Carmel` | CPAN | Add CPAN mirror/proxy support. |
| P3 | Lua | `luarocks` | LuaRocks | Add LuaRocks manifest and rock download proxying. |
| P3 | C / C++ | `conan`, `vcpkg` | ConanCenter, vcpkg, Git | Add Conan first; vcpkg likely needs Git-aware support. |
| P3 | D | `dub` | DUB registry | Add DUB registry proxying. |
| P3 | Nim | `nimble` | Nim package directory, Git | Add Nimble package index and Git-aware handling. |
| P3 | Zig | Zig package manager | URLs, Git, custom sources | Add URL/archive blocking once Zig conventions stabilize. |

</details>

## Privacy and data

- **Outbound network calls.** The only network endpoint Computer Police contacts on its own is the public OSV malicious-package advisory snapshot, used to refresh the local malware cache. There is no analytics, no telemetry, no remote logging.
- **Local state.** All Computer Police state lives under `~/.computer-police/`:
  - `registry-proxy/events.ndjson` — install ledger (one JSON object per request).
  - `registry-proxy/malware-advisories.json` — cached OSV advisory snapshot.
  - `bin/computer-police` — the CLI binary.
- **No background scanning.** Computer Police does not crawl your filesystem. It only sees package install requests you (or your agents) initiate while protection is enabled.
- **Reversible.** `computer-police uninstall` stops the proxy and restores every package-manager config file it ever changed. `computer-police self uninstall` removes the binary and on-disk state.

## Security model

**In scope.** Blocking installation of public package versions that are listed as malicious by OSV (`MAL-*` advisories) for the package managers and ecosystems marked **Supported** above.

**Out of scope (today).** Vulnerable-but-not-malicious dependencies (this is a malware tool, not a vulnerability scanner), runtime sandboxing of installed code, network egress filtering, post-install lifecycle-script analysis, and source-code analysis. Several of these are on the roadmap as the `harden` and `compromise-check` subcommands — see [`FEATURE_IDEAS.md`](FEATURE_IDEAS.md).

**Defense in depth.** Computer Police is a strong, focused layer. It does not replace pinning, lockfiles, code review, signed releases, or organizational policy. It complements them.

## Our own supply chain

Because Computer Police is a supply-chain security tool, we hold ourselves to the same bar:

- **Zero external Go dependencies.** The CLI is built from the Go standard library only. Check `go.mod`.
- **Reproducible release builds.** Cross-platform CLI archives and macOS app bundles are produced by GitHub Actions from tagged commits.
- **SHA-256 verified install.** The public installer downloads release artifacts and verifies their checksums before extracting anything.
- **Signed macOS updates.** Sparkle-signed appcast updates are coming with Developer-ID signing and notarization (see [`PUBLIC_RELEASE_TASKS.md`](PUBLIC_RELEASE_TASKS.md)).

## CLI reference

```text
computer-police install [--project]            # start proxy + point package managers at it (global by default)
computer-police uninstall [--project]          # restore package-manager config + stop the proxy
computer-police doctor                         # check binary, proxy, and registry config health
computer-police ledger list [--limit N]        # show recent install events
computer-police proxy start [--host H --port P]
computer-police proxy stop
computer-police proxy enable [--project]       # rewrite package-manager config only
computer-police proxy disable [--project]      # restore package-manager config only
computer-police proxy events [--limit N]
computer-police self update [--version vX.Y.Z]
computer-police self uninstall
```

When the proxy is running, three read-only JSON endpoints are exposed on the same loopback listener for the macOS app and for scripting:

- `GET /api/health`
- `GET /api/events?limit=50`
- `GET /api/stats?window=week`
- `GET /api/advisories`

## macOS app

The macOS menu-bar app lives in [`desktop/ComputerPolice/`](desktop/ComputerPolice/). It is a thin control surface over the same proxy: toggle protection on and off, see Binary / Proxy / Registry status lights, watch recent install events, and repair package-manager config if something else has touched it.

Build and run locally:

```bash
./scripts/dev.sh
```

See [`desktop/ComputerPolice/README.md`](desktop/ComputerPolice/README.md) for the full click-through checklist.

## Build from source

Requires Go 1.24+.

```bash
go build -o ./computer-police ./cmd/computer-police
go test ./...
go vet ./...
```

To run the proxy against bundled OSV test fixtures (no large download):

```bash
export COMPUTER_POLICE_OSV_ADVISORY_DIR=./internal/proxy/testdata/osv
./computer-police proxy start
```

For development conventions, environment setup, and CI rules see [`AGENTS.md`](AGENTS.md).

## Roadmap

The big bets, all open and tracked in this repo:

- **Onboarding compromise check.** "Have I already been hit?" — a one-time scan of your lockfiles, install history, and ledger against the OSV malicious-package corpus.
- **`computer-police harden`.** Repo hardening: pin direct deps, restrict lifecycle scripts, block lockfile drift in pre-commit, generate agent and CI policy files.
- **Broader ecosystem coverage.** Conda family next, then Ruby / PHP / Rust / Go / JVM / .NET. See the coverage table above.
- **First-party agent onboarding.** Per-agent auto-detection for Claude Code, Codex, OpenCode, Cursor, and custom harnesses.

Full breakdown in [`PUBLIC_RELEASE_TASKS.md`](PUBLIC_RELEASE_TASKS.md) and [`FEATURE_IDEAS.md`](FEATURE_IDEAS.md).

## Security disclosures

Please do **not** open a public GitHub issue for security vulnerabilities. Instead:

- Use [GitHub Security Advisories](https://github.com/vidocsecurity/computer-police/security/advisories/new), or
- Email [security@vidocsecurity.com](mailto:security@vidocsecurity.com).

We will acknowledge within two business days.

## Contributing

Computer Police is open source and contributions are welcome. Start with [`AGENTS.md`](AGENTS.md) for build/test instructions and [`PUBLIC_RELEASE_TASKS.md`](PUBLIC_RELEASE_TASKS.md) for the current task list. Issues and PRs are the right place for bugs, missing ecosystems, and feature requests.

## Credits

- Malicious-package advisories from [OSV.dev](https://osv.dev). Computer Police would not exist without their open vulnerability database.
- macOS menu-bar UX inspired by [CodexBar](https://github.com/steipete/CodexBar).

## License

MIT. See [`LICENSE`](LICENSE).
