# Helmfile Adoption Guide

> When to use Helmfile vs plain YAML, integration with Helm workflows, and best practices for multi-environment deployments

**Status**: Production-ready (June 2026)
**Golden Tests**: ✅ Pass

---

## Overview

The `koncept render helmfile` output generates a complete, templated Helm chart ecosystem with a top-level `helmfile.yaml` orchestrator. This guide covers:

1. **When to choose Helmfile** over plain YAML or Helm
2. **How idp-concept generates Helmfile** from stack configuration
3. **Workflows for multi-environment deployments**
4. **Storage class patterns** (local, SSD, Ceph, etc.)
5. **Common override patterns** for team-specific needs

---

## When to Use Helmfile

### ✅ Use Helmfile When

- **Multiple related Helm charts** need coordinated deployment (e.g., webapp + database + cache)
- **Dependency ordering matters** (e.g., database must be ready before app)
- **Team prefers Helm** as the packaging standard but needs orchestration
- **Environment-specific overrides** are frequent and complex
- **GitOps workflow** includes a Helmfile repository (e.g., fleet, ArgoCD integration)
- **Upgrade paths** need sequencing (e.g., database schema first, then app)

### ❌ Don't Use Helmfile When

- **Simple single-chart deployments** (use `koncept render helm` instead)
- **Plain YAML is preferred** for compliance/audit (use `koncept render yaml`)
- **No Helm tooling** available in the deployment environment (use `koncept render yaml` or `kustomize`)

---

## idp-concept's Helmfile Generation Strategy

### Architecture: Strategy B (Parameterized Helm Charts)

idp-concept generates Helmfile using **Strategy B: Parameterized Helm Charts**.

```
kcl configurations + templates
           ↓
      framework builders
           ↓
[chart structure: Chart.yaml, values.yaml, templates/]
           ↓
helmfile.yaml (with releases, repositories, overrides, hooks)
           ↓
helm dependency update → helm repo add → helmfile sync
```

### Generated Artifacts

After `koncept render helmfile`:

```
output/
  helmfile.yaml                 # Top-level orchestrator (can be modified)
  charts/
    erp-api/                    # Generated Helm chart 1
      Chart.yaml
      values.yaml
      templates/
        deployment.yaml
        service.yaml
        configmap.yaml
    erp-postgres/               # Generated Helm chart 2
      Chart.yaml
      values.yaml
      templates/
        deployment.yaml
        service.yaml
        pvc.yaml
```

### helmfile.yaml Structure

```yaml
apiVersion: helmfile.darWindowsdel.io/v1alpha1
repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami

releases:
  - name: erp-api
    namespace: default
    chart: ./charts/erp-api
    needs:
      - erp-postgres
    # auto-injected from stack metadata
    labels:
      team: platform
      tier: app

  - name: erp-postgres
    namespace: default
    chart: ./charts/erp-postgres
    labels:
      team: platform
      tier: database
```

> **Key**: `needs` relationships are automatically computed from `dependsOn` chains in the stack.

---

## Workflow 1: Local Development

### Render and template-check

```bash
cd projects/erp_back/pre_releases/manifests/dev

# Generate Helmfile + charts
koncept render helmfile

# Verify charts are valid (no template errors)
helm template erp-api ./output/charts/erp-api
helm template erp-postgres ./output/charts/erp-postgres

# Validate manifests against kubeval
helm template erp-api ./output/charts/erp-api | kubeval
```

### Deploy to kind cluster

```bash
# Update dependencies (not needed for local charts, but good habit)
helmfile -f output/helmfile.yaml repo update

# Sync to kind cluster
helmfile -f output/helmfile.yaml sync

# Check status
helmfile -f output/helmfile.yaml status

# Clean up
helmfile -f output/helmfile.yaml delete
```

---

## Workflow 2: Multi-Environment Overrides with Helmfile Environments

### Override values per environment

Create `environment-overrides.yaml`:

```yaml
environments:
  dev:
    values:
      replicas: 1
      storageSize: 5Gi
      
  stg:
    values:
      replicas: 2
      storageSize: 20Gi
      
  prod:
    values:
      replicas: 3
      storageSize: 100Gi

releases:
  - name: erp-api
    namespace: default
    chart: ./charts/erp-api
    values:
      - replicas: {{ .Values.replicas }}
      - resources.requests.memory: "{{ mul .Values.replicas 512 }}Mi"
```

### Deploy to specific environment

```bash
helmfile -f helmfile.yaml -e prod sync
```

---

## Workflow 3: GitOps with ArgoCD

### Setup

1. **Commit helmfile to Git** (next to factory configs)
   ```
   projects/erp_back/releases/v1_0_0_production/
     factory/
       render.k
       factory_seed.k
     helmfile.yaml
     charts/
       erp-api/
       erp-postgres/
   ```

