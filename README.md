# Package Police

Package Police is a local npm-compatible registry proxy plus a macOS menu-bar frontend.

The proxy records local package install traffic in `~/.package-police/registry-proxy/events.ndjson`, blocks npm package versions that match current-year OSV `MAL-*` advisories, and exposes read-only JSON endpoints on the same loopback listener:

- `GET /api/health`
- `GET /api/events?limit=50`
- `GET /api/stats?window=week`

The macOS app lives in `desktop/PackagePolice`. It acts like a VPN-style control surface for package-install protection: start/stop the proxy, rewrite/repair npm and bun registry config, show status lights, surface weekly install counts, and flag packages that match the bundled mock blocklist.

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

See `desktop/PackagePolice/README.md` for the full click-through checklist.

## CLI

```bash
go build -o ~/.local/bin/package-police ./cmd/package-police
package-police proxy start
package-police proxy events --limit 20
package-police proxy stop
```

Current registry integration supports npm and bun.

Malware advisory data is cached at `~/.package-police/registry-proxy/malware-advisories.json` and refreshed from the OSV npm snapshot every 10 minutes. For local testing, set `PACKAGE_POLICE_OSV_ADVISORY_DIR` to a directory of OSV-format JSON advisories; those advisories are layered onto the cache.
