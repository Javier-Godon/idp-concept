# Helmfile & Crossplane V2 Adoption Guide

**Edition**: June 7, 2026  
**Target Audiences**: Platform Engineers, Infrastructure Teams, Operators  
**Scope**: Production-Ready Multi-Format Output Generation

---

## Quick Start: Choosing Your Output Format

### Decision Tree

```
START: "I need to deploy infrastructure and applications"
  │
  ├── Q1: "Do you want GitOps with ArgoCD?"
  │   ├── YES → Use YAML + ArgoCD format
  │   │          Command: koncept render yaml
  │   │          Next: Commit to Git repo for ArgoCD
  │   │
  │   └── NO → Go to Q2
  │
  ├── Q2: "Do you need Helm chart management?"
  │   ├── YES → Use Helmfile format
  │   │          Command: koncept render helmfile
  │   │          Next: Use "helmfile sync" for deployment
  │   │
  │   └── NO → Go to Q3
  │
  ├── Q3: "Do you want Infrastructure-as-Code with Kubernetes APIs?"
  │   ├── YES → Use Crossplane V2 format
  │   │          Command: koncept render crossplane
  │   │          Next: Use "kubectl apply -f" for infrastructure provisioning
  │   │
  │   └── NO → Use YAML for manual kubectl deployment
  │
  └── Q4: "Do you want both?"
      └── YES → Render both and use for different purposes:
               - Helmfile for Helm-based services
               - Crossplane for infrastructure provisioning
               - Both can coexist in the same cluster
```

---

## Helmfile Adoption Path

### What is Helmfile?

Helmfile is a declarative interface for managing multiple Helm charts. Each "release" in a Helmfile represents a Helm chart deployment. Helmfile orchestrates:

- Chart installation order (via `needs` dependencies)
- Shared values inheritance (via `defaults`)
- Environment-specific configurations (via `environments`)
- Multi-repository chart sources

### When to Use Helmfile

✅ **Good fit for:**

- Applications already packaged as Helm charts (databases, message queues, SaaS connectors)
- Multi-chart deployments where orchestration order matters
- Teams already familiar with Helm chart values + overrides
- Want separation between infrastructure (managed separately) and applications (via Helmfile)

❌ **Not ideal for:**

- Custom application containers not in Helm charts yet
- Low-level Kubernetes primitives not packaged as charts
- Want single unified Kubernetes manifest (use YAML/ArgoCD instead)

### Helmfile Rendering from KCL

```bash
# Step 1: Navigate to your factory directory
cd projects/your_project/pre_releases/manifests/dev/factory

# Step 2: Render helmfile
/path/to/koncept render helmfile

# Step 3: Check generated output
cat ../output/helmfile.yaml
head -20 ../output/charts/*/values.yaml

# Step 4: Deploy with Helmfile
helmfile sync

# Step 5: Verify deployment
helmfile status
helm list -A
```

### Advanced Helmfile Configuration

The idp-concept framework allows you to customize Helmfile output via `HelmfileRenderOptions` in your stack:

```kcl
import framework.templates.webapp.v1_0_0.webapp
import framework.templates.postgresql.v1_0_0.postgresql
import framework.custom.helmfile.helmfile as hf
import framework.procedures.kcl_to_helmfile as helmfile_proc

# Define your stack normally
_stack = RenderStack {
    components = [
        _app_instance,
    ]
    accessories = [
        _postgres_instance,
    ]
    
    # NEW: Customize Helmfile generation
    helmfile = hf.HelmfileRenderOptions {
        # Add extra repositories
        repositories = [
            { name = "bitnami", url = "https://charts.bitnami.com/bitnami" }
        ]
        
        # Add extra releases not generated from stack
        extraReleases = [
            { 
                name = "my-operator"
                namespace = "operators"
                chart = "bitnami/my-operator"
                version = "1.2.3"
            }
        ]
        
        # Override specific release options
        releaseOverrides = {
            "my-app" = hf.ReleasePatch {
                version = "2.0.0"
                values = ["path/to/custom/values.yaml"]
                needs = ["postgres/my-db"]  # Explicit dependencies
            }
        }
        
        # Global helmfile options
        helmDefaults = {
            atomic = True
            wait = True
            timeout = 600
        }
    }
}

# Render normally
_helmfile = helmfile_proc.generate_helmfile_from_stack(_stack)
manifests.yaml_stream([_helmfile])
```

