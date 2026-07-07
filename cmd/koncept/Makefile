BINARY_NAME = koncept
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME = $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')
LDFLAGS = -ldflags "-X github.com/idp-concept/koncept/cmd.version=$(VERSION) -X github.com/idp-concept/koncept/cmd.buildTime=$(BUILD_TIME)"

.PHONY: build build-all build-linux build-darwin build-windows clean test fmt lint install docker checksums verify-checksums test-binaries dist-archives

build:
	go build $(LDFLAGS) -o bin/$(BINARY_NAME) .

build-linux:
	GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o bin/$(BINARY_NAME)-linux-amd64 .
	GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o bin/$(BINARY_NAME)-linux-arm64 .

build-darwin:
	GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o bin/$(BINARY_NAME)-darwin-amd64 .
	GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o bin/$(BINARY_NAME)-darwin-arm64 .

build-windows:
	GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o bin/$(BINARY_NAME)-windows-amd64.exe .

build-all: build-linux build-darwin build-windows
	@echo "✓ All platform binaries built successfully"

checksums: build-all
	cd bin && sha256sum $(BINARY_NAME)-* > SHA256SUMS && cat SHA256SUMS

verify-checksums: checksums
	@echo "Verifying checksums..."
	@cd bin && sha256sum -c SHA256SUMS && echo "✓ All checksums verified"

test-binaries: build-all
	@echo "Testing binaries..."
	@HOST_OS=$$(uname -s | tr '[:upper:]' '[:lower:]'); \
	HOST_ARCH=$$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/'); \
	for binary in bin/$(BINARY_NAME)-*; do \
		case "$$binary" in \
			*.exe) echo "Skipping $$binary (Windows)" ;; \
			*$$HOST_OS-$$HOST_ARCH*) \
				echo "Testing $$binary..."; \
				$$binary --version || exit 1 ;; \
			*) echo "Skipping $$binary (cross-compiled)" ;; \
		esac; \
	done
	@echo "✓ All platform-native binaries passed basic tests"

dist-archives: build-all
	@echo "Creating distribution archives..."
	@mkdir -p dist
	@cd bin && \
	tar czf ../dist/$(BINARY_NAME)-linux-amd64-$(VERSION).tar.gz $(BINARY_NAME)-linux-amd64 && \
	tar czf ../dist/$(BINARY_NAME)-linux-arm64-$(VERSION).tar.gz $(BINARY_NAME)-linux-arm64 && \
	tar czf ../dist/$(BINARY_NAME)-darwin-amd64-$(VERSION).tar.gz $(BINARY_NAME)-darwin-amd64 && \
	tar czf ../dist/$(BINARY_NAME)-darwin-arm64-$(VERSION).tar.gz $(BINARY_NAME)-darwin-arm64 && \
	zip ../dist/$(BINARY_NAME)-windows-amd64-$(VERSION).zip $(BINARY_NAME)-windows-amd64.exe && \
	cp SHA256SUMS ../dist/SHA256SUMS
	@echo "✓ Distribution archives created in dist/"

IMAGE ?= koncept:$(VERSION)

docker:
	docker build -f Dockerfile \
	  --build-arg VERSION=$(VERSION) \
	  --build-arg BUILD_TIME=$(BUILD_TIME) \
	  -t $(IMAGE) ..

clean:
	rm -rf bin/

test:
	go test ./...

fmt:
	go fmt ./...

lint:
	go vet ./...

install: build
	cp bin/$(BINARY_NAME) $(GOPATH)/bin/$(BINARY_NAME)
