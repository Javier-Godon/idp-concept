# Dry-Run Planning & Observability

> Planning layer for idp-concept that previews merged configurations, module inventory, dependency graphs, and orchestration intent before rendering deployable artifacts.

---

## Overview

The `koncept dry-run` command generates a comprehensive planning document that helps teams understand what will be deployed before actually rendering manifests.

```
Factory Stack Definition
  (components, accessories, configurations)
           ↓
  kcl_to_dry_run procedure
           ↓
output/dry_run_plan.yaml
  (merged config, inventory, dependencies, orchestration preview)
```

---

## 1. Dry-Run Plan Structure

### Top-Level Schema

```yaml
apiVersion: koncept.bluesolution.es/v1alpha1
kind: DryRunPlan
metadata:
  name: erp-back-dry-run
  project: ERP Back
  version: 1.0.0
  generatedBy: koncept dry-run
spec:
  mergedConfigurations: {...}      # Kernel + Profile + Tenant + Site merged configs
  stackMetadata: {...}             # Owner, team, lifecycle, criticality, SLOs, cost center, etc.
  inventory: {...}                 # Namespaces, components, accessories, module count
  dependencies: [...]              # Dependency graph edges with kinds
  outputs:                          # Projected orchestration for Helmfile/Crossplane
    helmfile: {...}
    crossplane: {...}
```

### Merged Configurations

Contains the full merged configuration from all layers:

```yaml
mergedConfigurations:
  projectName: erp_back
  siteName: dev_cluster
  brandIcon: internal-logo
  appsNamespace: erp-apps
  gitRepoUrl: https://github.com/Javier-Godon/idp-concept
  rootPaths:
    postgres: erp-postgres.erp-postgres.svc.cluster.local
  (... all project/profile/tenant/site configuration values ...)
```

This shows teams exactly what configurations were merged, useful for debugging config override conflicts.

### Stack Metadata

Governance context for the entire deployment:

```yaml
stackMetadata:
  owner: erp-platform-team
  team: erp-platform
  system: erp-back
  domain: erp
  lifecycle: production
  sloTier: tier-1
  criticality: high
  dataClassification: internal
  costCenter: CC-ERP-001
  runbook: https://runbooks.bluesolution.es/erp-back
  repository: https://github.com/Javier-Godon/idp-concept
  support: '#erp-platform-support'
```

### Inventory

Module count and composition:

```yaml
inventory:
  namespaces:
    - erp-apps
    - erp-postgres
  components:
    - name: erp-api
      namespace: erp-apps
      kind: component
      leaders:
        - APPLICATION:erp-api
      dependsOn:
        - Namespace:cluster:erp-apps
  accessories:
    - name: erp-postgres
      namespace: erp-postgres
      kind: accessory
      leaders:
        - CRD:erp-postgres
      dependsOn:
        - Namespace:cluster:erp-postgres
```

Leaders show what workload types each module contains (Deployment, StatefulSet, CRD instances, etc.).

### Dependency Graph

Edges showing what depends on what:

```yaml
dependencies:
  - from: erp-apps/erp-api
    to: cluster/erp-apps
    dependencyKind: Namespace
  - from: erp-postgres/erp-postgres
    to: cluster/erp-postgres
    dependencyKind: Namespace
  - from: erp-apps/erp-api
    to: erp-apps/dns-service
    dependencyKind: APPLICATION
```

Teams can read this to understand the deployment order and verify configurations are correct before rendering.

### Orchestration Preview

Projected outputs for Helmfile and Crossplane without full generation:

```yaml
outputs:
  helmfile:
    releaseCount: 2
    releases:
      - name: erp-api
        namespace: erp-apps
        chart: ./charts/erp-api
        needs:
          - erp-postgres
      - name: erp-postgres
        namespace: erp-postgres
        chart: ./charts/erp-postgres
        needs: []
  crossplane:
    metadata:
      resourceCount: 7
      sequencerRules: 5
      xrKind: XErpBack
      version: 1.0.0
    sequencerRules:
      - sequence: [ns-erp-apps, comp-erp-api-deployment-erp-api]
      - sequence: [ns-erp-postgres, acc-erp-postgres-cluster-erp-postgres]
    prerequisites:
      - Provider/provider-kubernetes
      - Provider/provider-helm
      - Function/function-patch-and-transform
      - Function/function-sequencer
      - Function/function-auto-ready
```

This gives operators immediate visibility into:

- How many Helm releases will be created
- Release names, namespaces, and dependencies
- How many Crossplane resources will be generated
- What Provider/Function packages will be needed

