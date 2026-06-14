# OCI Registry Publishing & Framework Distribution

> How to publish idp-concept framework and custom modules to OCI registries for versioned, shareable consumption

---

## 1. Overview

> **Current state.** The idp-concept framework is already published to GitHub Container
> Registry at `oras://ghcr.io/javier-godon/idp-concept-framework:v1.0.0`, associated with
> the [Javier-Godon/idp-concept](https://github.com/Javier-Godon/idp-concept) repository.
> The canonical, supported publishing path is `scripts/publish_oci.sh framework <version>`
> (local, reads `credentials/ghcr.env`) and the `.github/workflows/phase-d-publish-framework.yml`
> workflow (CI, on release). See [GHCR_PUBLISHING_GUIDE.md](GHCR_PUBLISHING_GUIDE.md) for the
> concrete GHCR procedure. This document covers the general OCI-registry concepts that apply
> to any registry (Harbor, Artifactory, ACR, Docker Hub, mirrors, air-gapped).

The idp-concept framework can be published to OCI-compatible registries (Docker Registry, OCI Distribution, Artifactory, Harbor, etc.) for:

- **Versioned distribution** — Pin specific framework versions
- **Multi-team adoption** — Share framework across organizations
- **Dependency management** — Reference framework versions in `kcl.mod`
- **CI/CD integration** — Automated publishing on releases
- **Air-gapped environments** — Mirror registries for offline deployment

---

## 2. Prerequisites

### Local Tools

```bash
# KCL >= 0.10.0 with registry support
kcl version

# OCI CLI (optional, for direct registry inspection)
brew install oras  # macOS
apt install oras   # Linux (via https://github.com/oras-project/oras/releases)

# Docker or compatible container registry client
docker version
```

### Registry Access

```bash
# Log in to your registry
docker login myregistry.azurecr.io
# or
oras login myregistry.azurecr.io -u <username>
```

---

## 3. Publishing the Framework

### Prepare kcl.mod for Publishing

Ensure your `framework/kcl.mod` is properly configured:

```toml
[package]
name = "framework"
edition = "v0.10.0"
version = "1.0.0"  # ← Update for each release

[dependencies]
k8s = "1.31.2"     # Pin external dependencies
```

### Option A: Publish from Local Machine

```bash
cd /path/to/idp-concept-framework

# Push to Docker registry
kcl mod push --registry docker://myregistry.azurecr.io

# Push to OCI registry (HTTPS)
kcl mod push --registry oras://myregistry.azurecr.io
```

**Output:**
```
✓ Published framework module
  Registry: oras://myregistry.azurecr.io
  Package:  framework
  Version:  1.0.0
  Digest:   sha256:abcd1234...
```

### Option B: Publish via CI/CD (GitHub Actions)

Create `.github/workflows/publish-framework.yml`:

```yaml
name: Publish Framework to OCI

on:
  push:
    tags:
      - 'framework-v*'
  workflow_dispatch:
    inputs:
      registry:
        description: 'OCI Registry URL (no schema)'
        required: true

env:
  REGISTRY_URL: myregistry.azurecr.io
  FRAMEWORK_VERSION: ${{ github.ref_name }}

jobs:
  publish:
    runs-on: ubuntu-latest
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

      - name: Log in to OCI Registry
        run: |
          echo "${{ secrets.REGISTRY_PASSWORD }}" | \
          docker login -u "${{ secrets.REGISTRY_USERNAME }}" \
          --password-stdin "${{ env.REGISTRY_URL }}"

      - name: Publish Framework
        run: |
          cd framework
          kcl mod push --registry "oras://${{ env.REGISTRY_URL }}"

      - name: Create Release Note
        run: |
          echo "Framework ${{ env.FRAMEWORK_VERSION }} published to ${{ env.REGISTRY_URL }}" \
          >> $GITHUB_STEP_SUMMARY
```

**Trigger:**
```bash
# Publish framework v1.0.0
git tag framework-v1.0.0
git push origin framework-v1.0.0
```

---

## 4. Consuming Published Framework

### In kcl.mod

```toml
[package]
name = "my_project"
edition = "v0.10.0"
version = "1.0.0"

[dependencies]
# Option 1: Local path (development)
framework = { path = "../../framework" }

# Option 2: Published OCI registry (production)
framework = "oras://myregistry.azurecr.io/framework:1.0.0"

# Option 3: Latest version (not recommended for production)
framework = "oras://myregistry.azurecr.io/framework:latest"

# External k8s models from official registry
k8s = "1.31.2"
```

### Validate Registry Reference

```bash
# Verify the dependency resolves
kcl mod info

# Output:
# Package: my_project v1.0.0
# Dependencies:
#   framework:1.0.0 (oras://myregistry.azurecr.io/framework:1.0.0)
#   k8s:1.31.2 (registry)
```

### Update Locked Version

After updating `kcl.mod`, regenerate the lock file:

```bash
# Remove old lock
rm kcl.mod.lock

# KCL will regenerate lock with new dependency resolution
kcl run --dry-run
```

---

## 5. Publishing Custom Modules

### Project-Level Publication

```bash
cd projects/my_project

# Update version in kcl.mod
#   version = "1.5.0"

# Publish
kcl mod push --registry oras://myregistry.azurecr.io
```

### Publishing Multiple Versions

```bash
# Version 1.0.0
cd projects/my_project
# Edit kcl.mod: version = "1.0.0"
kcl mod push --registry oras://myregistry.azurecr.io

# Version 1.1.0
# Edit kcl.mod: version = "1.1.0"
kcl mod push --registry oras://myregistry.azurecr.io

# Reference specific version in consumer
# [dependencies]
# my_project = "oras://myregistry.azurecr.io/my_project:1.1.0"
```

---

## 6. Registry-Specific Setup

### Azure Container Registry (ACR)

```bash
# Log in
az acr login --name myregistry

# Publish
cd framework
kcl mod push --registry oras://myregistry.azurecr.io
```

### Docker Hub

```bash
# Log in
docker login

# Publish (use username prefix)
kcl mod push --registry docker://dockerhub_username/framework

# Reference
# [dependencies]
# framework = "oras://docker.io/dockerhub_username/framework:1.0.0"
```

### Private Harbor Registry

```bash
# Log in
docker login myenterprise-harbor.com

# Publish to project
kcl mod push --registry oras://myenterprise-harbor.com/idp-concept-framework

# Reference
# [dependencies]
# framework = "oras://myenterprise-harbor.com/idp-concept-framework:1.0.0"
```

### Artifactory/JFrog

```bash
# Configure credentials
export ARTIFACTORY_USER=your_user
export ARTIFACTORY_API_KEY=your_key

# Log in
docker login myartifactory.jfrog.io

# Publish
kcl mod push --registry oras://myartifactory.jfrog.io/kcl-modules/framework
```

---

## 7. Versioning Strategy

### Semantic Versioning for Modules

```
MAJOR.MINOR.PATCH

Major: Breaking changes to APIs (module schema incompatibilities)
Minor: Backwards-compatible new features
Patch: Bug fixes, documentation, non-behavioral changes
```

### Version Tagging

```
framework-v0.9.0-alpha    # Alpha pre-release
framework-v0.9.0-beta.1   # Beta pre-release
framework-v1.0.0          # Release
framework-v1.0.1          # Patch
framework-v1.1.0          # Minor feature
framework-v2.0.0          # Major breaking change
```

### kcl.mod Update Process

```toml
# BEFORE: consuming framework v1.0.0
[dependencies]
framework = "oras://myregistry.azurecr.io/framework:1.0.0"

# AFTER: consuming framework v1.1.0 with new features
[dependencies]
framework = "oras://myregistry.azurecr.io/framework:1.1.0"
```

---

## 8. Mirror Registries (Air-Gapped Environments)

### Setup Mirror Registry

```bash
# Create mirror in private network
docker run -d \
  --name registry-mirror \
  -p 5000:5000 \
  -v /data/registry:/var/lib/registry \
  registry:2
```

### Pre-Populate Mirror Before Air Gap

```bash
# From internet-connected host, pull framework
docker pull myregistry.azurecr.io/framework:1.0.0

# Tag for mirror
docker tag myregistry.azurecr.io/framework:1.0.0 \
  localhost:5000/framework:1.0.0

# Push to mirror
docker push localhost:5000/framework:1.0.0

# Export for transport to air-gapped network
docker save localhost:5000/framework:1.0.0 > framework-1.0.0.tar
```

### In Air-Gapped Network

```bash
# Load image into local registry
docker load < framework-1.0.0.tar

# Use via localhost mirror
[dependencies]
framework = "oras://localhost:5000/framework:1.0.0"
```

---

## 9. Security Best Practices

### Signed Images (Cosign)

```bash
# Generate signing key (one time)
cosign generate-key-pair

# Sign published module
cosign sign --key cosign.key \
  myregistry.azurecr.io/framework:1.0.0

# Verify signature (in CI)
cosign verify --key cosign.pub \
  myregistry.azurecr.io/framework:1.0.0
```

### Image Scanning

```bash
# Scan for vulnerabilities before publishing
trivy image myregistry.azurecr.io/framework:1.0.0

# Example output:
# myregistry.azurecr.io/framework:1.0.0 (oras)
# Found 2 vulnerabilities
#   - CVE-2024-1234 (MEDIUM) in kcl@0.10.0
#   - CVE-2024-5678 (LOW) in libssl@1.1.1
```

### Access Control

```bash
# Configure registry authz/authn
# Azure ACR role-based access:
az role assignment create \
  --resource-group my-rg \
  --role acrpush \
  --assignee SERVICE_PRINCIPAL_ID

# Docker Registry credentials in CI:
# - Store credentials in secret vault (GitHub Secrets, GitLab CI Variables)
# - Never commit credentials
# - Use short-lived tokens when possible
```

---

## 10. Verification & Testing

### Verify Published Module

```bash
# Check registry for published versions
oras repo tags myregistry.azurecr.io/framework |  grep "^v"

# Pull and inspect
kcl mod info --registry oras://myregistry.azurecr.io/framework:1.0.0

# List dependencies
kcl mod info --show-deps
```

### Test Consumption in CI

```bash
# Clone consumer project
git clone https://github.com/myorg/consumer-project

# Update to use published framework
cd consumer-project
echo '[dependencies]' >> kcl.mod
echo 'framework = "oras://myregistry.azurecr.io/framework:1.0.0"' >> kcl.mod

# Run tests
kcl test ./...
kcl run factory/render.k -D output=yaml > /tmp/test.yaml
kubeconform /tmp/test.yaml
```

---

## 11. Rollback & Deprecation

### Yanking Versions (Disable Usage)

If a version has critical bugs:

```bash
# Remove from registry (if supported)
oras manifest delete myregistry.azurecr.io/framework:1.0.0

# Or tag as deprecated
# Document in release notes:
# "framework v1.0.0 is yanked due to CVE-XXXX, use v1.0.1"
```

### Migration Path

```
User on v0.9.x → Upgrade to v1.0.1 (or v1.1.0 for new features)

Deprecation timeline:
  v0.9.x - unsupported (recommend v1.0.1)
  v1.0.0 - yanked (use v1.0.1)
  v1.0.1 - supported (LTS)
  v1.1.0-v1.x.y - latest features
```

---

## 12. Monitoring & Metrics

### Track Framework Adoption

```bash
# Metrics on registry (if supported)
# Docker Hub: view download counts per tag
# Harbor: view pull counts and audit logs

# Manual tracking:
# - Log framework mentions in CI/CD runs
# - Track version adoption across teams
# - Gather feedback on published releases
```

### CI/CD Integration Metrics

```bash
# koncept publish metric
koncept metrics | grep -E "publish|framework"

# Output example:
# command,format,duration_ms,timestamp
# publish,oras,2345,2026-06-03T10:30:00Z
```

---

## 13. Troubleshooting

### "authentication required" Error

```bash
# Ensure logged in to registry
docker login myregistry.azurecr.io

# For OCI registries, try with credentials file
oras login myregistry.azurecr.io -u username -p password
```

### "push failed: storage quota exceeded"

- Check registry quota
- Delete old versions if versioning strategy permits
- Upgrade registry storage tier

### Module resolution fails in consumer

```bash
# Check kcl.mod dependency syntax
# Ensure version tag matches published tag
# Verify network access to registry

# Debug:
kcl mod info --debug
kcl mod add framework --registry oras://myregistry.azurecr.io
```

### Cannot delete/modify published version

- Most registries don't allow deleting versions after publish (immutability)
- Use new version number (1.0.1, 1.1.0, etc.)
- Yank versions if critical issues found, but version stays in registry history

---

## 14. Governance & Approval

### Publish Checklist

- [ ] Version number updated in kcl.mod (semantic versioning)
- [ ] kcl mod info shows clean dependency graph
- [ ] All unit tests pass: `kcl test ./...`
- [ ] Golden tests pass: `./scripts/golden.sh check`
- [ ] Documentation updated (CHANGELOG, README)
- [ ] Security scanning complete (no CVEs introduced)
- [ ] Code reviewed (at least one approver)
- [ ] Registry credentials verified

### Release Notes Template

```markdown
# Framework v1.1.0 Release Notes

## New Features
- Added [feature description]
- Enhanced [module name] with [capability]

## Bug Fixes
- Fixed [issue] affecting [scenario]
- Corrected [error] in [component]

## Breaking Changes
- NONE for v1.1.0
- Use v2.0.0 if breaking changes required

## Upgrade Path
- Safe upgrade from v1.0.x to v1.1.0
- Run: kcl mod update framework --registry oras://...

## Dependencies
- KCL >= v0.10.0
- k8s >= 1.31.2
```

---

## 15. Integration with CI/CD

### GitHub Actions Publishing

See section 3 for complete workflow.

### GitLab CI Publishing

```yaml
publish_framework:
  stage: publish
  image: kcl-lang/kcl:v0.10.0
  script:
    - cd framework
    - kcl mod push --registry "oras://$CI_REGISTRY/$CI_PROJECT_NAMESPACE/framework"
  only:
    - tags
  variables:
    CI_REGISTRY_PASSWORD: $CI_JOB_TOKEN
```

### Jenkins Publishing

```groovy
pipeline {
    stages {
        stage('Publish Framework') {
            when {
                tag pattern: "framework-v.*", comparator: "REGEXP"
            }
            steps {
                dir('framework') {
                    sh 'docker login -u $REGISTRY_USER -p $REGISTRY_PASS registry.example.com'
                    sh 'kcl mod push --registry oras://registry.example.com'
                }
            }
        }
    }
}
```

---

## 16. Next Steps

1. **Set up registry** — Choose provider (Azure ACR, Docker Hub, Harbor, etc.)
2. **Publish framework** — Follow section 3 steps
3. **Document versions** — Maintain CHANGELOG and release notes
4. **Integrate CI/CD** — Automate publishing on releases
5. **Monitor adoption** — Track framework usage across teams
6. **Gather feedback** — Improve framework based on user reports

---

## References

- [KCL Module System](../../.github/instructions/kcl-module-system.instructions.md)
- [KCL Registry Documentation](https://www.kcl-lang.io/docs/reference/registry)
- [OCI Image Spec](https://github.com/opencontainers/image-spec)
- [ORAS — OCI Registry As Storage](https://oras.land/)

