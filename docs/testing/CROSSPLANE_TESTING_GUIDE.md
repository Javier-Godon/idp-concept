# Crossplane Testing & Lifecycle Validation Guide

> Complete workflow for testing Crossplane V2 outputs: from static validation to full reconciliation and cleanup.

---

## 1. Overview: The Testing Pyramid

Crossplane output testing follows a safety pyramid — validate progressively with increasing cluster impact:

```
      ┌─────────────────────────┐
      │  Full Reconciliation    │  ← Longest timeouts, full cleanup
      │  (lifecycle/api-lifecycle│  ← Real cluster state changes
      ├─────────────────────────┤
      │  Prerequisite Validation │  ← Prerequisites installed, XR reconciled
      │  (catalog profile)       │  ← Server-dry-run with operator context
      ├─────────────────────────┤
      │  API Contract Validation │  ← XRD/Composition/XR syntax checked
      │  (smoke profile)         │  ← Server-dry-run for API compatibility
      ├─────────────────────────┤
      │  Static Contract Checks  │  ← No kubectl required
      │  (default/no-profile)    │  ← Validates output structure only
      └─────────────────────────┘
```

## 2. Static Validation (Always First)

Static checks require **no cluster access** and catch structural errors early.

### Usage

```bash
# From a factory directory
koncept crossplane test

# Or with explicit factory
koncept crossplane test --factory projects/erp_back/pre_releases/manifests/dev/factory
```

### What It Validates

- ✅ All required output files exist: `xrd.yaml`, `composition.yaml`, `xr.yaml`
- ✅ Prerequisites file exists (if applicable)
- ✅ XRD is valid Kubernetes manifest
- ✅ Composition pipeline structure is valid
- ✅ All Providers and Functions are **pinned** (no `latest` tags)
- ✅ XR references XRD/Composition correctly

### Example Output

```
crossplane test: static contract checks passed
  providers pinned: 4
  functions pinned: 2
[warn] composition function-kcl missing version pin
```

### When to Use

- **PR gates** — Run on all PRs to catch manifest errors before review
- **CI pipelines** — Quick feedback loop for fast iteration
- **Pre-render checks** — Validate before long rendering processes

---

## 3. Local Render Validation (Optional)

If the `crossplane` CLI is installed locally, validates that the Crossplane render engine accepts your artifacts.

### Prerequisites

```bash
# Install crossplane CLI
curl https://releases.crossplane.io/download/v1.15.0/crank-linux-amd64 -o /usr/local/bin/crank
chmod +x /usr/local/bin/crank
crank --version
```

### Usage

```bash
# Enable automatic local render (if crossplane CLI found)
koncept crossplane test

# Require crossplane CLI (fail if not found)
koncept crossplane test --require-cli

# Skip local render even if available
koncept crossplane test --skip-render
```

### What It Validates

- ✅ Composition pipeline renders without function errors
- ✅ Function result formats are valid
- ✅ All function inputs/outputs match expected types
- ✅ Sequencer rules produce valid ordering constraints

### When to Use

- **Local development** — Catch rendering errors before pushing to cluster
- **Nightly CI** — More comprehensive checks without impacting PR gates
- **After composition changes** — Validate pipeline logic

---

## 4. API Server Validation (Dry-Run Profile)

Validates against a real Kubernetes cluster **WITHOUT creating resources**.

### Prerequisites

```bash
# Requires kubectl access to a Kuber netes cluster
kubectl config current-context
```

### Usage

```bash
# Default smoke profile (safe server-dry-run)
koncept crossplane test --runtime-profile smoke

# With explicit context
koncept crossplane test --runtime-profile smoke --runtime-context prod-cluster

# Plan the validation without running it
koncept crossplane test --runtime-profile smoke --runtime-plan
```

### What It Validates

- ✅ All manifests are valid against cluster API server
- ✅ CRDs are installed (detect missing operators)
- ✅ RBAC allows manifest application
- ✅ Defaults and mutations are applied correctly
- ✅ Webhooks accept the manifests

