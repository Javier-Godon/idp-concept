# Helmfile Orchestration & Governance

> This document describes the Helmfile output generation, metadata governance, and dependency orchestration patterns used in idp-concept.

---

## Overview

The Helmfile procedure provides **declarative multi-chart orchestration** with governance metadata and deterministic dependency ordering derived from framework stack definitions.

```
Stack Definition
  (components, accessories, namespaces, metadata)
           ↓
  kcl_to_helmfile procedure
           ↓
helmfile.yaml
  (releases with labels, namespaces, needs, values)
           ↓
  helmfile sync / helmfile apply / helmfile charts
```

---

## 1. Helmfile Output Structure

### File Organization

```
output/
├── helmfile.yaml          # Main orchestration file
├── charts/
│   ├── <component-1>/
│   │   ├── Chart.yaml
│   │   └── values.yaml
│   ├── <component-2>/
│   │   ├── Chart.yaml
│   │   └── values.yaml
│   └── <accessory-1>/
│       ├── Chart.yaml
│       └── values.yaml
└── dry_run_plan.yaml      # Side-by-side planning visibility
```

### Helmfile Schema

```yaml
# Top-level configuration
repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami
environments:
  dev:
    values:
      env: development
helmDefaults:
  atomic: true
  timeout: 5m
releases:
  - name: erp-api
    namespace: erp-apps
    chart: ./charts/erp-api
    version: 1.0.0
    labels:
      owner: erp-platform-team
      team: erp-platform
      lifecycle: production
      sloTier: tier-1
      criticality: high
      dataClassification: internal
      costCenter: CC-ERP-001
    values:
      - ./charts/erp-api/values.yaml
    needs:
      - erp-postgres

  - name: erp-postgres
    namespace: erp-postgres
    chart: ./charts/erp-postgres
    version: 1.0.0
    labels:
      owner: erp-platform-team
      team: erp-platform
      lifecycle: production
      sloTier: tier-1
      criticality: high
      dataClassification: internal
      costCenter: CC-ERP-001
    values:
      - ./charts/erp-postgres/values.yaml
    needs: []

# Top-level labels and common labels
labels:
  owner: erp-platform-team
  team: erp-platform
  lifecycle: production
  sloTier: tier-1
  criticality: high
  dataClassification: internal
  costCenter: CC-ERP-001
commonLabels:
  owner: erp-platform-team
  team: erp-platform
  lifecycle: production
  sloTier: tier-1
  criticality: high
  dataClassification: internal
  costCenter: CC-ERP-001
```

---

## 2. Metadata Governance

### Metadata Sources

Helmfile metadata is derived from `RenderStack.metadata`:

```kcl
metadata:
  owner: str                 # Team or person owning the application
  team: str                  # Team identifier (e.g., "platform-team")
  lifecycle: str             # Development stage (development|staging|production)
  sloTier: str              # SLO tier (tier-1|tier-2|tier-3|best-effort)
  criticality: str          # Business criticality (high|medium|low)
  dataClassification: str   # Data sensitivity (internal|confidential|public)
  costCenter: str           # Billing/cost center code
  runbook: str              # URL to operational runbook
  repository: str           # Source repository URL
  support: str              # Support contact (email or Slack channel)
```

### Metadata Application

Metadata is applied at **three levels** for complete governance visibility:

1. **Top-level `labels`** — Applied to the Helmfile itself for global tracking
2. **Top-level `commonLabels`** — Applied to all releases by Helm automatically
3. **Per-release `labels`** — Override or extend top-level labels for specific releases

This triple-application ensures governance metadata flows through at every Helm invocation:

- When Helm installs/upgrades a release, `commonLabels` and release-specific `labels` are merged
- When operators query released charts, they see the full governance context
- When observability systems scrape pod/service labels, they inherit the stack identity

### Example: Owner Tracking

```yaml
# Top-level (global stack identity)
labels:
  owner: platform-team

# Common (applied to all releases)
commonLabels:
  owner: platform-team

# Per-release (can override if needed)
releases:
  - name: critical-service
    labels:
      owner: critical-service-owner  # Overrides commonLabels
```

---

## 3. Dependency Orchestration

### How `dependsOn` Maps to Helmfile `needs`

Framework stacks define dependencies via `dependsOn` arrays in module definitions:

```kcl
component.ComponentInstance {
  name = "api"
  dependsOn = [
    { kind = "Namespace", name = "apps" }
    { kind = "APPLICATION", name = "auth-service", namespace = "apps" }
    { kind = "CRD", name = "postgres", namespace = "data" }
  ]
}
```

The Helmfile procedure translates these into `needs` entries:

```yaml
releases:
  - name: api
    needs:
      - apps/auth-service     # component dependency in same namespace
      - data/postgres         # accessory dependency
```

