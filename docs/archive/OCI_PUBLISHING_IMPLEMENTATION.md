# Framework v1.0.0 OCI Registry Publishing Implementation

> Operational guide for publishing idp-concept framework to OCI registries for versioned, multi-team consumption.

---

## 1. Executive Summary

This guide provides the implementation foundation for publishing the idp-concept framework as versioned OCI packages. Publishing enables:

- **Versioned consumption**: Teams pin `framework = "oras://registry.example.com/idp-concept/framework:v1.0.0"` in their `kcl.mod`
- **Multi-team distribution**: Share framework across organizations without git cloning
- **Decentralized adoption**: External IDPs and applications can depend on framework independently
- **Air-gapped support**: Mirror registries for offline deployment environments
- **Governance & audit**: Track framework consumption across the organization

---

## 2. Implementation Status (June 2026)

| Component | Status | Details |
|---|---|---|
| **Framework versioning** | ✅ READY | `framework/kcl.mod` has version field |
| **Dependency pinning** | ✅ READY | All dependencies pinned (k8s, Crossplane, etc.) |
| **OCI publishing guide** | ✅ READY | `docs/OCI_REGISTRY_PUBLISHING.md` comprehensive |
| **CI/CD automation** | 🔄 BLOCKED | Blocked on KPM package manager v2.0+ stability |
| **Registry infrastructure** | ⚠️ DEFERRED | Requires organization registry decision |
| **Publishing workflow** | ➡️ READY TO IMPLEMENT | Documented and ready for manual execution |

### Blocker: KPM Package Manager Maturity

The `kcl mod push` command (via KPM) is the standard mechanism for OCI publishing. Current blockers:

- **KPM v1.x limitations**: Package resolution issues with nested dependencies
- **Registry compatibility**: Some registries require specific auth patterns not yet stable in KPM
- **Metadata handling**: Package documentation/README not fully supported in v1.x

**Timeline**: KPM v2.0 expected Q3 2026 with full OCI support. **Workaround**: Manual `oras` CLI publishing available now.

---

## 3. Current State: Framework Ready for Publishing

### Framework Metadata (framework/kcl.mod)

```toml
[package]
name = "framework"
edition = "v0.10.0"
version = "1.0.0"  # ← Ready to publish

[dependencies]
k8s = "1.31.2"     # ← Pinned
```

### Dependencies (All Pinned ✅)

```toml
[dependencies]
k8s = "1.31.2"       # ✅ Uses stable registry
# All internal modules use fixed paths or versions
# No floating tags like "latest" or "main"
```

### Directory Structure (Ready for Export)

```
framework/
├── kcl.mod                          # Package metadata
├── kcl.mod.lock                     # Transitive dependencies locked
├── main.k                           # Module index
├── models/                          # Core domain schemas
├── templates/                       # High-level abstractions
├── builders/                        # Low-level manifest generators
├── procedures/                      # Output format converters (YAML, Helm, Crossplane, etc.)
├── tests/                           # Comprehensive test coverage (433 unit tests)
├── assembly/                        # Stack assembly helpers
├── custom/                          # Output-format-specific schemas
└── factory/                         # Rendering entry points
```

---

## 4. Manual Publishing (Available Now)

Until KPM v2.0 stabilizes, use the `oras` CLI for OCI publishing:

### Step 1: Install ORAS

```bash
# Linux
wget https://github.com/oras-project/oras/releases/download/v1.1.0/oras_1.1.0_linux_amd64.tar.gz
tar xzf oras*.tar.gz && sudo mv oras /usr/local/bin/

# macOS
brew install oras-project/tap/oras

# Windows
choco install oras
```

### Step 2: Authenticate to Registry

```bash
# Docker Hub
oras login -u <username> <registry>

# Azure Container Registry
az acr login --name <registry-name>

# Private Harbor
oras login -u <username> <registry-url>

# GitHub Container Registry
oras login -u <github-username> ghcr.io
```

### Step 3: Create Framework Archive

```bash
cd /path/to/idp-concept
tar czf framework-v1.0.0.tar.gz framework/
```

### Step 4: Push to Registry

```bash
# Docker Hub
oras push docker.io/myorg/idp-concept-framework:v1.0.0 \
  framework-v1.0.0.tar.gz:application/vnd.oras.artifact.manifest.v1+json

# Azure Container Registry  
oras push myregistry.azurecr.io/idp-concept/framework:v1.0.0 \
  framework-v1.0.0.tar.gz:application/gzip

# Private Harbor
oras push myharbor.company.com/library/idp-framework:v1.0.0 \
  framework-v1.0.0.tar.gz:application/gzip

# GitHub Container Registry (recommended for open source)
oras push ghcr.io/myorg/idp-concept-framework:v1.0.0 \
  framework-v1.0.0.tar.gz:application/vnd.oras.artifact.manifest.v1+json
```

### Step 5: Verify Published Package