### Timing

- **Typical**: 5-30 seconds per manifest

### When to Use

- **Pre-deployment checks** — Validate manifest compatibility before deployment
- **Cluster compatibility checks** — Detect missing operators or incompatible versions
- **Integration testing** — Quick validation without long waits

---

## 5. Prerequisite Validation (Catalog Profile)

Validates with all **prerequisites installed** (Providers, Functions) but **without deploying the actual composition**.

### Prerequisites

```bash
# Prerequisites must be installed on target cluster
kubectl get providers
kubectl get functions

# Or use konzept to install them
kubectl apply -f output/crossplane/prerequisites/infrastructure.yaml
```

### Usage

```bash
# Catalog profile: prerequisites + server-dry-run
koncept crossplane test --runtime-profile catalog

# Plan prerequisites installation
koncept crossplane test --runtime-profile catalog --runtime-plan
```

### What It Validates

- ✅ Providers are installed and functioning
- ✅ Functions are registered and available
- ✅ XRD is accepted by control plane
- ✅ Composition references valid functions
- ✅ Composition pipeline validates in provider context

### Timing

- **Typical**: 10-60 seconds (includes CRD registration)

### When to Use

- **Operator readiness checks** — Ensure required controllers are running
- **Integration CI** — Validate composition logic before full apply
- **Dependency verification** — Detect operator/provider version conflicts

---

## 6. Full Reconciliation (Lifecycle Profile)

**Real cluster state changes** — applies all resources, waits for readiness, then cleans up.

### Prerequisites

```bash
# Requirements:
# 1. kubectl access to writable cluster
# 2. All prerequisites installed (Providers, Functions, etc.)
# 3. Enough cluster resources for deployed workloads
# 4. Storage classes available if PVCs required

# Verify prerequisites are ready
kubectl get providers --all-namespaces
kubectl get functions --all-namespaces
kubectl get storageclass
```

### Usage

```bash
# Lifecycle profile: apply → wait → cleanup
koncept crossplane test --runtime-profile lifecycle

# With custom kubecontext
koncept crossplane test --runtime-profile lifecycle --runtime-context staging

# Custom timeout (default 120s)
koncept crossplane test --runtime-profile lifecycle --runtime-context staging --runtime-timeout 300s

# Keep resources after test (debugging)
koncept crossplane test --runtime-profile lifecycle --runtime-context staging --keep-artifacts

# Plan the execution before running
koncept crossplane test --runtime-profile lifecycle --runtime-plan
```

### What It Validates

- ✅ XRD is applied successfully
- ✅ Composition is applied successfully
- ✅ XR instantiation succeeds
- ✅ Sequencer rules order resources correctly
- ✅ All composed resources are reconciled
- ✅ XR reaches Ready condition
- ✅ Cleanup removes all resources (no orphans)

### Cleanup Behavior

Resources are deleted in **reverse dependency order**:

1. Delete XR (claim)
2. Wait for composed resources to be reaped
3. Delete Composition
4. Delete XRD
5. (Optional) Delete prerequisites if `--runtime-cleanup-prerequisites` specified

### Timing

- **Typical**: 30 seconds - 5 minutes (depends on workload complexity)
- **Timeouts**: 120s (lifecycle) / 180s (api-lifecycle)

### When to Use

- **Nightly CI tests** — Full reconciliation validation
- **Staging deployments** — Smoke test real operator behavior
- **Acceptance tests** — Validate end-to-end functionality
- **Debugging production issues** — Reproduce real reconciliation flows

### Common Issues

| Issue | Cause | Solution |
|---|---|---|
| `Timeout waiting for Ready` | Operator not progressing | Check operator logs: `kubectl logs -n crossplane-system <pod>` |
| `Resource quota exceeded` | Cluster too small | Use smaller footprints or clean other resources |
| `Unknown provider` | Prerequisites not installed | `kubectl apply -f prerequisites/infrastructure.yaml` |
| `Orphaned resources after cleanup` | Cleanup failed | Inspect with `kubectl get all --all-namespaces` |