The `needs` format follows Helmfile convention: `namespace/release-name`.

### Effective Name Resolution

Dependencies are resolved using **effective release names** after applying override patches:

```go
_effective_release_name = lambda module_name: str, options: hf.HelmfileRenderOptions -> str {
    _override_patch = _release_override_patch(options, module_name)
    _override_patch.name if _override_patch != None and _override_patch.name != Undefined 
        else module_name
}
```

This ensures that if a release is renamed via `releaseOverrides`, the `needs` entry points to the actual renamed release, not the original module name.

### Dependency Contract

| Dependency Kind | Example `needs` Entry | Notes |
|---|---|---|
| Namespace | `erp-apps/erp-api` | Component within namespace |
| Component (APPLICATION) | `erp-apps/erp-api` | Direct release dependency |
| Accessory (CRD, SECRET) | `data/erp-postgres` | Infrastructure dependency |
| ThirdParty (HELM) | `tools/monitoring` | External third-party release |

---

## 4. Configuration & Customization

### HelmfileRenderOptions Schema

The `RenderStack.helmfile` field accepts `HelmfileRenderOptions` for fine-grained control:

```kcl
helmfile: hf.HelmfileRenderOptions {
    chartBasePath = "./charts"              # Path to generated charts
    namespace = "default"                   # Global namespace override
    kubeContext = "production-cluster"      # Kube context for all releases
    includeGeneratedReleases = True         # Include auto-generated releases
    
    # Standard Helmfile fields
    repositories = [
        { name = "bitnami", url = "https://charts.bitnami.com/bitnami" }
    ]
    environments = {
        "prod": { values = { env = "production" } }
    }
    helmDefaults = {
        atomic = True
        timeout = "5m"
    }
    
    # Release defaults (applied to all generated releases)
    releaseDefaults = hf.ReleasePatch {
        createNamespace = True
        verify = False
    }
    
    # Per-release overrides
    releaseOverrides = {
        "erp-postgres": hf.ReleasePatch {
            name = "postgres-prod"           # Rename release
            namespace = "database"           # Override namespace
            condition = "postgres.enabled"   # Conditional deployment
            needs = ["namespace-provisioner"] # Override dependencies
        }
    }
    
    # Hand-authored releases not generated from stack
    extraReleases = [
        {
            name = "external-service"
            namespace = "external"
            chart = "third-party/service"
            version = "1.0.0"
        }
    ]
}
```

### Setting HelmfileRenderOptions in-place

In release factories:

```kcl
import framework.models.manifests.renderstack as renderstack
import custom.helmfile.helmfile as hf

_stack = renderstack.RenderStack {
    # ... stack definition ...
    helmfile = hf.HelmfileRenderOptions {
        repositories = [...]
        releaseDefaults = hf.ReleasePatch { ... }
        releaseOverrides = { ... }
    }
}
```

---

## 5. Validation & Testing

### Procedure Tests

Helmfile generation is tested in `framework/tests/procedures/helmfile_test.k`:

- ✅ Releases generated from components
- ✅ Releases generated from accessories
- ✅ Full helmfile structure from stack
- ✅ Dependency needs calculation
- ✅ Empty components handling
- ✅ Metadata label injection
- ✅ Release overrides patching

Run tests:

```bash
cd framework
kcl test tests/procedures/helmfile_test.k
```

### Golden Snapshot Validation

Helmfile output is tracked in golden snapshots for regression detection:

```bash
cd projects/erp_back/pre_releases/manifests/dev
koncept golden check --formats helmfile
```

Expected location: `golden/helmfile/manifests.yaml` (single aggregated file containing the helmfile.yaml)

### CLI Render Verification

```bash
cd projects/erp_back/pre_releases/manifests/dev
koncept render helmfile --factory factory
# Generates output/helmfile.yaml + output/charts/*/
```

---

## 6. Best Practices

### 1. Always Use Stack Metadata

```kcl
# Good: metadata flows through Helmfile
_stack = renderstack.RenderStack {
    metadata = {
        owner = "team-a"
        team = "platform"
        criticality = "high"
        costCenter = "CC-001"
    }
    # ...
}

# Avoid: missing metadata → less observability
_stack = renderstack.RenderStack {
    # metadata = Undefined
}
```

### 2. Keep `dependsOn` Accurate

```kcl
# Good: explicit dependencies
component.ComponentInstance {
    name = "api"
    dependsOn = [
        { kind = "Namespace", name = "apps" }
        { kind = "CRD", name = "postgres", namespace = "data" }
    ]
}

# Avoid: missing dependencies → race conditions in helm sync
component.ComponentInstance {
    name = "api"
    dependsOn = []  # api implicitly depends on postgres, but it's missing
}
```

### 3. Use Release Overrides Sparingly