---

## 2. Usage

### Generate Plan

```bash
cd projects/erp_back/pre_releases/manifests/dev
koncept dry-run --factory factory
```

Output: `output/dry_run_plan.yaml`

### Review Plan Before Render

```bash
# Inspect merged configurations
yq '.spec.mergedConfigurations' output/dry_run_plan.yaml

# Check metadata
yq '.spec.stackMetadata' output/dry_run_plan.yaml

# View dependency graph
yq '.spec.dependencies' output/dry_run_plan.yaml

# Preview Helmfile releases
yq '.spec.outputs.helmfile.releases' output/dry_run_plan.yaml

# Preview Crossplane orchestration
yq '.spec.outputs.crossplane.sequencerRules' output/dry_run_plan.yaml
```

### In CI/CD Pipeline

```bash
# Fail on dry-run if configurations are wrong
koncept dry-run --factory factory || exit 1

# Then proceed to render real artifacts
koncept render yaml --factory factory
koncept render helmfile --factory factory
koncept render crossplane --factory factory
```

---

## 3. Safety & Observability Benefits

### Early Configuration Validation

Check merged configs before rendering any manifests:

```bash
# Does the namespace match our expectations?
yq '.spec.mergedConfigurations.appsNamespace' output/dry_run_plan.yaml

# Is the database host correct?
yq '.spec.mergedConfigurations.postgresHost' output/dry_run_plan.yaml

# Are the SLO tiers and criticality levels set properly?
yq '.spec.stackMetadata | {lifecycle, sloTier, criticality}' output/dry_run_plan.yaml
```

### Dependency Drift Detection

Verify Helmfile `needs` and Crossplane sequencer rules match logical dependencies:

```bash
# Did erp-api release depend on erp-postgres?
yq '.spec.outputs.helmfile.releases[] | select(.name == "erp-api") | .needs' output/dry_run_plan.yaml

# Are the sequencer rules capturing the right ordering?
yq '.spec.outputs.crossplane.sequencerRules' output/dry_run_plan.yaml
```

### Resource Footprint Preview

Before full render, operators can see projected resource counts:

```bash
# How many Helm releases will be created?
yq '.spec.outputs.helmfile.releaseCount' output/dry_run_plan.yaml

# How many Crossplane resources will be generated/wrapped?
yq '.spec.outputs.crossplane.metadata.resourceCount' output/dry_run_plan.yaml
```

---

## 4. Integration with Render Commands

The dry-run plan is **not a substitute** for full render, but a **safety check before**:

```
Flow: Develop → Validate Config → Generate Plan → Review Plan → Render Artifacts
```

1. **Develop**: Write configuration in factory
2. **Validate Config**: `koncept dry-run`
3. **Generate Plan**: Review `output/dry_run_plan.yaml`
4. **Review Plan**: Check merged configs, dependencies, metadata
5. **Render Artifacts**: `koncept render yaml|helmfile|crossplane`

---

## 5. Troubleshooting

### Plan Shows Wrong Namespace

**Problem**: `mergedConfigurations.appsNamespace` is not what team expected

**Solution**: Check configuration layer overrides (kernel → profile → tenant → site)

```bash
# Review configuration merge order in factory_seed.k
cat projects/erp_back/pre_releases/manifests/dev/factory/factory_seed.k | grep -A 10 "appsNamespace"

# Update site-level configuration if needed
cat projects/erp_back/sites/dev_cluster/configurations_dev.k
```

### Dependency Missing from Plan

**Problem**: `erp-api` does not show dependency on `erp-postgres` in orchestration preview

**Solution**: Verify `dependsOn` is set in component definition

```kcl
# In projects/erp_back/stacks/v1_0_0/modules_v1_0_0.k or similar

component.ComponentInstance {
    name = "erp-api"
    dependsOn = [
        { kind = "Namespace", name = "erp-apps" }
        { kind = "CRD", name = "erp-postgres", namespace = "erp-postgres" }  # ← Must be here
    ]
}
```

### Sequencer Rules Count Wrong

**Problem**: Plan shows `sequencerRules: 3` but 5 are expected

**Solution**: Check if all manifests are being generated (may need to verify module states)

```bash
# Count actual dependencies in plan output
yq '.spec.dependencies | length' output/dry_run_plan.yaml

# Or query Helmfile releases to see if any are missing
yq '.spec.outputs.helmfile.releaseCount' output/dry_run_plan.yaml
```

---

## 6. Best Practices

### 1. Always Run Before Render

