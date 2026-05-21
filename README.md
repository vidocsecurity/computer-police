# Computer Police

Computer Police is a local package-registry proxy plus a macOS menu-bar frontend.

The proxy records local package install traffic in `~/.computer-police/registry-proxy/events.ndjson`, blocks package versions that match current-year OSV `MAL-*` advisories, and exposes read-only JSON endpoints on the same loopback listener:

- `GET /api/health`
- `GET /api/events?limit=50`
- `GET /api/stats?window=week`
- `GET /api/advisories`

The macOS app lives in `desktop/ComputerPolice`. It acts like a VPN-style control surface for package-install protection: start/stop the proxy, rewrite/repair npm and bun registry config, show status lights, surface weekly install counts, and flag packages that match the bundled mock blocklist.

## Manual App Test

```bash
./scripts/dev.sh
```

Then click the shield in the macOS menu bar. Useful test helpers:

```bash
./scripts/seed-events.sh
./scripts/kill-proxy.sh
./scripts/break-registry.sh
./scripts/uninstall-dev.sh
```

See `desktop/ComputerPolice/README.md` for the full click-through checklist.

## CLI

```bash
go build -o ~/.local/bin/computer-police ./cmd/computer-police
computer-police proxy start
computer-police proxy events --limit 20
computer-police proxy stop
```

Malware advisory data is cached at `~/.computer-police/registry-proxy/malware-advisories.json`, refreshed from the OSV npm snapshot every 10 minutes, and synced in the background when the proxy starts. The `/api/advisories` endpoint reports sync state and download progress for the menu bar app. For local testing, set `COMPUTER_POLICE_OSV_ADVISORY_DIR` to a directory of OSV-format JSON advisories; those advisories are layered onto the cache.

## Public Install

```bash
curl -fsSL https://raw.githubusercontent.com/vidocsecurity/computer-police/main/scripts/install.sh | bash
```

Use `computer-police self update` to update and `computer-police self uninstall` to remove the public install. The installer verifies release SHA-256 checksums before extracting artifacts. See `docs/RELEASING.md` for version pinning and platform details.

## Package Manager Coverage

Status legend:

- `Supported`: proxy blocking is implemented and covered by end-to-end tests.
- `Partial`: related support exists, but important install paths or configuration flows are missing.
- `Missing`: not implemented yet.

| Priority | Language / Ecosystem | Package managers / tools | Registry / source | Status | Next work |
|---|---|---|---|---|---|
| P0 | JavaScript / TypeScript / Node | `npm`, `yarn`, `pnpm`, `bun` | npm registry | Supported | Expand real-world fixture coverage and keep registry config repair current. |
| P0 | Python / PyPI | `pip`, `uv`, `poetry`, `pdm`, `pipx` | PyPI | Supported | Add more resolver/version-selection cases and project-config coverage. |
| P1 | Python / Conda | `conda`, `mamba`, `micromamba`, `pixi` | conda-forge, Anaconda channels, PyPI for hybrid pixi projects | Missing | Implement Conda channel metadata proxying and channel config rewriting. |
| P1 | Ruby | `gem`, `bundler` | RubyGems | Missing | Add RubyGems metadata/download classification and `.gemrc`/Bundler config support. |
| P1 | PHP | `composer` | Packagist / Composer repositories | Missing | Add Composer repository proxying and `composer.json`/global config support. |
| P1 | Rust | `cargo` | crates.io | Missing | Support Cargo sparse registry/index and crate download blocking. |
| P1 | Go | `go mod`, `go install` | Go module proxy, VCS | Missing | Add Go module proxy protocol support and `GOPROXY` configuration. |
| P1 | JVM: Java / Kotlin / Android | `maven`, `gradle` | Maven Central, Google Maven, custom Maven repos | Missing | Add Maven repository metadata/artifact proxying and Gradle/Maven config support. |
| P1 | .NET / C# / F# | `nuget`, `dotnet restore` | NuGet | Missing | Add NuGet v3 feed proxying and `nuget.config` support. |
| P2 | Scala | `sbt`, `coursier`, `mill` | Maven repos, Ivy, Coursier cache | Missing | Reuse Maven proxy work, then add Coursier/sbt config coverage. |
| P2 | Clojure | Clojure CLI / `deps.edn`, `leiningen`, `boot` | Maven Central, Clojars | Missing | Reuse Maven proxy work and add Clojars config coverage. |
| P2 | Dart / Flutter | `dart pub`, `flutter pub` | pub.dev | Missing | Add pub.dev hosted package metadata/download proxying. |
| P2 | Swift | Swift Package Manager | Git URLs, Swift package registries | Missing | Support Swift package registry flows and evaluate Git dependency blocking. |
| P2 | iOS / macOS legacy | `cocoapods`, `carthage` | CocoaPods Specs, GitHub/Git | Missing | Add CocoaPods specs/source support; Carthage likely needs Git-aware blocking. |
| P2 | R | `install.packages`, `renv`, `pak` | CRAN, Bioconductor, RSPM, GitHub | Missing | Add CRAN-like repository proxying and R repo config support. |
| P2 | Julia | `Pkg` | General registry, Julia package servers, Git | Missing | Add Julia package server/registry proxying. |
| P3 | Elixir / Erlang | `mix`, `rebar3` | Hex.pm | Missing | Add Hex package metadata/download proxying. |
| P3 | Haskell | `cabal`, `stack` | Hackage, Stackage | Missing | Add Hackage/Stackage metadata and tarball proxying. |
| P3 | OCaml | `opam` | opam repository, source archives | Missing | Add opam repository metadata/archive proxying. |
| P3 | Perl | `cpan`, `cpanm`, `Carton`, `Carmel` | CPAN | Missing | Add CPAN mirror/proxy support. |
| P3 | Lua | `luarocks` | LuaRocks | Missing | Add LuaRocks manifest and rock download proxying. |
| P3 | C / C++ | `conan`, `vcpkg` | ConanCenter, vcpkg registries, Git | Missing | Add Conan first; vcpkg likely needs registry/Git-aware support. |
| P3 | D | `dub` | DUB registry | Missing | Add DUB registry proxying. |
| P3 | Nim | `nimble` | Nim package directory, Git | Missing | Add Nimble package index and Git-aware handling. |
| P3 | Zig | Zig package manager / `build.zig.zon` | URLs, Git, custom sources | Missing | Add URL/archive blocking once Zig package-manager conventions stabilize. |

## CI and Releases

GitHub Actions run Go tests across Linux, macOS, and Windows, plus Swift app builds/tests on macOS.

Release tags such as `v0.1.0` publish a GitHub Release with a zipped macOS app and cross-compiled CLI archives. See `docs/RELEASING.md`.
