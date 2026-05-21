# Public Release Task List

This checklist captures work that should be finished before Computer Police is released publicly. It intentionally excludes features that already exist in the repo by default.

Checked public-installer items reflect the current public installer branch. Linux installer behavior has an end-to-end smoke test; macOS and Windows installer paths are implemented in the script but still need platform-specific smoke tests before public release.

## Already implemented, do not duplicate

- Local registry proxy with event ledger, health, events, stats, and advisory API endpoints.
- Install-time blocking for current-year OSV `MAL-*` advisories from cached npm and PyPI OSV snapshots.
- npm-compatible package-manager coverage for `npm`, `yarn`, `pnpm`, and `bun`.
- PyPI package-manager e2e coverage for `pip`, `uv`, `poetry`, `pdm`, and `pipx`.
- Basic macOS menu-bar app for enabling protection, viewing status, viewing recent events, and installing the bundled CLI.
- GitHub release workflow that publishes cross-platform CLI archives and an ad-hoc-signed macOS app zip.

## P0 - Public release blockers

- [x] Build a one-command public installer entrypoint.
- [x] Detect OS and CPU architecture in the public installer.
- [x] Make the public installer choose the correct GitHub Release artifact.
- [x] Verify release artifact SHA-256 checksums during install.
- [ ] Install the signed and notarized macOS app bundle on macOS.
- [x] Ensure the macOS app install also provides the bundled CLI.
- [x] Install only the CLI on Linux.
- [x] Install only the CLI on Windows.
- [x] Fail clearly when the installer sees an unsupported platform.
- [x] Add a supported update path for public installs.
- [x] Add a supported uninstall path for public installs.

- [ ] Add a first-run onboarding flow after app installation.
- [ ] Add a first-run onboarding flow after CLI-only installation.
- [ ] Detect package managers installed on the user's machine during onboarding.
- [ ] Detect active package-manager configuration files during onboarding.
- [ ] Detect local projects that should be included in onboarding checks.
- [ ] Ask for explicit user consent before running local compromise checks.
- [ ] Explain what local data the onboarding checks inspect.
- [ ] Explain where onboarding results are stored.
- [ ] Add an onboarding step that checks whether the user may already have been affected.
- [ ] Create a bundled set of local compromise-check scripts.
- [ ] Create a bundled set of local compromise-check rules.
- [ ] Scan existing package-manager lockfiles during onboarding.
- [ ] Scan existing package-manager install history during onboarding.
- [ ] Scan the Computer Police ledger during onboarding when it already exists.
- [ ] Scan local package-manager caches for known malicious package versions.
- [ ] Check local projects for recently added suspicious dependencies.
- [ ] Check local projects for suspicious lifecycle scripts.
- [ ] Check local projects for suspicious package-manager configuration changes.
- [ ] Show onboarding compromise-check progress in the macOS app.
- [ ] Show onboarding compromise-check progress in the CLI.
- [ ] Show clear compromise-check results after onboarding.
- [ ] Provide recommended next actions when onboarding finds risky packages.
- [ ] Provide recommended next actions when onboarding finds suspicious lockfile changes.
- [ ] Provide recommended next actions when onboarding finds suspicious lifecycle scripts.
- [ ] Provide a clean "no known compromise found" state after onboarding.
- [ ] Add a machine-readable onboarding report for later support and audits.

- [ ] Add an onboarding hardening step for detected package managers.
- [ ] Ask for explicit user consent before changing package-manager configuration.
- [ ] Back up package-manager configuration before onboarding hardening changes it.
- [ ] Add rollback support for onboarding hardening changes.
- [ ] Configure a minimum package age policy for supported package managers.
- [ ] Let users choose the minimum package age threshold during onboarding.
- [ ] Provide a recommended default minimum package age threshold.
- [ ] Apply minimum package age checks in install-time proxy policy.
- [ ] Add package-manager hardening for lifecycle-script restrictions.
- [ ] Add package-manager hardening for registry pinning.
- [ ] Add package-manager hardening for lockfile integrity checks.
- [ ] Add package-manager hardening for package signature checks where supported.
- [ ] Add package-manager hardening for dependency confusion protection.
- [ ] Add package-manager hardening for unsafe self-update flows.
- [ ] Add package-manager hardening for newly published package versions.
- [ ] Add package-manager hardening for newly created package names.
- [ ] Add package-manager hardening for packages with recent maintainer or ownership changes.
- [ ] Add package-manager hardening for packages with known malicious advisories.
- [ ] Show the exact package-manager settings changed during onboarding.
- [ ] Show the protection level enabled for each detected package manager.
- [ ] Persist onboarding hardening choices in local policy configuration.

