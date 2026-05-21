# Computer Police Release Process

This repository follows the useful parts of CodexBar's release model:

- CI tests Go on Linux, macOS, and Windows.
- CI builds and tests the macOS Swift package on macOS.
- GitHub Releases receive a zipped macOS app bundle plus cross-compiled CLI archives.
- The macOS app is currently ad-hoc signed. Developer ID signing, notarization, and Sparkle appcast updates are the next release-hardening steps.

## CI

CI runs from `.github/workflows/ci.yml` on pushes, pull requests, and manual dispatches.

The Go matrix currently covers:

- `ubuntu-latest` amd64
- `ubuntu-24.04-arm` arm64
- `macos-14` arm64
- `windows-latest` amd64

The Swift app matrix currently covers:

- `macos-14`

Some package-manager e2e subtests skip locally when tools such as Bun, pnpm, uv, Poetry, PDM, pipx, conda, or pixi are not installed.

In CI, proxy e2e tests run with `COMPUTER_POLICE_E2E_STRICT=1`. In strict mode, missing required package-manager executables fail the workflow instead of being reported as skipped tests. This is intentional: a green e2e job must mean the required package-manager coverage actually ran. Conda-family coverage is still marked optional because the proxy does not yet implement Conda channel metadata handling.

## Manual Release

Create a release by pushing a version tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Or run the `Release` workflow manually with a `version` input such as `v0.1.0`.

The release workflow builds:

- `ComputerPolice-vX.Y.Z-macos-universal.zip`
- `ComputerPoliceCLI-vX.Y.Z-macos-arm64.tar.gz`
- `ComputerPoliceCLI-vX.Y.Z-macos-x86_64.tar.gz`
- `ComputerPoliceCLI-vX.Y.Z-linux-arm64.tar.gz`
- `ComputerPoliceCLI-vX.Y.Z-linux-x86_64.tar.gz`
- `ComputerPoliceCLI-vX.Y.Z-windows-arm64.zip`
- `ComputerPoliceCLI-vX.Y.Z-windows-x86_64.zip`
- SHA-256 checksum files

## Local Artifact Builds

CLI archives:

```bash
VERSION=v0.1.0 ./scripts/release/build_cli_artifacts.sh
```

macOS app zip:

```bash
VERSION=v0.1.0 ./scripts/release/package_macos_app.sh
```

Artifacts are written to `dist/`.

## Public Installer

The public install entrypoint is:

```bash
curl -fsSL https://raw.githubusercontent.com/vidocsecurity/computer-police/main/scripts/install.sh | bash
```

To pin a version:

```bash
curl -fsSL https://raw.githubusercontent.com/vidocsecurity/computer-police/main/scripts/install.sh | bash -s -- --version v0.1.0
```

The installer detects the user's OS and CPU architecture, downloads the matching GitHub Release artifact, downloads the release checksum file, verifies SHA-256 before extraction, and installs:

- macOS: `Computer Police.app` plus the bundled `computer-police` CLI, then launches the app so protection can auto-enable.
- Linux: the `computer-police` CLI.
- Windows from Git Bash/MSYS/Cygwin: the `computer-police.exe` CLI.

By default the CLI is installed to `~/.computer-police/bin`. Use `--install-dir <path>` to choose another location, `--no-modify-path` to skip shell profile edits, and `--no-launch` to prevent automatic app launch on macOS.

## Updates and Uninstall

Users can update by rerunning the installer or by running:

```bash
computer-police self update
```

They can uninstall the public install with:

```bash
computer-police self uninstall
```

or:

```bash
curl -fsSL https://raw.githubusercontent.com/vidocsecurity/computer-police/main/scripts/install.sh | bash -s -- --uninstall
```

Uninstall removes the public binary and macOS app bundle, and best-effort disables/stops the local proxy. It intentionally leaves ledger and configuration data in `~/.computer-police` for auditability.

## Installer Smoke Test

The Linux installer flow can be tested end-to-end against locally generated release-shaped artifacts:

```bash
./scripts/test-public-installer.sh
```

## Next: CodexBar-Style Auto-Updates

CodexBar uses Sparkle for direct-download macOS auto-updates. To match that fully, Computer Police still needs:

1. Add Sparkle as a SwiftPM dependency.
2. Add `SUFeedURL` and `SUPublicEDKey` to `Info.plist`.
3. Add a Check for Updates menu action.
4. Sign releases with Developer ID.
5. Notarize app zips with Apple credentials in GitHub Actions.
6. Generate and publish `appcast.xml` with Sparkle signatures.

Required future GitHub secrets will likely be:

- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64`
- `DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD`
- `SPARKLE_PRIVATE_KEY`

Until those exist, the release workflow intentionally publishes ad-hoc signed macOS app zips suitable for internal testing, not final public auto-updating builds.