```bash
# ✅ Good: Two-step validation
koncept dry-run
cat output/dry_run_plan.yaml  # Review
koncept render helmfile
```

```bash
# ❌ Avoid: Skip planning
koncept render helmfile  # Directly without visibility
```

### 2. Check Orchestration Projections

```bash
# Review Helmfile release needs
yq '.spec.outputs.helmfile.releases | .[] | {name, needs}' output/dry_run_plan.yaml

# Review Crossplane sequencer rules
yq '.spec.outputs.crossplane.sequencerRules' output/dry_run_plan.yaml
```

### 3. Document Overrides

If using `releaseOverrides` in Helmfile config, document why:

```kcl
releaseOverrides = {
    "postgres": hf.ReleasePatch {
        namespace = "database"  # This overrides the default erp-postgres namespace
        condition = "postgres.enabled"  # Allow opt-out for dev environments
    }
}
```

### 4. Keep Plan in Version Control

```bash
# Commit the dry-run plan with the factory config
git add projects/erp_back/pre_releases/manifests/dev/output/dry_run_plan.yaml
git add projects/erp_back/pre_releases/manifests/dev/factory/

# Enables reviewers to see exact orchestration before render
```

---

## 7. Operational Workflows

### Pre-Deployment Review

```bash
cd projects/erp_back/pre_releases/manifests/prod

# 1. Generate plan
koncept dry-run

# 2. Review what will be deployed
cat output/dry_run_plan.yaml

# 3. Check metadata matches environment
yq '.spec.stackMetadata | {owner, lifecycle, criticality, costCenter}' output/dry_run_plan.yaml

# 4. If correct, proceed to render all formats
./../../scripts/golden.sh update  # or use specific render commands
```

### Dependency Audit

```bash
# Find all dependencies for erp-api
yq '.spec.dependencies[] | select(.from == "erp-apps/erp-api")' output/dry_run_plan.yaml

# Verify Helmfile sees the same dependencies
yq '.spec.outputs.helmfile.releases[] | select(.name == "erp-api") | .needs' output/dry_run_plan.yaml
```

### Cost Estimation

```bash
# Extract cost center from metadata
COST_CENTER=$(yq '.spec.stackMetadata.costCenter' output/dry_run_plan.yaml)

# Count resources that will be deployed
RELEASE_COUNT=$(yq '.spec.outputs.helmfile.releaseCount' output/dry_run_plan.yaml)
RESOURCE_COUNT=$(yq '.spec.outputs.crossplane.metadata.resourceCount' output/dry_run_plan.yaml)

echo "Deploying $RELEASE_COUNT charts ($RESOURCE_COUNT Crossplane resources) to cost center $COST_CENTER"
```

---

## 8. Integration with Other Commands

### Complementary to `koncept crossplane test`

- **dry-run**: Shows what will be deployed (planning/validation)
- **crossplane test**: Validates generated Crossplane output (local render + optional kubectl checks)

```bash
# Workflow: Plan → Verify Crossplane → Generate All Formats
koncept dry-run
koncept crossplane test --runtime-profile smoke
koncept render yaml helmfile crossplane
```

### Complementary to `koncept render`

Each render command generates that specific format. Dry-run shows the planning layer across all formats before any are fully rendered.

```bash
koncept dry-run                  # Plan: merged configs + projections
koncept render yaml              # Kubernetes YAML
koncept render helmfile          # Helmfile orchestration
koncept render crossplane        # Crossplane artifacts (XRD + Composition + XR)
```

---

## 9. Reference

- Dry-run procedure: `framework/procedures/kcl_to_dry_run.k`
- Dry-run schema: `framework/models/dry_run_plan.k`
- CLI command: `cmd/koncept/cmd/dry_run.go`
- Golden snapshot: `projects/erp_back/pre_releases/manifests/dev/golden/dry-run/manifests.yaml`

---

## 10. Implementation Status

✅ **Complete Features**:

- Dry-run plan generation from stack definitions
- Merged configuration inclusion
- Stack metadata context
- Module inventory with leader tracking
- Dependency graph with kind information
- Helmfile orchestration preview with release count and needs
- Crossplane sequencer rules and resource count preview
- CLI integration: `koncept dry-run`
- Golden snapshot validation

🔄 **In Progress**:

- Resource footprint estimation (CPU, memory, storage prediction)
- Cost estimation based on resource counts and metadata
- Observability system export (Prometheus/Grafana labels)

📋 **Future**:

- Interactive filtering and exploration of dry-run plans
- Plan diffing between versions
- Dry-run plan OpenAPI schema for external tooling integration