---

## 7. API Lifecycle Profile (Advanced)

Extended reconciliation with **operator-level validation** — waits longer, validates composed resource  health.

### Usage

```bash
# API lifecycle profile: apply → wait → validate health → cleanup
koncept crossplane test --runtime-profile api-lifecycle

# Longer timeout for complex workloads
koncept crossplane test --runtime-profile api-lifecycle --runtime-timeout 600s
```

### Differences from Lifecycle

| Aspect | Lifecycle | API Lifecycle |
|---|---|---|
| Prerequisites | Excluded | Excluded |
| Timeout | 120s | 180s |
| Validation | XR Ready condition | XR + composed resources health |
| Use case | Fast feedback | Production confidence |

### When to Use

- **Pre-release validation** — High-confidence checks before production
- **Complex stateful workloads** — Databases, messaging systems
- **Multi-component stacks** — App + database + secrets

---

## 8. Matrix Profile (Progressive Validation)

Runs the **full testing pyramid** in order: `smoke` → `catalog` → `api-lifecycle`

### Usage

```bash
# Run full testing matrix
koncept crossplane test --runtime-profile matrix

# Run subset of matrix
koncept crossplane test --runtime-profile matrix --runtime-matrix-from catalog
koncept crossplane test --runtime-profile matrix --runtime-matrix-stop-on api-lifecycle

# Combined slice
koncept crossplane test --runtime-profile matrix --runtime-matrix-from catalog --runtime-matrix-stop-on catalog
```

### What It Does

1. **Step 1 (smoke)**: Server-dry-run validation
2. **Step 2 (catalog)**: Prerequisites + composition pipeline check
3. **Step 3 (api-lifecycle)**: Full reconciliation with extended timeouts

### Timing

- **Total**: 2-10 minutes (depends on resource complexity)

### When to Use

- **Comprehensive CI/CD** — Full testing before promoting to production
- **Acceptance testing** — Prove all layers work together
- **Regression detection** — Catch subtle timing/ordering issues

### Example CI/CD Integration

```yaml
# GitHub Actions example
jobs:
  crossplane-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Static validation (fast)
        run: konzept crossplane test
        
      - name: Full validation (slow - nightly only)
        if: github.event_name == 'schedule'or github.ref == 'refs/heads/main'
        run: koncept crossplane test --runtime-profile matrix
```

---

## 9. Safety Defaults & Best Practices

| Aspect | Recommendation | Why |
|---|---|---|
| **Profiles** | Start with `smoke`, graduate to `matrix` | Catch errors early, scale up safely |
| **Contexts** | Use staging cluster by default, prod only after approval | Prevent accidental production modifications |
| **Cleanup** | Enabled by default in lifecycle profiles | Prevent resource leaks and cost overruns |
| **Timeouts** | Use defaults (120s/180s), increase only if needed | Detect stuck reconciliations |
| **Artifacts** | Keep only for debugging (`--keep-artifacts`) | Saves disk space, easier cleanup |
| **Prerequisites** | Include by default in catalog profile | Catches operator issues early |

---

## 10. Example Workflows

### Local Development

```bash
# 1. Quick syntax check (no cluster needed)
koncept crossplane test

# 2. Verify with crossplane CLI (local)
koncept crossplane test --require-cli

# 3. Test against local cluster (kind/minikube)
koncept crossplane test --runtime-profile smoke --runtime-context kind-local
```

### CI/CD (PR Gates)

```bash
# Fast: < 30 seconds
koncept crossplane test

# Optional: Require crossplane CLI to be present
koncept crossplane test --require-cli
```

### CI/CD (Nightly/Main Branch)

```bash
# Full pyramid: smoke → catalog → api-lifecycle
koncept crossplane test --runtime-profile matrix --runtime-context staging

# With cleanup
koncept crossplane test --runtime-profile matrix --runtime-context staging --runtime-cleanup-prerequisites
```