2. **Add ArgoCD ApplicationSet** that deploys via Helmfile:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: ApplicationSet
   metadata:
     name: idp-helm-releases
   spec:
     generators:
       - files:
           repoURL: https://git.example.com/idp-configs
           paths:
             - 'projects/*/releases/*/helmfile.yaml'
     template:
       spec:
         source:
           repoURL: https://git.example.com/idp-configs
           path: .
           plugin:
             name: helmfile
             env:
               - name: HELMFILE_PATH
                 value: src.repoURL/{{ .path }}
   ```

3. **Deploy**
   ```bash
   kubectl apply -f applicationset.yaml
   ```

---

## Storage Class Patterns

### Pattern 1: Cloud-managed (Default)

```kcl
# In your factory_seed.k
_storage_class = "standard"  # or "gp2" on AWS, "standard-rwo" on GKE

# In module definitions
database.SingleDatabaseModule {
    storageClassName = _storage_class
    storageSize = "50Gi"
}
```

Generated `values.yaml`:
```yaml
storageClassName: standard
persistence:
  size: 50Gi
```

### Pattern 2: Local Development (kind/minikube)

```kcl
# Use local hostPath persistent volumes
database.SingleDatabaseModule {
    storageClassName = "local-path"  # kind built-in
    createLocalPersistentVolume = true
    storageHostPath = "/mnt/data/postgres"
    storageSize = "10Gi"
}
```

### Pattern 3: Enterprise (Ceph/Longhorn)

```kcl
# For production Ceph clusters
database.SingleDatabaseModule {
    storageClassName = "rook-ceph-block"
    storageSize = "100Gi"
}

# Helmfile-level declaration
# This is auto-set by the framework
```

---

## Common Override Patterns

### Override 1: Change replicas for scaling

Edit the generated `output/helmfile.yaml`:

```yaml
releases:
  - name: erp-api
    chart: ./charts/erp-api
    values:
      - replicas: 5  # Override: was 2, now 5
```

Then:
```bash
helmfile -f output/helmfile.yaml sync
```

### Override 2: Add custom repository

```yaml
repositories:
  - name: mycompany
    url: https://helm.mycompany.com

releases:
  - name: erp-api
    chart: mycompany/erp-api
    values:
      - replicas: 3
```

### Override 3: Add post-deployment hooks

```yaml
releases:
  - name: erp-postgres
    chart: ./charts/erp-postgres
    hooks:
      - events: ["postsync"]
        showlogs: true
        command: sh
        args:
          - -c
          - |
            kubectl wait --for=condition=ready pod \\
              -l app=erp-postgres \\
              -n default --timeout=300s
```

---

## Helmfile Testing Strategy

### Level 1: Template validation (local, no cluster)

```bash
#!/bin/bash
for chart in output/charts/*/; do
  helm template "$chart" || exit 1
done
```

### Level 2: Dry-run on cluster

```bash
helmfile -f output/helmfile.yaml --dry-run sync
```

### Level 3: Full sync + rollout wait

```bash
helmfile -f output/helmfile.yaml sync
helmfile -f output/helmfile.yaml status
```

### Level 4: Upgrade validation

```bash
# First release
helmfile -f output/helmfile.yaml sync

# Edit charts/values
<modify output/charts/erp-api/values.yaml>

# Sync again (exercises upgrade path)
helmfile -f output/helmfile.yaml sync

# Verify no broken releases
helmfile -f output/helmfile.yaml status
```

---

## Troubleshooting

### Issue: `needs` dependency doesn't resolve

**Symptom**: `helmfile sync` fails with "Release X not found in this state"

**Cause**: Release name was overridden or namespace differs from expectation

**Fix**: Verify release name in helmfile.yaml matches the `needs` entry:
```yaml
releases:
  - name: erp-postgres     ← exact name used in 'needs'
    namespace: default
    
  - name: erp-api
    needs:
      - erp-postgres       ← must match exactly
```

### Issue: Template rendering errors

**Symptom**: `helm template` fails with "error executing template"

**Cause**: Generated `values.yaml` has values that don't match template expectations

**Fix**: Validate values structure:
```bash
helm template charts/erp-api
helm lint charts/erp-api
```

### Issue: Storage class doesn't exist

**Symptom**: PVC stays Pending: "storageclass.storage.k8s.io ... not found"

**Cause**: Wrong storageClassName for the cluster

**Fix**: 
```bash
# Check available classes
kubectl get storageclass

# Update helmfile.yaml
releases:
  - name: erp-postgres
    values:
      - storageClassName: rook-ceph-block
```

---

## Relationship to Other Output Formats

| Format | Use For | Orchestration |
|--------|---------|---------------|
| **Helmfile** | Coordinated Helm charts, multi-release orchestration | helmfile (this guide) |
| **Helm** | Single chart distribution, library use | helm CLI directly |
| **YAML** | Plain K8s files, ArgoCD/Flux, compliance | kubectl/gitops tools |
| **Crossplane** | Infrastructure composition, multi-cluster provisioning | Crossplane API |
| **Kustomize** | Declarative K8s overlays, patches | kustomize build |

---

## See Also

- **Framework Builders**: `docs/FRAMEWORK_SCHEMAS.md` — how modules generate manifests
- **KCL Patterns**: `.github/instructions/framework-builders.instructions.md` — templates and module schema
- **Helmfile Official**: https://helmfile.readthedocs.io/
- **Helm Documentation**: https://helm.sh/docs/

---

**Last Updated**: June 2026
**Next Review**: When new template types or storage patterns are added

