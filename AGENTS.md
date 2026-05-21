# AGENTS.md

## Cursor Cloud specific instructions

This is a Go 1.24 monorepo with zero external dependencies. The macOS Swift desktop app (`desktop/ComputerPolice/`) cannot be built or tested on Linux.

### Running tests

```bash
export PATH=/usr/local/go/bin:/home/ubuntu/.bun/bin:/home/ubuntu/.local/bin:/usr/local/bin:$PATH
go test ./...
```

All Go tests (unit + e2e) run via `go test ./...`. E2e tests gracefully skip when a package manager is not installed unless `COMPUTER_POLICE_E2E_STRICT=1` is set.

### Lint

```bash
go vet ./...
```

There is no additional linter configured (no golangci-lint, no staticcheck).

### Build

```bash
go build -o ./computer-police ./cmd/computer-police
```

### Running the proxy (development mode)

```bash
export COMPUTER_POLICE_OSV_ADVISORY_DIR=./internal/proxy/testdata/osv
./computer-police proxy start
```

This starts the proxy on `127.0.0.1:4873` using local test OSV advisories (avoids a large download from Google Cloud Storage). The proxy exposes:
- `GET /api/health`
- `GET /api/events?limit=50`
- `GET /api/stats?window=week`
- `GET /api/advisories`

Stop with `./computer-police proxy stop`.

### Key gotchas

- Poetry, PDM, and pipx must be installed system-wide (`sudo pip install --break-system-packages`) so they work in e2e tests that override HOME.
- The `bun` binary lives at `/home/ubuntu/.bun/bin/bun`; make sure it's on PATH.
- The Go toolchain wrapper at `/usr/bin/go` may be a thin shim that tries to download; always use `/usr/local/go/bin/go` directly or ensure PATH has `/usr/local/go/bin` first.
- Conda/mamba/pixi e2e tests are skipped (not yet implemented).