- [ ] Add onboarding UI to the macOS app.
- [ ] Add onboarding state to the macOS app model.
- [ ] Add onboarding progress UI for install checks.
- [ ] Add onboarding progress UI for compromise checks.
- [ ] Add onboarding progress UI for hardening changes.
- [ ] Add onboarding completion UI that says protection is working.
- [ ] Show which package managers are protected after onboarding.
- [ ] Show which hardening policies are active after onboarding.
- [ ] Show what Computer Police is doing for the user after onboarding.
- [ ] Add a way to rerun onboarding from the macOS app.
- [ ] Add a way to skip onboarding without losing access to manual setup.
- [ ] Add a way to resume onboarding after interruption.
- [ ] Add CLI output for the same onboarding stages.
- [ ] Add CLI support to rerun onboarding.
- [ ] Add tests for onboarding state transitions.
- [ ] Add tests for onboarding report generation.
- [ ] Add tests for onboarding hardening rollback.

- [ ] Add Developer ID signing for the macOS app.
- [ ] Notarize macOS release zips in GitHub Actions.
- [ ] Add Apple release secrets to GitHub Actions.
- [ ] Add Sparkle as a SwiftPM dependency.
- [ ] Add Sparkle appcast keys to `Info.plist`.
- [ ] Add a Check for Updates action to the macOS app.
- [ ] Generate Sparkle signatures for release artifacts.
- [ ] Publish `appcast.xml` during the release workflow.

- [ ] Implement Conda-family package support for `conda`.
- [ ] Implement Conda-family package support for `mamba`.
- [ ] Implement Conda-family package support for `micromamba`.
- [ ] Implement Conda-family package support for `pixi`.
- [ ] Add Conda channel metadata proxying for conda-forge.
- [ ] Add Conda channel metadata proxying for Anaconda channels.
- [ ] Add Conda channel metadata proxying for custom channels.
- [ ] Add `.condarc` configuration rewriting.
- [ ] Add mamba configuration rewriting.
- [ ] Add micromamba configuration rewriting.
- [ ] Add pixi project and channel configuration rewriting.
- [ ] Support hybrid pixi projects that resolve both Conda and PyPI packages.
- [ ] Promote Conda-family e2e tests from optional to strict CI coverage.
- [ ] Expand PyPI resolver and version-selection fixtures for `pip`.
- [ ] Expand PyPI resolver and version-selection fixtures for `uv`.
- [ ] Expand PyPI resolver and version-selection fixtures for `poetry`.
- [ ] Expand PyPI resolver and version-selection fixtures for `pdm`.
- [ ] Expand PyPI resolver and version-selection fixtures for `pipx`.
- [ ] Add CLI install support for Python registry configuration.
- [ ] Add CLI repair support for Python registry configuration.
- [ ] Add CLI doctor checks for Python registry configuration.

- [ ] Add CLI commands for agent workflow initialization.
- [ ] Add CLI commands for agent readiness checks.
- [ ] Add CLI commands for agent policy status reports.
- [ ] Generate agent instruction files with package-install safety rules.
- [ ] Generate agent instruction files with approved package-manager flows.
- [ ] Detect agent-driven dependency additions.
- [ ] Detect agent-driven lockfile changes.
- [ ] Detect agent-driven lifecycle script additions.
- [ ] Show agent-related warnings in the CLI.
- [ ] Show agent-related warnings in the macOS app.
- [ ] Add app shortcuts to project policy files.
- [ ] Add app shortcuts to ledger views or exports.
- [ ] Add app shortcuts to hardening reports.
- [ ] Add app shortcuts to agent status.
- [ ] Add per-agent trust profile metadata for common local agents.