### Helmfile Integration Testing

Verify your Helmfile renders correctly before deploying:

```bash
# Run Helmfile validation with real Helm templating
./scripts/helmfile_helm_integration_test.sh

# This will:
# 1. Validate helmfile.yaml syntax
# 2. Run "helm template" on each release
# 3. Validate generated YAML with kubeconform
# 4. Detect dependency mismatches
# 5. Report any chart fetch failures
```

### Troubleshooting Helmfile Issues

| Problem | Diagnosis | Solution |
|---------|-----------|----------|
| Release order wrong | Check `needs` entries | Update `releaseOverrides.needs` in stack config |
| Chart not found | Check chart paths and versions | Verify `repositories` + chart names in `releaseOverrides` |
| Values not applying | Check values file paths | Ensure values.yaml paths are correct relative to helmfile.yaml |
| Namespace conflicts | Check release namespaces | Use `releaseOverrides.namespace` to set correct namespace |

---

## Crossplane V2 Adoption Path

### What is Crossplane?

Crossplane is a Kubernetes-native infrastructure-as-code system that allows you to:

- Define infrastructure services using **Kubernetes Custom Resources** (XRs = Composite Resources)
- Manage infrastructure **lifecycle** (create, update, delete) via kubectl
- Orchestrate dependencies between infrastructure components
- Audit infrastructure changes via Kubernetes RBAC and audit logs

### When to Use Crossplane

✅ **Good fit for:**

- Infrastructure services (databases, message queues, object storage, identity providers)
- Multi-tenant, multi-environment infrastructure provisioning
- Teams already comfortable with `kubectl apply` and Kubernetes APIs
- Want centralized audit trail and RBAC for infrastructure changes
- Want to treat infrastructure as code via GitOps

❌ **Not ideal for:**

- One-off infrastructure (prefer direct provider CLI)
- Simple single-service deployments (overhead of Crossplane setup)
- Teams not familiar with Kubernetes operators

### Crossplane V2 Architecture

The idp-concept Crossplane implementation follows a **"two-track" model**:

```
Track 1: Generated Bridge (from kcl_to_crossplane procedure)
  ├─ Wraps finalized Kubernetes manifests in Crossplane Objects
  ├─ Used for quick iteration and testing
  └─ Suitable for all manifest types (apps, all infrastructure)

Track 2: Hand-Authored Managed Resources (in crossplane_v2/managed_resources/)
  ├─ Intent-level XRD/Composition/XR APIs for major services
  ├─ Direct operator integration (MongoDB, PostgreSQL, Redis, etc.)
  ├─ Production-recommended path
  └─ Curated subset (infrastructure only, no application workloads)
```

### Crossplane Rendering from KCL

```bash
# Step 1: Navigate to your factory directory
cd projects/your_project/pre_releases/manifests/dev/factory

# Step 2: Render Crossplane output
/path/to/koncept render crossplane

# Step 3: Check generated output
cat ../output/crossplane/xrd.yaml      # API definition
cat ../output/crossplane/composition.yaml  # Implementation
cat ../output/crossplane/xr.yaml      # Instance

# Step 4: Install prerequisites (providers + functions)
kubectl apply -f ../output/crossplane/prerequisites/providers.yaml
kubectl apply -f ../output/crossplane/prerequisites/functions.yaml

# Step 5: Install the managed resources
kubectl apply -f ../output/crossplane/xrd.yaml
kubectl apply -f ../output/crossplane/composition.yaml
kubectl apply -f ../output/crossplane/xr.yaml

# Step 6: Monitor deployment
kubectl get compositions
kubectl get xrs
kubectl describe xr my-stack-workload
```

