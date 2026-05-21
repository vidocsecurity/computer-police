.PHONY: dev seed kill-proxy break-registry clean test

dev:
	./scripts/dev.sh

seed:
	./scripts/seed-events.sh

kill-proxy:
	./scripts/kill-proxy.sh

break-registry:
	./scripts/break-registry.sh

clean:
	./scripts/uninstall-dev.sh

test:
	go test ./...
	cd desktop/ComputerPolice && swift test