- [ ] Add `computer-police harden`.
- [ ] Make `computer-police harden` inspect the current repo.
- [ ] Make `computer-police harden` produce a hardening report.
- [ ] Add `computer-police harden --apply`.
- [ ] Make `computer-police harden --apply` perform low-risk mechanical fixes.
- [ ] Add `computer-police harden --policy`.
- [ ] Make `computer-police harden --policy` generate repo policy files for agents.
- [ ] Make `computer-police harden --policy` generate pre-commit policy files.
- [ ] Make `computer-police harden --policy` generate CI policy files.
- [ ] Add `computer-police harden --review-deps`.
- [ ] Make `computer-police harden --review-deps` review lifecycle scripts.
- [ ] Make `computer-police harden --review-deps` review lockfile changes.
- [ ] Make `computer-police harden --review-deps` review new transitive dependency exposure.
- [ ] Identify heavy SDKs with large transitive dependency trees.
- [ ] Identify risky SDKs with large transitive dependency trees.
- [ ] Check whether direct external dependencies are pinned.
- [ ] Generate or enforce npm shrinkwrap for shipped CLI transitive dependencies.
- [ ] Recommend lifecycle-script restrictions for self-update flows.
- [ ] Require review when newly added dependencies introduce lifecycle scripts.
- [ ] Block lockfile changes in pre-commit unless explicitly allowed.
- [ ] Add scheduled GitHub checks for `npm audit`.
- [ ] Add scheduled GitHub checks for npm registry signature verification.
- [ ] Add scheduled GitHub checks for vulnerability-triggered dependency updates.
- [ ] Document 2FA release requirements.

- [ ] Add `computer-police compromise-check`.
- [ ] Make `computer-police compromise-check` run a local-first investigation.
- [ ] Add `computer-police compromise-check --github`.
- [ ] Make `computer-police compromise-check --github` inspect connected GitHub repositories.
- [ ] Add `computer-police compromise-check --org`.
- [ ] Make `computer-police compromise-check --org` inspect organization repositories where permissions allow.
- [ ] Add `computer-police compromise-check --since <date>`.
- [ ] Scan local projects for known malicious packages.
- [ ] Scan local projects for known malicious package versions.
- [ ] Scan local lockfiles for malicious package entries.
- [ ] Scan local install history for malicious package events.
- [ ] Inspect the Computer Police ledger for risky package-install timelines.
- [ ] Check repositories for suspicious dependency additions.
- [ ] Check repositories for suspicious lockfile changes.
- [ ] Check repositories for suspicious GitHub Actions workflow edits.
- [ ] Check repositories for suspicious release changes.
- [ ] Check repositories for suspicious deploy key changes.
- [ ] Check repositories for suspicious secrets usage changes.
- [ ] Produce an incident-response report with affected projects.
- [ ] Produce an incident-response report with suspicious packages.
- [ ] Produce an incident-response report with relevant commits and branches.
- [ ] Produce an incident-response report with potentially affected users or machines.
- [ ] Produce an incident-response report with recommended next actions.

- [ ] Add `computer-police check-package <name>@<version>`.
- [ ] Add `computer-police scan-lockfile`.
- [ ] Add `computer-police scan-ledger`.
- [ ] Add `computer-police watch-osv`.
- [ ] Support live OSV API queries in addition to cached snapshots.
- [ ] Support OSV package URL queries.
- [ ] Support OSV pagination with `next_page_token`.
- [ ] Preserve OSV advisory IDs from query results.
- [ ] Classify OSV advisory IDs including `MAL-*`, `GHSA-*`, `CVE-*`, and `OSV-*`.
- [ ] Map npm lockfile entries into OSV ecosystems and purls.
- [ ] Map pnpm lockfile entries into OSV ecosystems and purls.
- [ ] Map yarn lockfile entries into OSV ecosystems and purls.
- [ ] Map bun lockfile entries into OSV ecosystems and purls.
- [ ] Map Python lockfile entries into OSV ecosystems and purls.
- [ ] Make OSV block-versus-warn behavior policy-controlled.

## P1 - Ecosystem coverage for a credible public release