### Using Curated Managed Resource APIs

The idp-concept framework includes hand-authored Crossplane APIs for common infrastructure services:

```bash
# PostgreSQL database
kubectl apply -f crossplane_v2/managed_resources/postgres/xrd_postgres.yaml
kubectl apply -f crossplane_v2/managed_resources/postgres/x_postgres.yaml
kubectl apply -f crossplane_v2/managed_resources/postgres/xr_instance_postgres.yaml

# MongoDB cluster
kubectl apply -f crossplane_v2/managed_resources/mongodb/xrd_mongodb.yaml
kubectl apply -f crossplane_v2/managed_resources/mongodb/x_mongodb.yaml
kubectl apply -f crossplane_v2/managed_resources/mongodb/xr_instance_mongodb.yaml

# Redis cache
kubectl apply -f crossplane_v2/managed_resources/redis/xrd_redis.yaml
kubectl apply -f crossplane_v2/managed_resources/redis/x_redis.yaml
kubectl apply -f crossplane_v2/managed_resources/redis/xr_instance_redis.yaml

# ... and others (RabbitMQ, Keycloak, OpenSearch, MinIO, Vault, QuestDB, Elasticsearch)
```

### Crossplane Runtime Validation

Verify your Crossplane configuration before deploying:

```bash
# Static validation (local)
koncept crossplane test

# With dry-run verification
koncept crossplane test --profile smoke

# With full lifecycle testing (requires cluster)
koncept crossplane test --profile lifecycle

# With progressive validation matrix
koncept crossplane test --runtime-matrix-from smoke --runtime-matrix-stop-on api-lifecycle
```

### Crossplane Troubleshooting

| Problem | Diagnosis | Solution |
|---------|-----------|----------|
| XR stuck in "Creating" | Check Composition pipeline | `kubectl logs -n crossplane-system -l app=crossplane` |
| Resource dependencies fail | Check sequencer rules | Verify resource naming in generated XR.spec.resources |
| Provider not installed | List installed providers | `kubectl get providers.pkg.crossplane.io` |
| Function missing | Check function packages | `kubectl get functions.pkg.crossplane.io` |

---

## Side-by-Side: Helmfile vs Crossplane

### Scenarios Where Each Excels

| Scenario | Helmfile | Crossplane | Reason |
|----------|----------|-----------|--------|
| Deploy a Helm chart | ✅ Native | ⚠️ Wrapper | Helmfile is the direct Helm interface |
| Multi-chart orchestration | ✅ Built-in | ⚠️ Complex | Helmfile has native `needs` support |
| Infrastructure provisioning | ❌ Not ideal | ✅ Native | Crossplane is designed for infra-as-code |
| Multi-tenant isolation | ⚠️ Manual | ✅ Built-in | Crossplane has native RBAC + claims |
| Audit trail | ⚠️ Limited | ✅ Full | Crossplane stores everything in etcd |
| GitOps + infrastructure | ⚠️ Separate | ✅ Unified | Crossplane uses same Git/kubectl flow |

### Using Both Simultaneously

It's common to use **both** in the same cluster:

```bash
# Applications + platform services via Helmfile
helmfile sync

# Infrastructure provisioning via Crossplane
kubectl apply -f crossplane/xrd.yaml
kubectl apply -f crossplane/composition.yaml
kubectl apply -f crossplane/xr.yaml
```

Example: PostgreSQL as managed resource (Crossplane) + application Helm charts (Helmfile)

```
User Application (Helmfile)
    ↓ (depends on)
PostgreSQL Service (Crossplane XR)
```

---

## Production Deployment Patterns

### Pattern 1: GitOps with ArgoCD + Helmfile