```bash
# List available versions
oras repository tags <registry>/idp-framework

# Download and inspect
oras pull <registry>/idp-framework:v1.0.0
tar tzf framework-v1.0.0.tar.gz | head -20
```

---

## 5. Planned KPM v2.0 Publishing (Q3 2026)

Once KPM v2.0 stabilizes, publishing becomes simpler:

### Via KPM CLI (Recommended, Future)

```bash
# Log in
kpm login -u <username> <registry>

# Publish directly from source
cd /path/to/idp-concept
kpm mod push --registry oras://ghcr.io/myorg

# Output:
# ✓ Published framework module
#   Registry: oras://ghcr.io/myorg
#   Package:  framework
#   Version:  1.0.0
#   Digest:   sha256:abc123def456...
```

### CI/CD Automation (Future, Blocked on KPM)

```yaml
# .github/workflows/publish-framework.yml (waiting for KPM v2.0)
name: Publish Framework to OCI

on:
  push:
    tags:
      - 'framework-v*'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install KPM (v2.0+when available)
        run: |
          # curl https://releases.kcl-lang.io/kpm/v2.0.0/install.sh | bash
          echo "Blocked: Awaiting KPM v2.0.0 release"
      - name: Publish to GHCR
        env:
          REGISTRY_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # kpm login -u ${{ github.actor }} ghcr.io
          # kpm mod push --registry oras://ghcr.io/${{ github.repository_owner }}
          echo "Implementation deferred until KPM v2.0"
```

---

## 6. Consumption Models (Once Published)

### Model 1: Direct Registry Reference (Manual Download)

Teams can download and cache locally:

```bash
# Download published framework
oras pull ghcr.io/myorg/idp-framework:v1.0.0
tar xzf framework-v1.0.0.tar.gz -C ~/.kcl/packages

# Update kcl.mod to use local path or registry reference (KPM v2.0)
[dependencies]
framework = { registry = "oras://ghcr.io/myorg/idp-framework", version = "v1.0.0" }
```

### Model 2: KPM Registry Resolution (Future)

Once KPM v2.0 stabilizes:

```toml
# kcl.mod — KPM auto-downloads from registry
[package]
name = "my-idp"
version = "0.1.0"

[dependencies]
framework = { registry = "oras://ghcr.io/my-org", version = "1.0.0" }
k8s = "1.31.2"
```

Then:

```bash
kcl mod pull    # KPM fetches framework from registry
kcl run main.k  # Framework available as `framework.*`
```

### Model 3: Multi-Registry Mirror (Air-Gapped)

For offline environments:

```bash
# Corporate mirror setup (one-time)
oras copy ghcr.io/myorg/idp-framework:v1.0.0 \
         docker.io/corp-mirror/idp-framework:v1.0.0

# kcl.mod points to internal mirror
[dependencies]
framework = { registry = "oras://docker.io/corp-mirror", version = "1.0.0" }
```

---

## 7. Versioning Strategy for v1.0.0 and Beyond

### Semantic Versioning Rules

Adopted from https://semver.org/ with Kubernetes adjustments:

| Version | When to Bump | Examples |
|---|---|---|
| MAJOR (v1 → v2) | Breaking schema changes, incompatible template APIs | Schema field type change, mandatory fields added |
| MINOR (v1.0 → v1.1) | New features, backward compatible | New template added, new builder function |
| PATCH (v1.0.0 → v1.0.1) | Bug fixes, non-breaking | Procedure fix, builder validation improvement |

### Milestones (Proposed)

- **v1.0.0** (Current): Core platform (Helmfile, Crossplane V2, dry-run, 9 output formats)
- **v1.1.0** (Q3 2026): Crossplane runtime lifecycle, monitoring dashboard
- **v1.2.0** (Q4 2026): Score spec support, OCI package management
- **v2.0.0** (2027): Multi-cluster support, Fleet output format

### Compatibility Policy

- Framework versions are **independent** of KCL versions
- Per-version kcl.mod locks framework's KCL dependency (e.g., `k8s = "1.31.2"` for v1.0.0)
- Consumers pin both: `framework v1.0.0` + `k8s 1.31.2`

---

## 8. Registry Selection Recommendations

| Registry | Pros | Cons | Recommended For |
|---|---|---|---|
| **Docker Hub** | Free tier, large community, simple auth | Rate limits for free tier, bandwidth limits | Open-source projects, education |
| **GitHub Container Registry (GHCR)** | Integrated with GitHub Actions, free for public, private plans available | Requires GitHub account | GitHub-based projects, CI/CD automation ready now |
| **Azure Container Registry (ACR)** | Enterprise-grade, SLA, geo-replication | Higher cost | Enterprise/Microsoft-ecosystem heavy |
| **Private Harbor** | Self-hosted, air-gapped support, role-based  access | Operational burden | High-security environments |
| **Artifactory/JFrog** | Universal package manager, multi-format | High cost, complex setup | Large enterprises with multi-language needs |