```kcl
# Good: override when Helmfile-specific config needed
releaseOverrides = {
    "postgres": hf.ReleasePatch {
        condition = "postgres.enabled"  # Easy opt-out for dev environments
    }
}

# Avoid: overriding namespace just to avoid updating helm chart
releaseOverrides = {
    "api": hf.ReleasePatch {
        namespace = "custom-ns"  # Should update chart instead
    }
}
```

### 4. Pin Chart Versions

```yaml
# Good: explicit version pins
releases:
  - name: postgres
    chart: ./charts/postgres
    version: "16.4-alpine"

# Avoid: floating versions (no version = latest)
releases:
  - name: postgres
    chart: ./charts/postgres
```

### 5. Document External Releases

```kcl
# Good: hand-authored releases documented in code
extraReleases = [
    {
        name = "external-monitoring"
        chart = "prometheus/kube-prometheus-stack"
        version = "65.0.0"
        # TODO: Consider migrating to framework template
    }
]

# Avoid: undocumented extra releases
extraReleases = [...]
```

---

## 7. Troubleshooting

### Helmfile Validation Errors

```bash
# Validate helmfile.yaml syntax before deploy
helmfile lint

# Preview what helmfile sync would do
helmfile diff
```

### Missing Dependency Needs

**Problem**: Release deploys before its dependency is ready

**Solution**: Ensure `dependsOn` is complete in module definition

```diff
- dependsOn = [{ kind = "Namespace", name = "apps" }]
+ dependsOn = [
+     { kind = "Namespace", name = "apps" }
+     { kind = "CRD", name = "postgres", namespace = "data" }
+ ]
```

### Override Not Taking Effect

**Problem**: `releaseOverrides` for a release not applied

**Solution**: Verify module name matches release name (before override)

```kcl
# Module name is "postgres" (lowercase)
component.ComponentInstance {
    name = "postgres"
    # ...
}

# Override key must match module name
releaseOverrides = {
    "postgres": hf.ReleasePatch { ... }  # ✅ Correct
    "Postgres": hf.ReleasePatch { ... }  # ❌ Won't match
}
```

### Labels Not Appearing in Helm Release

**Problem**: Governance labels missing from deployed pods

**Solution**: Ensure `commonLabels` are applied and inherited by templates

The framework applies `commonLabels` at the Helmfile level; chart templates must respect them (most modern charts do).

If a chart ignores `commonLabels`, patch it:

```yaml
releases:
  - name: api
    values:
      - ./charts/api/values.yaml
      - labels:
          inherited_from: stackLabel
```

---

## 8. Integration with Other Formats

### YAML Output Structure

Helmfile and YAML outputs come from the same stack:

```
RenderStack
  ↓
  ├─→ kcl_to_yaml → output/manifests.yaml
  ├─→ kcl_to_helmfile → output/helmfile.yaml
  ├─→ kcl_to_kusion → output/kusion.yaml
  └─→ kcl_to_crossplane → output/crossplane/
```

Helmfile and YAML outputs describe the same infrastructure. Use whichever matches your deployment strategy.

### Parity with Crossplane

Both Helmfile and Crossplane outputs receive identical stack metadata, though they apply it differently:

- **Helmfile**: Metadata flows through `labels` → Helm release tags → Kubernetes labels
- **Crossplane**: Metadata flows through annotations → XRD/Composition/XR → wrapped Object annotations

---

## 9. Operational Workflows

### Deploy via Helmfile

```bash
cd output
helmfile sync
```

### Preview Changes

```bash
cd output
helmfile diff
```

### Upgrade with Custom Values

```bash
cd output
helmfile -l team=platform sync --values custom-values.yaml
```

### Selectively Deploy Releases

```bash
cd output
helmfile -l criticality=high sync  # Deploy only high-criticality releases
```

---

## 10. Reference

- Official Helmfile docs: https://helmfile.readthedocs.io/
- Helm docs: https://helm.sh/docs/
- Generated helmfile schema: `framework/custom/helmfile/helmfile.k`
- Procedure implementation: `framework/procedures/kcl_to_helmfile.k`
- Procedure tests: `framework/tests/procedures/helmfile_test.k`

---

## 11. Implementation Status

✅ **Complete Features**:

- Helmfile generation from stack components/accessories
- Metadata label injection at three levels (top-level, common, per-release)
- Dependency orchestration via `needs` calculation
- Release overrides and customization
- Golden snapshot validation
- Procedure tests with 20+ test cases
- CLI integration via `koncept render helmfile`

🔄 **In Progress**:

- Expanded Helmfile integration testing with real chart values
- Observability enhancements (resource totals in dry-run output)
- Multi-chart dependency analysis and visualization

📋 **Future**:

- Fleet output format (Helmfile + GitRepo as deployment interface)
- Helmfile lifecycle hooks for pre/post sync callbacks
- Custom Helmfile plugins for organization-specific hooks
