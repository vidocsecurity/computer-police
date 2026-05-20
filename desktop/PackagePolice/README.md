# PackagePolice.app

PackagePolice.app is the macOS menu-bar frontend for the local Package Police registry proxy.

It owns the proxy lifecycle like a lightweight VPN:

- The menu-bar shield toggles protection on/off.
- Protection On starts the local proxy and rewrites npm/bun registry config to `http://127.0.0.1:4873/`.
- Protection Off restores package-manager config and stops the proxy.
- The app watches `/api/health` every 5 seconds and restarts the proxy if it crashes.
- Diagnostics split the system into Binary / Proxy / Registry status lights.

## Build

From the repo root:

```bash
./scripts/dev.sh
```

This builds the Go CLI, embeds it in `PackagePolice.app/Contents/Resources/bin/package-police`, builds the Swift app, ad-hoc signs it, installs it to `/Applications/PackagePolice.app`, and opens it.

To only build the app bundle without installing:

```bash
cd desktop/PackagePolice
./Scripts/package_app.sh
open PackagePolice.app
```

## Manual Test Flow

1. Run `./scripts/dev.sh`.
2. Click the menu-bar shield. It should show `Protection: On` with green Binary / Proxy / Registry lights.
3. Run `./scripts/seed-events.sh`. The app should update on the next refresh tick.
4. Run `./scripts/kill-proxy.sh`. The shield should briefly go yellow while the watchdog restarts the proxy.
5. Run `./scripts/break-registry.sh`. The app should show `Protection: Partial` and offer Repair.
6. Run `./scripts/uninstall-dev.sh` when done.

## Mock Blocklist Caveat

The `Vulnerable detected` and `Prevented installs` counts currently use the bundled mock blocklist in `Sources/PackagePoliceCore/Resources/blocklist.json`.

Real install blocking is not wired yet. Until the Go `BlocklistInspector` is implemented, the app labels matched installs as would-have-been-prevented. The Go stats API is already ready to count real blocked events via HTTP `403` responses.
