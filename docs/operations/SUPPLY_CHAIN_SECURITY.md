# Supply Chain Security for idp-concept Releases

> Supply-chain integrity for the `koncept` CLI and framework artifacts, using industry standards: SLSA provenance, SBOM (CycloneDX), and cosign signing.

---

## Overview

As of 2026-06-07, the `.github/workflows/release.yml` now includes:

### 1. **SLSA v1.0 Provenance** (supply-chain levels for software artifacts)

- Generated automatically for every tagged release via `slsa-github-generator`
- Proves the artifact was built from the tagged commit, not injected later
- File: `koncept.provenance.json` on GitHub Release

### 2. **Software Bill of Materials (SBOM)** using Syft

- Scans each binary for dependencies (transitive), licenses, and known vulnerabilities
- Format: **CycloneDX XML** (industry standard, integrates with Grype/Snyk/etc.)
- Files: `koncept-<platform>.sbom.xml` on GitHub Release
- Usage: `syft --file koncept.sbom.xml` or import into SIEM/scanning tools

### 3. **Code Signing** via Cosign

- Each binary signed using Sigstore keyless signing (OIDC + Fulcio)
- No manual key management; GitHub OIDC token is the identity
- Files: `koncept-<platform>.bundle` (signature + cert chain)
- Verification: `cosign verify-blob --bundle koncept.bundle --public-key=<key> binary`

---

## What This Means for Adopters

### For Teams Installing the CLI

```bash
# Download and verify checksum (existing)
curl -L -O https://github.com/Javier-Godon/idp-concept/releases/download/v1.0.0/koncept-linux-amd64
curl -L -O https://github.com/Javier-Godon/idp-concept/releases/download/v1.0.0/SHA256SUMS
sha256sum --check SHA256SUMS

# NEW: Verify cryptographic signature (Sigstore keyless)
curl -L -O https://github.com/Javier-Godon/idp-concept/releases/download/v1.0.0/koncept-linux-amd64.bundle
cosign verify-blob-experimental \
  --bundle koncept-linux-amd64.bundle \
  --certificate-github-workflow-repository Javier-Godon/idp-concept \
  --certificate-github-workflow-trigger push \
  koncept-linux-amd64

# NEW: Review SBOM for known vulnerabilities (requires Grype or Snyk scan)
curl -L -O https://github.com/Javier-Godon/idp-concept/releases/download/v1.0.0/koncept-linux-amd64.sbom.xml
grype --from konzept-linux-amd64.sbom.xml
```

### For Enterprise/Air-Gapped Deployments

- Store `koncept.provenance.json` in your artifact repository as proof of build integrity
- Store SBOM for quarterly vulnerability reviews and license audits
- Validate provenance before deploying to high-security environments

### For Enterprises Using Container Images

```bash
# Pull the pinned image
docker pull ghcr.io/javier-godon/idp-concept/koncept:v1.0.0

# Container is signed by GitHub Actions (OCI signing support in future cosign release)
# For now, checksums on the release page provide integrity
```

---

## Workflow Details

### Binaries Job (`release.yml`)

- ✅ Builds for all platforms (Linux amd64/arm64, macOS amd64/arm64, Windows amd64)
- ✅ Generates SHA256SUMS checksums
- ✅ Creates SBOM for each binary via `syft`
- ✅ Signs each binary via `cosign sign-blob` (Sigstore keyless)
- ✅ Outputs hashes for SLSA provenance job

### Provenance Job (`release.yml`)

- ✅ Generates SLSA v1.0 provenance for all binaries
- ✅ Publishes `koncept.provenance.json` to GitHub Release
- ✅ Requires explicit `id-token: write` permission (OIDC)

### Artifact Publishing

- GitHub Release includes:
  - Binaries (`koncept-linux-amd64`, `koncept-darwin-arm64`, `koncept-windows-amd64.exe`, etc.)
  - Checksums (`SHA256SUMS`)
  - Signatures (`.bundle` files, one per binary)
  - SBOMs (`.sbom.xml` files, one per binary)
  - Tarballs/archives (`.tar.gz`, `.zip`)
  - SLSA provenance (`koncept.provenance.json`)

---

## Verification Checklist for Releases

Before adopting a new version, teams should:

- [ ] Download the release artifacts from GitHub Release page
- [ ] Verify checksums: `sha256sum --check SHA256SUMS`
- [ ] Verify signature with Sigstore: `cosign verify-blob-experimental ...` (see examples above)
- [ ] Review SBOM: `grype --from koncept.sbom.xml` (if using Grype)
- [ ] Check SLSA provenance digest matches the binary: `jq .subject[] koncept.provenance.json`

---

## Security Properties

| Property | Mechanism | Trust Root |
|----------|-----------|-----------|
| **Authenticity** | Cosign + Sigstore | GitHub OIDC + Let's Encrypt + sigstore root CA |
| **Integrity** | SHA256 checksums + SLSA provenance | Git commit hash |
| **Completeness** | SBOM (CycloneDX) | Syft transitive scanner |
| **Traceability** | SLSA provenance | GitHub Actions workflow logs (audit trail) |

---

## Troubleshooting

### "Cannot verify signature"

- Ensure `cosign` is v2.0.0+: `cosign version`
- Check certificate expiry; Sigstore certs rotate daily
- Verify GitHub OIDC is enabled in the workflow (check logs for cosign login)

### "SBOM is empty"

- Binary might not have Go dependencies (pure static binary is possible)
- Run `syft <binary>` locally to debug

### "Provenance JSON doesn't match my binary"

- Hash the binary and compare to `subject.digest.sha256` in provenance JSON
- If mismatch, binary may have been mutated; do not use

---

## Future Work

1. **Container image signing**: OCI signing support (when cosign adds native OCI signing in `docker/build-push-action`)
2. **Time-stamping**: Add RFC 3161 timestamp authority for legal/audit trails
3. **Hardware signing**: optional support for hardware keys (YubiKey, etc.)
4. **Vulnerability scanning in CI**: Optional Renovate scan before release

---

## References

- SLSA: https://slsa.dev/ — Supply chain Levels for software Artifacts
- Sigstore: https://www.sigstore.dev/ — keyless signing with OIDC
- CycloneDX: https://cyclonedx.org/ — SBOM standard
- Syft: https://github.com/anchore/syft — SBOM generator
- Cosign: https://github.com/sigstore/cosign — signing tool
