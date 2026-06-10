# CLI Distribution Guide

> How to obtain, verify, and use prebuilt `koncept` CLI binaries across platforms

**Status**: Production-ready
**Platforms**: Linux (amd64), macOS (amd64, arm64), Windows (amd64)
**Container Image**: Available (Alpine base)

---

## Quick Start

### Option 1: Prebuilt Binary (Recommended)

```bash
# Download latest release
curl -L https://github.com/Javier-Godon/idp-concept/releases/latest/download/koncept-linux-amd64 -o koncept
chmod +x koncept

# Verify checksum
curl -L https://github.com/Javier-Godon/idp-concept/releases/latest/download/CHECKSUMS -o CHECKSUMS
sha256sum --check CHECKSUMS

# Use it
./koncept render yaml
```

### Option 2: Container Image

```bash
docker run ghcr.io/javier-godon/idp-concept/koncept:latest \
  --factory /workspace/factory \
  render helmfile
```

### Option 3: Install from Source

```bash
git clone https://github.com/Javier-Godon/idp-concept
cd idp-concept/cmd/koncept
go build -o koncept .
./koncept render yaml
```

---

## Platform-Specific Installation

### Linux (amd64)

```bash
wget https://github.com/Javier-Godon/idp-concept/releases/latest/download/koncept-linux-amd64
chmod +x koncept-linux-amd64
sudo mv koncept-linux-amd64 /usr/local/bin/koncept
koncept --version
```

### macOS (Intel)

```bash
curl -L https://github.com/Javier-Godon/idp-concept/releases/latest/download/koncept-darwin-amd64 -o koncept
chmod +x koncept
sudo mv koncept /usr/local/bin/koncept
koncept --version
```

### macOS (Apple Silicon / M1/M2/M3)

```bash
curl -L https://github.com/Javier-Godon/idp-concept/releases/latest/download/koncept-darwin-arm64 -o koncept
chmod +x koncept
sudo mv koncept /usr/local/bin/koncept
koncept --version
```

### Windows

```powershell
# Download the binary
$url = "https://github.com/Javier-Godon/idp-concept/releases/latest/download/koncept-windows-amd64.exe"
Invoke-WebRequest -Uri $url -OutFile koncept.exe

# Add to PATH or use full path
.\koncept.exe render yaml
```

---

## Checksum Verification

All releases include `CHECKSUMS` files signed with GPG. To verify:

```bash
# Download binary and checksums
curl -L https://github.com/Javier-Godon/idp-concept/releases/latest/download/koncept-linux-amd64 -o koncept-linux-amd64
curl -L https://github.com/Javier-Godon/idp-concept/releases/latest/download/CHECKSUMS -o CHECKSUMS

# Verify SHA256 (all platforms)
sha256sum --check CHECKSUMS

# Expected output:
# koncept-linux-amd64: OK
```

### On macOS

```bash
sha256sum --check CHECKSUMS
# or
shasum -a 256 -c CHECKSUMS
```

### On Windows (PowerShell)

```powershell
$hash = (Get-FileHash koncept-windows-amd64.exe -Algorithm SHA256).Hash
Get-Content CHECKSUMS | Select-String "koncept-windows-amd64.exe"
# Compare manually or use:
$expectedHash = (Get-Content CHECKSUMS | Select-String "koncept-windows-amd64.exe").Line.Split()[0]
$hash -eq $expectedHash
```

---

## Container Image Usage

### Prerequisites

- Docker or Podman
- kubectl (optional, for applying output)

### Basic Usage

```bash
# Render YAML from mounted factory directory
docker run -v /path/to/factory:/workspace ghcr.io/javier-godon/idp-concept/koncept:latest \
  --factory /workspace \
  render yaml

# With custom output directory
docker run \
  -v /path/to/factory:/workspace \
  -v /path/to/output:/output \
  ghcr.io/javier-godon/idp-concept/koncept:latest \
  --factory /workspace \
  --output /output \
  render helmfile
```

### In CI/CD (Example: GitHub Actions)

```yaml
- name: Render with koncept
  uses: docker://ghcr.io/javier-godon/idp-concept/koncept:latest
  with:
    args: >
      --factory projects/erp_back/pre_releases/manifests/dev/factory
      render yaml
```

### Image Tags

- `ghcr.io/javier-godon/idp-concept/koncept:latest` — Most recent release
- `ghcr.io/javier-godon/idp-concept/koncept:v1.0.0` — Specific release version
- `ghcr.io/javier-godon/idp-concept/koncept:main` — Built from main branch (development)

### Building & Publishing the Image (maintainers)

Publishing reads its GHCR token from the local, git-ignored `credentials/` folder —
**you are never prompted for a token and must never pass one on the command line**.

```bash
# One-time: create credentials/ghcr.env (git-ignored — see .gitignore)
#   GHCR_USERNAME=javier-godon
#   CR_PAT=<github_pat_with_write:packages>

# Build + push the CLI container image (version defaults to `git describe --tags`)
./scripts/publish_oci.sh image            # ghcr.io/javier-godon/idp-concept/koncept:<version> + :latest
./scripts/publish_oci.sh image v1.0.1     # explicit version
```

In CI the same image is published automatically on `v*` tags by
`.github/workflows/release.yml` using the workflow's `GITHUB_TOKEN` (no `credentials/`
folder is involved on CI — that folder is for local maintainer publishing only).

---

## What This Project Publishes

This repository publishes **two consumable artifacts** to
`https://github.com/Javier-Godon/idp-concept` / `ghcr.io/javier-godon`:

| Artifact | Reference | Purpose |
|---|---|---|
| `koncept` CLI binaries + checksums | GitHub Releases assets | Installable cross-platform CLI |
| `koncept` CLI container image | `ghcr.io/javier-godon/idp-concept/koncept` | Pinned CI/runtime image (kcl bundled) |
| Framework KCL module (OCI) | `oras://ghcr.io/javier-godon/idp-concept/framework` | The reusable `framework/` package — see [GHCR_PUBLISHING_GUIDE.md](GHCR_PUBLISHING_GUIDE.md) |

The `projects/` directory (`video_streaming`, `erp_back`, `pokedex`) is **not** a
published artifact. Those are **reference example usages** of the framework that
demonstrate the recommended project layout and templates. Likewise the hand-authored
`crossplane_v2/` cluster prerequisites and reference APIs are applied per-cluster, not
published as a package.

---



The `koncept` CLI bundles a pinned KCL toolchain (and the kcl-go SDK) to ensure reproducible renders across all platforms and environments.

### Verify The Bundled KCL Toolchain

```bash
# doctor reports the koncept build and the KCL CLI it can find
koncept doctor
# e.g. "KCL CLI found: /usr/local/bin/kcl (kcl version 0.11.3)"
```

### Update KCL (If Needed)

The container image pins the KCL CLI via the `KCL_VERSION` build arg in
`cmd/koncept/Dockerfile`, and the render engine is pinned through the `kcl-go`
dependency in `cmd/koncept/go.mod`. To change the version:

```bash
# 1. Bump the kcl-go SDK used by the render engine
cd cmd/koncept
go get github.com/kcl-lang/kcl-go@v0.11.3
go mod tidy

# 2. Bump the bundled CLI in the image (cmd/koncept/Dockerfile)
#    ARG KCL_VERSION=0.11.3

# 3. Rebuild
make build
```

---

## Installation Verification

After installing, verify the CLI works:

```bash
# Check version
koncept --version

# Check help
koncept --help

# Quick test (if in a factory directory)
koncept dry-run
```

Expected output:
```
[DryRun] Generating dependency-aware preview plan...
✅ Dry-run plan written to output/dry_run_plan.yaml
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Render with Koncept

on:
  push:
    paths:
      - 'projects/**'
      - 'framework/**'

jobs:
  render:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Render YAML
        run: |
          # Download and verify CLI
          curl -L https://github.com/Javier-Godon/idp-concept/releases/latest/download/koncept-linux-amd64 \
            -o /use/local/bin/koncept
          chmod +x /usr/local/bin/koncept
          sha256sum --check CHECKSUMS
          
          # Render factory
          koncept --factory projects/erp_back/pre_releases/manifests/dev/factory \
            render yaml argocd helmfile crossplane
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: rendered-manifests
          path: output/
```

### GitLab CI Example

```yaml
render-manifests:
  image: ghcr.io/javier-godon/idp-concept/koncept:latest
  script:
    - koncept --factory projects/erp_back/releases/v1_0_0_production/factory
               render yaml helmfile crossplane
  artifacts:
    paths:
      - output/
    expire_in: 1 week
```

---

## Troubleshooting

### Issue: "command not found: koncept"

**Solution**: Ensure the binary is in your PATH:
```bash
# Option 1: Add to PATH
export PATH="/path/to/koncept:$PATH"

# Option 2: Use full path
/path/to/koncept render yaml

# Option 3: Move to standard location
sudo mv koncept /usr/local/bin/
```

### Issue: "checksum verification failed"

**Solution**: Verify you downloaded both the binary AND checksums file:
```bash
# Redownload both
curl -L https://github.com/Javier-Godon/idp-concept/releases/latest/download/koncept-linux-amd64 -o koncept-linux-amd64
curl -L https://github.com/Javier-Godon/idp-concept/releases/latest/download/CHECKSUMS -o CHECKSUMS

# Try verification again
sha256sum --check CHECKSUMS
```

### Issue: "KCL version mismatch"

**Solution**: Ensure you're using the prebuilt binary (includes pinned KCL):
```bash
# NOT: apt-get install kcl  (this installs unrelated version)

# YES: Use the prebuilt koncept binary
./koncept --version
```

### Issue: Container can't find factory

**Solution**: Ensure the mount path matches:
```bash
# Run FROM the repository root
docker run -v $(pwd):/workspace \
  ghcr.io/javier-godon/idp-concept/koncept:latest \
  --factory /workspace/projects/erp_back/pre_releases/manifests/dev/factory \
  render yaml
```

---

## Release Process

New versions are published automatically when Git tags are created:

```bash
git tag v1.0.1
git push origin v1.0.1

# Automated CI/CD will:
# 1. Build cross-platform binaries
# 2. Generate checksums
# 3. Create GitHub release with assets
# 4. Push container image to registry
```

---

## Security Considerations

1. **Always verify checksums** before running downloaded binaries
2. **Use specific version tags**, not `latest`, in production
3. **Container images are scanned** for vulnerabilities on each release
4. **Pinned dependencies** (Go, KCL, Kubernetes) prevent supply-chain surprises

---

## See Also

- **Quick Start**: [../developer/DEVELOPER_QUICKSTART.md](../developer/DEVELOPER_QUICKSTART.md)
- **API Reference**: [../platform-engineering/FRAMEWORK_SCHEMAS.md](../platform-engineering/FRAMEWORK_SCHEMAS.md)
- **Release Notes**: GitHub Releases page

---

**Last Updated**: June 2026
**Next Review**: When new platforms or architectures are added