```yaml
# argocd/Application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/company/platform
    targetRevision: main
    path: projects/my-project/pre_releases/manifests/dev/output
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Deploy helmfile via ArgoCD:

```bash
# ArgoCD will sync the helmfile.yaml, triggering helmfile sync
git push origin main
# → ArgoCD detects change
# → ArgoCD applies helmfile.yaml
# → Helmfile syncs all releases
```

### Pattern 2: Infrastructure Provisioning with Crossplane

```bash
# 1. Install Crossplane core
helm repo add crossplane-stable https://charts.crossplane.io
helm install crossplane --namespace crossplane-system xpkg.upbound.io/upbound/xp

# 2. Apply platform prerequisites
kubectl apply -f crossplane_v2/providers/
kubectl apply -f crossplane_v2/functions/

# 3. Apply managed resource definitions
kubectl apply -f crossplane_v2/managed_resources/postgres/
kubectl apply -f crossplane_v2/managed_resources/mongodb/

# 4. Teams provision infrastructure via Kubernetes API
kubectl create namespace app-team
kubectl apply -f app-team-postgres.yaml  # Creates PostgreSQL instance
kubectl apply -f app-team-mongodb.yaml   # Creates MongoDB instance

# 5. Monitor provisioning
kubectl get xpostgresinstances -A
kubectl get xmongodbinstances -A
```

### Pattern 3: Unified Stack (Helmfile + Crossplane)

```bash
# Render both
koncept render helmfile
koncept render crossplane

# Deploy infrastructure first
kubectl apply -f output/crossplane/

# Deploy applications via infrastructure-aware Helmfile
helmfile sync
```

---

## Governance & Observability

### Metadata Propagation

Both Helmfile and Crossplane outputs include rich governance metadata:

**Helmfile Labels**:

```yaml
labels:
  owner: platform-team
  team: infrastructure
  lifecycle: production
  sloTier: tier-1
  criticality: high
commonLabels:  # Applied to all resources
  owner: platform-team
  # ... etc
```

**Crossplane Annotations**:

```yaml
metadata:
  annotations:
    koncept.io/owner: platform-team
    koncept.io/team: infrastructure
    koncept.io/lifecycle: production
    # ... etc
```

### Resource Footprint Planning

Use dry-run to preview resource requirements before deployment:

```bash
# Preview resource footprint
koncept dry-run

# Output includes:
# - Manifest count (Deployments, StatefulSets, PVCs, etc.)
# - CPU + memory estimates
# - Storage footprint
# - Resource warnings (missing limits, etc.)
```

---

## Troubleshooting & Support

### Common Issues

**Issue: `helmfile sync` fails with "chart not found"**

```bash
# Solution 1: Verify charts were generated
ls -la output/charts/

# Solution 2: Ensure chart paths in helmfile.yaml are correct
cat output/helmfile.yaml | grep chart:

# Solution 3: Check that values.yaml exists for each chart
ls -la output/charts/*/values.yaml
```

**Issue: Crossplane XR stuck in "Waiting for resources"**

```bash
# Diagnosis 1: Check Crossplane controller logs
kubectl logs -n crossplane-system -l app=crossplane -f

# Diagnosis 2: Check specific resource status
kubectl describe xr my-stack-workload

# Diagnosis 3: Check if providers are installed
kubectl get providers.pkg.crossplane.io

# Diagnosis 4: Check if functions are installed
kubectl get functions.pkg.crossplane.io
```

### Getting Help

1. Check `docs/HELMFILE_ORCHESTRATION.md` for Helmfile details
2. Check `docs/CROSSPLANE_PATTERNS.md` for Crossplane architecture
3. Check `crossplane_v2/QUICK_REFERENCE.md` for API reference
4. Run `koncept --help` for CLI support

---

## Next Steps

1. ✅ **Choose format**: Decide Helmfile vs Crossplane (or both)
2. ✅ **Render output**: Use `koncept render {helmfile|crossplane}`
3. ✅ **Validate**: Run integration tests before deploying
4. ✅ **Deploy**: Use helmfile sync or kubectl apply
5. ✅ **Monitor**: Verify releases or XRs are healthy
6. ✅ **Iterate**: Update stack and re-render

---

**Document last updated**: June 7, 2026  
**Maintained by**: Platform Engineering Team