- [ ] Add RubyGems metadata classification for Ruby support.
- [ ] Add RubyGems download classification for Ruby support.
- [ ] Add `.gemrc` configuration support.
- [ ] Add Bundler configuration support.
- [ ] Add Composer repository proxying for PHP support.
- [ ] Add Packagist proxying for PHP support.
- [ ] Add Composer project configuration support.
- [ ] Add Composer global configuration support.
- [ ] Add Cargo sparse registry support for Rust.
- [ ] Add Cargo index handling for Rust.
- [ ] Add crate download blocking for Rust.
- [ ] Add Go module proxy protocol support.
- [ ] Add `GOPROXY` configuration support.
- [ ] Add Maven repository metadata proxying.
- [ ] Add Maven artifact proxying.
- [ ] Add Gradle configuration support.
- [ ] Add Maven configuration support.
- [ ] Add NuGet v3 feed proxying.
- [ ] Add `nuget.config` support.
- [ ] Add `dotnet restore` coverage.

## P2 - Broader ecosystem expansion

- [ ] Add Scala `sbt` coverage.
- [ ] Add Scala `coursier` coverage.
- [ ] Add Scala `mill` coverage.
- [ ] Add Clojure CLI coverage.
- [ ] Add `leiningen` coverage.
- [ ] Add `boot` coverage.
- [ ] Add Clojars repository coverage.
- [ ] Add `dart pub` coverage.
- [ ] Add `flutter pub` coverage.
- [ ] Add Swift package registry support.
- [ ] Evaluate Git dependency blocking for Swift Package Manager.
- [ ] Add CocoaPods Specs handling.
- [ ] Add CocoaPods source handling.
- [ ] Evaluate Git-aware blocking for Carthage.
- [ ] Add CRAN support for R.
- [ ] Add Bioconductor support for R.
- [ ] Add RSPM support for R.
- [ ] Add `renv` coverage.
- [ ] Add `pak` coverage.
- [ ] Add Julia package server proxy support.
- [ ] Add Julia registry proxy support.

## P3 - Long-tail ecosystem expansion

- [ ] Add Hex package metadata support.
- [ ] Add `mix` coverage.
- [ ] Add `rebar3` coverage.
- [ ] Add Hackage metadata support.
- [ ] Add Stackage metadata support.
- [ ] Add `cabal` coverage.
- [ ] Add `stack` coverage.
- [ ] Add opam repository metadata support.
- [ ] Add opam archive proxying.
- [ ] Add CPAN mirror support.
- [ ] Add `cpan` coverage.
- [ ] Add `cpanm` coverage.
- [ ] Add Carton coverage.
- [ ] Add Carmel coverage.
- [ ] Add LuaRocks manifest support.
- [ ] Add LuaRocks rock download support.
- [ ] Add Conan support.
- [ ] Evaluate vcpkg registry support.
- [ ] Evaluate Git-aware blocking for vcpkg.
- [ ] Add DUB registry proxying.
- [ ] Add Nimble package index support.
- [ ] Evaluate Git-aware blocking for Nimble.
- [ ] Add Zig URL/archive blocking once package-manager conventions are stable enough.

## P0 - Validation and documentation

- [x] Update README with the public installer flow.
- [ ] Update README with supported OSes.
- [x] Update README with supported package managers.
- [ ] Document the security model.
- [ ] Document the privacy model.
- [x] Document the uninstall path.
- [x] Document the update path.
- [ ] Add public release smoke tests for macOS installer flows.
- [x] Add public release smoke tests for Linux installer flows.
- [ ] Add public release smoke tests for Windows installer flows.
- [ ] Add app and CLI version consistency checks across release artifacts.
- [x] Add checksum verification to the documented release process.
- [ ] Add troubleshooting docs for proxy startup failures.
- [ ] Add troubleshooting docs for port conflicts.
- [ ] Add troubleshooting docs for registry config repair.
- [ ] Add troubleshooting docs for advisory sync failures.
- [ ] Add troubleshooting docs for restoring package-manager config.
- [ ] Add privacy review for ledger contents.
- [ ] Add privacy review for local report storage.
- [ ] Add privacy review for GitHub-connected compromise checks.
- [ ] Add privacy review for organization-wide scans.
