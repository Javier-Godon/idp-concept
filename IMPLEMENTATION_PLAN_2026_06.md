# Strategic Evolution Implementation Plan - June 2026

> Steady, secure implementation of medium-term objectives to enhance helmfile and crossplane V2 outputs

**Execution Date**: June 3, 2026
**Priority Focus**: Helmfile integration testing, observability enhancements, CLI distribution hardening
**Expected Outcome**: Production-grade multi-format output system with confidence and visibility

---

## Phase 1: Helmfile Integration Testing (Day 1-2)

### Objective
Verify that generated Helmfiles can be templated with real Helm, catching template injection errors and chart metadata mismatches early.

### Implementation Steps

1. **Create Helmfile integration test fixture** (`framework/tests/acceptance/cases/helmfile-integration`)
   - Render a reference stack to Helmfile format
   - Template each generated Helm chart with `helm template`
   - Validate manifests against kubeval/kubeconform
   - Check dependency ordering with `helm dependency list`

2. **Add to acceptance test suite** (`scripts/acceptance_kind.sh`)
   - Register as dry-run-only scenario (no kubectl apply)
   - Use real Helm binary interaction (not stubs)
   - Capture template output for regression comparison

3. **Document Helmfile workflow** (in `docs/`)
   - Best practices for Helmfile + helmfile-secrets workflows
   - Storage class configuration patterns
   - Common override patterns

### Success Criteria
- ✅ Helmfile + helm template produces valid manifests without injection errors
- ✅ Dependency ordering satisfied (`needs` entries resolvable)
- ✅ All referenced charts exist with correct versions
- ✅ Test integrated into verification pipeline

---

## Phase 2: Observability Enhancements in Dry-Run (Day 2-3)

### Objective
Expand `koncept dry-run` output to include resource request totals, storage predictions, and cluster footprint estimations.

### Implementation Steps

1. **Enhance dry-run KCL procedure** (`framework/procedures/kcl_to_dry_run.k`)
   - Calculate total CPU/memory requests across all Deployments/StatefulSets
   - Aggregate Persistent Volume sizes
   - Estimate replicas × resource-per-replica
   - Detect storage classes and provide provisioning recommendations

2. **Add observability schema** (`framework/models/observability.k`)
   ```kcl
   schema ResourceFootprint:
       totalCpuRequest: str
       totalMemoryRequest: str
       totalStorageRequest: str
       estimatedNodes: int  # based on node profile (small/medium/large)
       warnings: [str]  # e.g., "no resource limits; cluster auto-scale may thrash"
   ```

3. **Update dry-run CLI output** (`cmd/koncept/cmd/dry_run.go`)
   - Print human-readable summary: "Cluster footprint: 3 nodes, 12 CPU, 48 Gi memory"
   - Add `--verbose` flag to show per-module breakdown
   - Include storage provisioning matrix (local/SSD/Ceph)

### Success Criteria
- ✅ `koncept dry-run` shows estimated cluster footprint
- ✅ Storage predictions account for replication/backup
- ✅ Teams can review resource needs before rendering
- ✅ Warnings catch common misconfigurations (missing limits, etc.)

---

## Phase 3: CLI Distribution Hardening (Day 3-4)

### Objective
Enable cross-platform binary distribution with pinned KCL toolchain and container image validation.

### Implementation Steps

1. **Add Makefile targets for cross-platform builds** (`cmd/koncept/Makefile`)
   ```makefile
   build-all:
       GOOS=linux GOARCH=amd64 go build -o bin/koncept-linux-amd64
       GOOS=darwin GOARCH=amd64 go build -o bin/koncept-darwin-amd64
       GOOS=darwin GOARCH=arm64 go build -o bin/koncept-darwin-arm64
       GOOS=windows GOARCH=amd64 go build -o bin/koncept-windows-amd64.exe
   
   checksums:
       sha256sum bin/koncept-* > bin/CHECKSUMS
   ```

