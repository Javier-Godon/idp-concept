# GHCR Publishing Guide for idp-concept Framework

> Step-by-step guide for publishing the idp-concept framework to GitHub Container Registry (GHCR) with automated CI/CD integration and rollback procedures.

---

## 1. Executive Summary

This guide provides concrete steps for publishing the idp-concept framework as versioned OCI packages under `ghcr.io/javier-godon/idp-concept` (GitHub Container Registry). Publishing under the repository path keeps the package automatically associated with the [Javier-Godon/idp-concept](https://github.com/Javier-Godon/idp-concept) repository. After publication, external teams can consume the framework via:

```toml
# In kcl.mod of consuming projects:
[dependencies]
framework = "oras://ghcr.io/javier-godon/idp-concept-framework:v1.0.0"
```

**Current Status**: Framework v1.0.0 is **published** to GHCR at `oras://ghcr.io/javier-godon/idp-concept-framework:v1.0.0`. Publishing is automated by `.github/workflows/phase-d-publish-framework.yml` (on GitHub Release) and reproducible locally via `scripts/publish_oci.sh framework <version>`.

---

## 2. Prerequisites

### 2.1 GitHub Authentication for GHCR (credentials come from `./credentials`)

Publishing **never prompts for a token**. The publish tooling reads the GHCR token
from the local, git-ignored `credentials/` folder. You set the token up once:

```bash
# 1. Create a Personal Access Token (PAT) on GitHub (one-time)
# - Visit: https://github.com/settings/tokens/new
# - Select scopes:
#   - write:packages    # Push to GHCR
#   - read:packages     # Pull from GHCR
#   - delete:packages   # Cleanup old versions

# 2. Store it in the git-ignored credentials folder (NEVER committed — see .gitignore)
#    File: credentials/ghcr.env
cat > credentials/ghcr.env << 'EOF'
GHCR_USERNAME=javier-godon
CR_PAT=<your_github_pat_token>
EOF

# 3. Verify the folder is ignored (must print a .gitignore match, and list nothing tracked)
git check-ignore -v credentials/
git ls-files credentials/   # expected: empty
```

> ⚠️ Never paste the token into a shell command, a doc, or a commit. The only place it
> lives is `credentials/ghcr.env`, which is ignored by Git. `scripts/publish_oci.sh`
> reads it with `--password-stdin` and never echoes it.

### 2.1.1 Quick publish (recommended)

```bash
# Authenticates from credentials/ghcr.env and publishes the framework OCI package.
./scripts/publish_oci.sh framework            # version defaults to `git describe --tags`
./scripts/publish_oci.sh framework v1.0.0     # explicit version

# Also available:
./scripts/publish_oci.sh image                # the koncept CLI container image
./scripts/publish_oci.sh all                  # both
```

The manual `oras`/`docker` steps in Section 3 are kept as a reference for what the
script does under the hood; day-to-day publishing should use `scripts/publish_oci.sh`.

### 2.1.2 What gets published (and what does NOT)

| Published artifact | Reference |
|---|---|
| Framework KCL module (OCI) | `oras://ghcr.io/javier-godon/idp-concept-framework:<version>` |
| `koncept` CLI container image | `ghcr.io/javier-godon/idp-concept/koncept:<version>` |
| `koncept` CLI binaries + checksums | GitHub Releases assets |

**Not published:** the `projects/` directory (`video_streaming`, `erp_back`, `pokedex`)
is a set of **reference example usages** of the framework, not a shipped package. The
`crossplane_v2/` cluster prerequisites and curated reference APIs are applied per cluster,
not published as an artifact.


### 2.2 Install ORAS CLI

```bash
# macOS
brew install oras

# Linux (apt)
curl -LO https://github.com/oras-project/oras/releases/download/v1.1.0/oras_1.1.0_linux_amd64.tar.gz
tar xzf oras_1.1.0_linux_amd64.tar.gz
sudo mv oras /usr/local/bin/

# Verify
oras version
# Expected: ORAS 1.1.0 or later
```

### 2.3 Prepare Framework Package

```bash
cd /path/to/idp-concept/framework

# Verify kcl.mod has version = "1.0.0"
grep "^version" kcl.mod
# Expected output: version = "1.0.0"

# Verify all tests passing
kcl test ./...
# Expected: All tests PASS (433/433)

# List framework contents
ls -la | grep -E "kcl.mod|models|templates|builders"
```

---

## 3. Manual Publishing (ORAS CLI — Available Now)

### 3.1 Create OCI Package Tarball

```bash
cd /path/to/idp-concept

# Create a clean archive of framework only (no build artifacts)
mkdir -p /tmp/idp-publish
tar --exclude='.git' \
    --exclude='*.lock' \
    --exclude='output' \
    --exclude='node_modules' \
    --exclude='**/test_to_delete' \
    -czf /tmp/idp-publish/framework-v1.0.0.tar.gz \
    framework/

# Verify archive contents
tar tzf /tmp/idp-publish/framework-v1.0.0.tar.gz | head -20
# Expected: framework/kcl.mod, framework/models/*, framework/templates/*, etc.
```

### 3.2 Upload to GHCR via ORAS

```bash
# Set variables
REGISTRY="ghcr.io"
NAMESPACE="javier-godon/idp-concept"
REPO="framework"
TAG="v1.0.0"
IMAGE="$REGISTRY/$NAMESPACE/$REPO:$TAG"

# Authenticate (if not already done) — token comes from credentials/ghcr.env
set -a; source credentials/ghcr.env; set +a
printf '%s' "$CR_PAT" | oras login ghcr.io -u "${GHCR_USERNAME:-javier-godon}" --password-stdin

# Push framework package to GHCR
oras push "$IMAGE" \
    /tmp/idp-publish/framework-v1.0.0.tar.gz:application/vnd.idp-concept.framework.v1+gzip

# Verify upload
oras ls "$REGISTRY/$NAMESPACE/$REPO"
# Expected: v1.0.0 listed

# Inspect pushed artifacts
oras manifest ls "$REGISTRY/$NAMESPACE/$REPO"
```

### 3.3 Publish Release Notes

```bash
# Create release notes annotation
cat > /tmp/idp-publish/release-notes.txt << 'EOF'
# idp-concept Framework v1.0.0

## Components Included

- **Models**: Project, Tenant, Site, Profile, Stack, Release schemas
- **Templates**: 15+ infrastructure templates (PostgreSQL, Kafka, MongoDB, Redis, etc.)
- **Builders**: Deployment, Service, ConfigMap, Storage, ServiceAccount manifests
- **Procedures**: 9 output formats (YAML, Helm, Helmfile, Kusion, Crossplane, Kustomize, Timoni, ArgoCD, Dry-run)
- **Tests**: 433 unit tests, 5 format golden snapshots, acceptance patterns

## Key Features

- ✅ Single source of truth: KCL configuration → multiple output formats
- ✅ Secure defaults: No hardcoded secrets, pinned versions
- ✅ Production-ready: Governance metadata, dependency orchestration
- ✅ Observable: Dry-run planning with resource footprint
- ✅ Extensible: Template system for custom modules

## Publishing Details

- **Registry**: ghcr.io/javier-godon/idp-concept
- **Package**: framework:v1.0.0
- **Edition**: KCL v0.10.0
- **K8s Support**: v1.31.2
- **Consumption**: oras://ghcr.io/javier-godon/idp-concept-framework:v1.0.0

## Migration from Git Clone

Replace in kcl.mod:

```toml
# OLD: Git clone method
# framework = { path = "../../framework" }

# NEW: GHCR registry method
framework = "oras://ghcr.io/javier-godon/idp-concept-framework:v1.0.0"
```

## Support & Feedback

- GitHub Issues: https://github.com/Javier-Godon/idp-concept/issues
- Documentation: https://github.com/Javier-Godon/idp-concept/blob/main/docs/
- Architecture: See [../platform-engineering/PROJECT_ARCHITECTURE.md](../platform-engineering/PROJECT_ARCHITECTURE.md)

---

Generated: 2026-06-03
Published by: GitHub Copilot Framework Automation
EOF

# Tag the archive with metadata
oras attach "$IMAGE" \
    --artifact-type "application/vnd.idp-concept.release-notes.v1+text" \
    /tmp/idp-publish/release-notes.txt
```

### 3.4 Verify Published Package

```bash
# List all published versions
oras ls "ghcr.io/javier-godon/idp-concept-framework"
# Expected: v1.0.0

# Show manifest
oras manifest fetch "ghcr.io/javier-godon/idp-concept-framework:v1.0.0" | jq .

# Show artifact size
oras describe "ghcr.io/javier-godon/idp-concept-framework:v1.0.0" --verbose

# Test pull access (simulates external team)
oras pull "ghcr.io/javier-godon/idp-concept-framework:v1.0.0" -o /tmp/framework-test
tar tzf /tmp/framework-test/framework-v1.0.0.tar.gz | head -10
```

---

## 4. Update Consuming Projects (Post-Publication)

### 4.1 Update kcl.mod

For any project that was using git clone method:

```toml
# Before (video_streaming/kcl.mod, erp_back/kcl.mod, etc.)
[dependencies]
framework = { path = "../../framework" }

# After
[dependencies]
framework = "oras://ghcr.io/javier-godon/idp-concept-framework:v1.0.0"
```

### 4.2 Test Consuming Project

```bash
# In a test consuming project
cd /tmp/test-project
mkdir -p test_idp && cd test_idp

cat > kcl.mod << 'EOF'
[package]
name = "test_consumer"
edition = "v0.10.0"
version = "0.0.1"

[dependencies]
framework = "oras://ghcr.io/javier-godon/idp-concept-framework:v1.0.0"
k8s = "1.31.2"
EOF

# Create minimal test file
cat > main.k << 'EOF'
import framework.models.project as proj

project = proj.Project {
    name = "test-project"
    version = "0.0.1"
}

instances = [project.instance]
EOF

# Run KCL to verify resolution
kcl run main.k --quiet
# Expected: No errors, GHCR package resolver works
```

---

## 5. CI/CD Integration

Publishing is already automated. `.github/workflows/phase-d-publish-framework.yml` packages
`framework/` and pushes it to GHCR on every GitHub Release (and on manual dispatch). The
workflow below documents that flow; keep it in sync with the committed workflow file.

### 5.1 GitHub Actions Workflow (Reference)

```yaml
# .github/workflows/phase-d-publish-framework.yml (excerpt)
name: Publish Framework to GHCR

on:
  push:
    tags:
      - 'v*.*.*'
    paths:
      - 'framework/**'

env:
  REGISTRY: ghcr.io
  NAMESPACE: javier-godon/idp-concept
  REPO: framework

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install KCL
        env:
          KCL_VERSION: "0.10.0"
        run: |
          set -euo pipefail
          curl -fsSL -o /tmp/kcl.tar.gz \
            "https://github.com/kcl-lang/cli/releases/download/v${KCL_VERSION}/kcl-v${KCL_VERSION}-linux-amd64.tar.gz"
          tar -xzf /tmp/kcl.tar.gz -C /tmp kcl
          sudo install -m 0755 /tmp/kcl /usr/local/bin/kcl
          kcl version
      
      - name: Run tests (pre-publication check)
        run: |
          cd framework
          kcl test ./...
      
      - name: Authenticate GHCR
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | \
            docker login ghcr.io -u javier-godon --password-stdin
      
      - name: Extract version from tag
        run: |
          TAG=${GITHUB_REF#refs/tags/}
          echo "VERSION=$TAG" >> $GITHUB_ENV
      
      - name: Package framework
        run: |
          tar --exclude='.git' \
              --exclude='*.lock' \
              --exclude='test_to_delete' \
              -czf framework-${{ env.VERSION }}.tar.gz \
              framework/
      
      - name: Push to GHCR
        run: |
          IMAGE="${{ env.REGISTRY }}/${{ env.NAMESPACE }}/${{ env.REPO }}:${{ env.VERSION }}"
          oras push "$IMAGE" \
              framework-${{ env.VERSION }}.tar.gz:application/vnd.idp-concept.framework.v1+gzip
      
      - name: Create GitHub Release
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ env.VERSION }}
          release_name: Framework ${{ env.VERSION }}
          body: |
            Published to GHCR: ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/${{ env.REPO }}:${{ env.VERSION }}
          draft: false
          prerelease: ${{ contains(env.VERSION, 'alpha') || contains(env.VERSION, 'beta') }}
```

### 5.2 Semantic Versioning Strategy

```
v1.0.0 = Framework v1, stable KCL v0.10.0, stable Crossplane APIs
v1.0.1 = Bug fix or patch (no breaking changes)
v1.1.0 = New templates or features (backward compatible)
v2.0.0 = Major restructure (when KCL v1.x stabilizes, or major API change)
v1.0.0-alpha.1 = Alpha release for testing
v1.0.0-rc.1 = Release candidate
```

---

## 6. Rollback Procedures

### 6.1 If v1.0.0 Has Issues

```bash
# Option 1: Temporarily remove from registry
oras discover "ghcr.io/javier-godon/idp-concept-framework:v1.0.0" --format json

# Option 2: Communicate issue to consuming teams
# - Create GitHub issue documenting problem
# - Publish v1.0.0-patch.1 or v1.0.1 with fix
# - Guide teams to upgrade

# Option 3: Hard delete (destructive, use cautiously)
# - Via GitHub CLI:
gh release delete v1.0.0 --yes # Removes GitHub release
# - Package remains in GHCR (manual cleanup via web UI or oras CLI)
```

### 6.2 If External Team Has Issues Upgrading

```bash
# Support option: Pin to previous version during transition
# In their kcl.mod:
framework = "oras://ghcr.io/javier-godon/idp-concept-framework:v0.9.9"

# Timeline: Give 2 release cycles (e.g., 1 month) before deprecating old version
# Communication via GitHub Releases page
```

---

## 7. Monitoring & Observability

### 7.1 Track Downloads (GitHub Packages)

```bash
# Via GitHub API (requires authentication)
curl -H "Authorization: token $GITHUB_TOKEN" \
     "https://api.github.com/users/javier-godon/packages?package_type=container" \
     | jq '.[] | select(.name == "idp-concept-framework")' 

# Manual: Visit https://github.com/Javier-Godon?tab=packages
```

### 7.2 Monitor GHCR Storage

- Login to https://ghcr.io
- Navigate to **Packages** → **idp-concept-framework**
- View: version history, pull statistics, storage usage

---

## 8. Security Considerations

### 8.1 Authentication

- ✅ GitHub PAT scoped to `write:packages`, `read:packages`, `delete:packages`
- ✅ GHCR defaults to private pulls requiring authentication
- ✅ Sensitive information (passwords, API keys) never included in framework archive

### 8.2 Image Provenance

```bash
# Optional: Sign images with cosign (if organization requires)
# Requires: https://docs.sigstore.dev/cosign/

# Sign pushed image
cosign sign --key cosign.key ghcr.io/javier-godon/idp-concept-framework:v1.0.0

# Verify signature
cosign verify --key cosign.pub ghcr.io/javier-godon/idp-concept-framework:v1.0.0
```

---

## 9. Next Steps

### Done

1. ✅ Create GitHub PAT for `javier-godon` account
2. ✅ Authenticate locally with GHCR
3. ✅ Package framework v1.0.0
4. ✅ Push to GHCR via ORAS under the repo-associated `idp-concept-framework` path
5. ✅ Verify pull from GHCR works
6. ✅ Automate publishing in `.github/workflows/phase-d-publish-framework.yml`

### Ongoing

7. Update internal consuming projects (video_streaming, erp_back, pokedex) to the pinned OCI reference once KCL `oras://` dependency resolution is fully validated; local `path` remains the working development default.
8. Establish semantic versioning and release cadence (see §5.2).
9. Track adoption across consuming teams.

---

## 10. FAQ

**Q: Can external teams without GHCR access consume the framework?**
A: Only if GHCR access is granted. For air-gapped environments, teams can mirror the package to their private registry using `oras copy`.

**Q: What if GHCR goes down?**
A: Mirror to Harbor or Docker Hub as backup (requires org decision). GHCR has 99.95% SLA.

**Q: How do we handle breaking changes?**
A: Use semantic versioning. v2.0.0 signals breaking changes. Give teams 2-3 release cycles to migrate.

**Q: Can teams use specific historical versions?**
A: Yes. Reference framework = "oras://ghcr.io/javier-godon/idp-concept-framework:v1.0.0" in kcl.mod to pin to specific version.

**Q: How do external teams get bugfixes?**
A: Publish v1.0.1, v1.0.2, etc. Teams explicitly update kcl.mod to consume patch versions.

---

## References

- ORAS CLI: https://oras.land/
- OCI Image Spec: https://github.com/opencontainers/image-spec
- GHCR Documentation: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
- KCL Module System: [../../.github/instructions/kcl-module-system.instructions.md](../../.github/instructions/kcl-module-system.instructions.md)
- Framework Architecture: [../platform-engineering/PROJECT_ARCHITECTURE.md](../platform-engineering/PROJECT_ARCHITECTURE.md)

---

**Framework Version**: v1.0.0
**Status**: Published to `oras://ghcr.io/javier-godon/idp-concept-framework:v1.0.0`; CI publishing via `.github/workflows/phase-d-publish-framework.yml`