### Debugging Production Issue

```bash
# Reproduce exact scenario with extended timeout
koncept crossplane test \
  --runtime-profile api-lifecycle \
  --runtime-context prod \
  --runtime-timeout 600s \
  --keep-artifacts

# Inspect artifacts
ls -la /tmp/crossplane-*
kubectl apply -f /tmp/crossplane-*/xr.yaml --dry-run=server
```

---

## 11. Troubleshooting

### "Unknown provider/function"

```bash
# Check installed providers
kubectl get providers --all-namespaces

# Install missing provider
kubectl apply -f output/crossplane/prerequisites/infrastructure.yaml

# Verify installed version
kubectl get provider provider-kubernetes -o yaml | grep version
```

### "Timeout waiting for Ready"

```bash
# Check XR status
kubectl describe xr <name> -n crossplane-system

# Check provider logs
kubectl logs -n crossplane-system deployment/crossplane -f

# Check composed resources
kubectl get managed.crossplane.io --all-namespaces
```

### "Cleanup failed to delete resource"

```bash
# Force delete stuck resource
kubectl delete xr <name> --grace-period=0 --force -n crossplane-system

# Check finalizers
kubectl get xr <name> -o yaml | grep finalizers

# Remove finalizer if stuck
kubectl patch xr <name> -p '{"metadata":{"finalizers":[]}}' -n crossplane-system
```

---

## 12. Integration with CI/CD

### GitHub Actions Example

```yaml
name: Crossplane Tests

on:
  pull_request:
  push:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'  # Nightly

jobs:
  static-validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install koncept
        run: make -C cmd/koncept build
      - name: Static Crossplane validation
        run: cmd/koncept/bin/koncept crossplane test --factory projects/erp_back/pre_releases/manifests/dev/factory

  full-validation:
    if: github.event_name == 'schedule' || github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v3
      - name: Install koncept
        run: make -C cmd/koncept build
      - name: Configure kubeconfig
        run: echo "${{ secrets.KUBE_CONFIG_STAGING }}" > ~/.kube/config
      - name: Full Crossplane matrix validation
        run: cmd/koncept/bin/koncept crossplane test --runtime-profile matrix --runtime-context staging
```

### GitLab CI Example

```yaml
crossplane:static:
  stage: validate
  script:
    - make -C cmd/koncept build
    - cmd/koncept/bin/koncept crossplane test

crossplane:runtime:
  stage: integration
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
    - if: '$CI_COMMIT_BRANCH == "main"'
  environment:
    name: staging
    kubernetes_namespace: crossplane-system
  script:
    - make -C cmd/koncept build
    - cmd/koncept/bin/koncept crossplane test --runtime-profile matrix
```

---

## 13. Performance Tuning

| Goal | Action |
|---|---|
| **Faster PR gates** | Run static only: `koncept crossplane test` |
| **Faster local dev** | Use smoke profile: `--runtime-profile smoke` |
| **Faster staging CI** | Skip prerequisites: (remove `--catalog` step) |
| **Faster cleanup** | Cleanup is parallelized automatically |
| **Parallel tests** | Run matrix slices in parallel: `--runtime-matrix-from X` |

---

## 14. Next Steps & Evolution

### Near-term (Next Sprint)

- [ ] Add resource inspection during reconciliation (post-Ready, pre-cleanup)
- [ ] Add detailed reconciliation progress logging
- [ ] Add automatic troubleshooting suggestions for common failures
- [ ] Enhance timeout calculation based on resource complexity

### Medium-term (Q3 2026)

- [ ] Add Crossplane rendering validation with real function execution
- [ ] Add multi-cluster validation (same XR on multiple clusters)
- [ ] Add drift detection and remediation testing

### Long-term (Q4 2026)

- [ ] Integration with observability systems (Prometheus metrics export)
- [ ] Automatic performance regression detection
- [ ] Predictive resource requirement analysis

---