2. **Create container image** (`Dockerfile`)
   - Use minimal base (alpine or distroless)
   - Pin KCL CLI version
   - Verify checksums at build time
   - Test image rendering in container

3. **Add CI/CD workflow** (`.github/workflows/release.yml`)
   - Trigger on Git tags (v*) 
   - Build cross-platform binaries
   - Generate checksums
   - Create GitHub release with assets
   - Push container image to registry

### Success Criteria
- ✅ Prebuilt binaries available for Linux/macOS/Windows
- ✅ Container image includes pinned KCL toolchain
- ✅ Checksums published for security verification
- ✅ CI/CD automates release workflow

---

## Phase 4: Documentation & Learning Updates (Day 4)

### Objective
Refine strategic document with implementation learnings and clear guidance for adoption.

### Implementation Steps

1. **Add Implementation Learnings section** to `PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md`
   - Document decisions made during Helmfile/Crossplane hardening
   - Capture lessons about metadata parity vs operational reality
   - Note patterns that worked well (FactorySeed, dependency identity)
   - Identify future improvements (Score input format, Fleet output)

2. **Create CLI Distribution Guide** (`docs/DISTRIBUTION.md`)
   - How to download prebuilt binaries
   - Container image usage
   - Checksum verification
   - Installing from source

3. **Create Helmfile Adoption Guide** (`docs/HELMFILE_ADOPTION.md`)
   - When to use Helmfile vs plain YAML
   - Integration with Helm workflows
   - Storage class patterns
   - Multi-environment override strategies

4. **Update TESTING_STRATEGY.md** with acceptance levels and Helmfile integration

### Success Criteria
- ✅ All implementation decisions documented
- ✅ Clear guidance for operators to adopt each feature
- ✅ Examples for common patterns
- ✅ Links between docs are consistent

---

## Phase 5: Crossplane Runtime Test Expansion (Optional, Day 4-5)

### Objective
Expand Crossplane runtime validation beyond `smoke` profile to include continuous reconciliation checks.

### Implementation Steps

1. **Add `deep` runtime profile** that exercises:
   - Full XRD/Composition/XR lifecycle (apply → wait for ready → delete)
   - Prerequisite controller interactions (e.g., Helm provider waits)
   - Error recovery patterns

2. **Create Crossplane acceptance fixture** for multi-stage validation
   - Stage 1: Apply XRD (should be idempotent)
   - Stage 2: Apply prerequisites + XR (wait for readiness)
   - Stage 3: Verify resource status/conditions
   - Stage 4: Delete XR + verify cleanup

3. **Document runtime test workflows** in `docs/ACCEPTANCE_RUNTIME.md`

### Success Criteria
- ✅ `koncept crossplane test --runtime-profile lifecycle` exercises full lifecycle
- ✅ Teams can validate Crossplane compositions in CI before production
- ✅ Safe defaults (prerequisites excluded, cleanup enabled)

---

## Commit Strategy & Timeline

- **Day 1**: Helmfile integration testing + Phase 2 scaffolding
- **Day 2**: Observability enhancements (dry-run footprint)
- **Day 3**: CLI distribution hardening (Makefile, Dockerfile, CI/CD)
- **Day 4**: Documentation refinement + learnings capture
- **Final**: Single comprehensive commit with all phases

---

## Rollback Plan

If any phase encounters blockers:
1. Skip to next phase; return to blockers with delegation
2. Test failures in Phase X do NOT block Phase Y (independent implementations)
3. Document issues in `docs/KNOWN_ISSUES.md` for future investigation

---

## Success Metrics

| Item | Metric | Target |
|------|--------|--------|
| **Helmfile Integration** | Tests pass, real helm template validated | 100% |
| **Observability** | Dry-run shows footprint, no regressions in golden tests | No diff |
| **CLI Distribution** | Cross-platform builds work, container tests pass | All platforms |
| **Documentation** | No broken links, clear adoption paths | 0 dead links |
| **Overall** | All 9 output formats functional with governance parity | Regression-free |