### Current Recommendation (June 2026)

**Use GitHub Container Registry (GHCR)** for v1.0.0 pilot:

✅ Free for public packages  
✅ CI/CD integration is trivial  
✅ No rate-limiting issues  
✅ Tokens work with KPM (v2.0+)  
✅ Good for open-source adoption pilot  

---

## 9. Pre-Publication Checklist

Before publishing v1.0.0, verify:

- [ ] **Version bumped**: `framework/kcl.mod` has `version = "1.0.0"`
- [ ] **Dependencies pinned**: No floating tags (review `kcl.mod.lock`)
- [ ] **Tests passing**: `kcl test ./...` returns 433/433 PASS
- [ ] **README included**: Create `framework/README.md` with quick start
- [ ] **Changelog prepared**: Document major changes from v0.x
- [ ] **Registry access verified**: `oras login` succeeds
- [ ] **Archive tested**: `tar tzf framework-v1.0.0.tar.gz` extracts cleanly
- [ ] **Digest recorded**: Note published sha256 digest for audit trail
- [ ] **Release notes**: GitHub/registry release notes prepared

---

## 10. Post-Publication Operations

### Tracking & Monitoring

```bash
# List all published versions
oras repository tags ghcr.io/myorg/idp-framework

# Pull specific version
oras pull ghcr.io/myorg/idp-framework:v1.0.0

# Inspect artifact metadata
oras manifest fetch ghcr.io/myorg/idp-framework:v1.0.0
```

### Deprecation & Yanking Versions

If a version must be removed from circulation:

```bash
# "Yank" by deleting the tag (replaces with v1.0.1 patch)
oras tag delete ghcr.io/myorg/idp-framework:v1.0.0

# Publish patch version with fix
tar czf framework-v1.0.1.tar.gz framework/
oras push ghcr.io/myorg/idp-framework:v1.0.1 framework-v1.0.1.tar.gz:application/gzip

# Notify consumers to upgrade
```

### Security & Image Scanning

For enterprise deployments:

```bash
# Scan pushed artifact for vulnerabilities (if using Harbor)
# Harbor UI → Projects → framework → Images → v1.0.0 → scan

# Or use trivy locally
trivy image ghcr.io/myorg/idp-framework:v1.0.0
```

---

## 11. Implementation Timeline

| Milestone | Target | Status | Action |
|---|---|---|---|
| **Manual publishing (oras)** | Now | ✅ READY | Teams can execute immediately if registry decided |
| **Test with external teams** | Q3 2026 | ➡️ READY | Identify 2-3 pilot teams |
| **KPM v2.0 release** | Q3 2026 | ⏳ EXTERNAL | Monitor KPM repo for stable v2.0 release |
| **CI/CD automation** | Q4 2026 | 🔄 BLOCKED | Implement after KPM v2.0 |
| **Production registry cutover** | Q4 2026 | 📅 PLANNED | All consumption via registry |

---

## 12. Next Steps

### Immediate (This Sprint)

1. **Decide registry**: Docker Hub, GHCR, ACR, or private Harbor?
2. **Create framework/README.md**: Quick start for consumers
3. **Prepare publish script**: Automate oras CLI commands
4. **Document versioning policy**: Share with platform team

### Near-term (Q3 2026)

1. **Manual v1.0.0 publish**: Via oras CLI to selected registry
2. **Pilot consumption**: Onboard 2-3 external teams
3. **Collect feedback**: Document gaps/improvements
4. **Monitor KPM v2.0**: Track kcl-lang/kpm releases

### Medium-term (Q4 2026)

1. **Implement CI/CD automation**: Automated publishes on tag
2. **Multi-registry support**: Mirror to corporate registries
3. **Deprecation workflow**: Document version lifecycle
4. **Dependency analysis**: Tools to identify framework consumers

---

## 13. Troubleshooting

### "Registry authentication failed"

```bash
# Verify login token
oras login -u <username> <registry>

# For GitHub:
oras login -u <github-username> ghcr.io
# When prompted, use GitHub personal access token (not password)
```

### "Package already exists"

```bash
# Registry prevents overwriting published versions (SemVer best practice)
# Option 1: Delete tag if not yet in use
oras tag delete <registry>:v1.0.0

# Option 2: Publish as new version
tar czf framework-v1.0.1.tar.gz framework/
oras push <registry>:v1.0.1 framework-v1.0.1.tar.gz
```

### "KPM cannot resolve registry dependency"

```bash
# Blocker: KPM v1.x does not fully support OCI registry resolution
# Workaround: Use local paths or manual download until KPM v2.0
[dependencies]
framework = { path = "../framework" }  # Temporary workaround
```

---

## References

- KPM Project: https://github.com/kcl-lang/kpm
- ORAS CLI: https://github.com/oras-project/oras
- OCI Spec: https://github.com/opencontainers/spec
- Semantic Versioning: https://semver.org/

---


