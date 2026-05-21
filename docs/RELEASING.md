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
- `macos-13` amd64
- `windows-latest` amd64

The Swift app matrix currently covers:

- `macos-14`
- `macos-13`

Some package-manager e2e subtests skip when tools such as Bun, pnpm, uv, conda, or pixi are not installed on the runner.

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
