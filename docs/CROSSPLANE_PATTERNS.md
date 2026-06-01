# Crossplane Patterns for idp-concept

> This document describes the Crossplane composition patterns expected for `crossplane_v2/` and the generated Crossplane output.
> References: https://docs.crossplane.io/, https://github.com/crossplane-contrib, https://github.com/vfarcic/crossplane-kubernetes, https://github.com/upbound/platform-ref-aws

---

## 1. Architecture Overview

The Crossplane layer provides **Kubernetes-native platform APIs** for infrastructure and platform services. It must not be treated as another place to copy rendered Kubernetes manifests. A professional Crossplane integration exposes typed XRDs, reconciles provider-native managed resources where possible, uses composition functions for reusable logic, and proves that deployed XRs can be observed, upgraded, rolled back, and debugged.

```
┌──────────────────────────────────────────────────┐
│              Platform APIs (XRDs + Claims)        │
│  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ XCertManager │  │ PostgresCompositeWorkload │  │
│  │ XKafkaStrimzi│  │ XKeycloak                 │  │
│  └──────┬───────┘  └──────────┬───────────────┘  │
│         │  Compositions       │                   │
│  ┌──────▼───────────────────▼─────────────────┐  │
│  │          Pipeline Functions                  │  │
│  │  function-kcl / function-go-templating      │  │
│  │  patch-and-transform / environment-configs  │  │
│  │  sequencer / auto-ready                     │  │
│  └───────────────────┬────────────────────────┘  │
│                      │ Providers / GitOps         │
│  ┌───────────────────▼────────────────────────┐  │
│  │ provider-native MR │ provider-helm          │  │
│  │ provider-kubernetes only for cluster glue   │  │
│  └─────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

---

## 2. API Groups

| Group | Purpose | Resources |
|---|---|---|
| `koncept.bluesolution.es` | Platform infrastructure | XCertManager, XKafkaStrimzi, XKeycloak |
| `gitops.bluesolution.es` | GitOps-oriented infrastructure | PostgresCompositeWorkload |

---

## 3. XRD (CompositeResourceDefinition) Pattern

XRDs define the custom API that platform users interact with.

### Design Rules

- Model **intent**, not implementation YAML. Inputs should describe database size, HA mode, version, backup policy, exposure, SLO tier, environment, and ownership; they should not expose raw `manifest` blobs.
- Prefer `scope: Namespaced` plus `claimNames` for tenant-facing APIs. Use `scope: Cluster` only for platform-owned global infrastructure.
- Use OpenAPI validation aggressively: `required`, `enum`, `default`, `minimum`, `maximum`, descriptions, and nested objects for related settings.
- Add `additionalPrinterColumns` for the fields operators need during `kubectl get`: version, namespace, Ready/synced status, endpoint, revision, and age.
- Add status fields with `ToCompositeFieldPath` or function-generated status updates so the XR shows the important outputs without digging through composed resources.
- Version the API deliberately: start at `v1alpha1`, add conversion/migration notes before `v1beta1`, and keep exactly one `referenceable: true` version per XRD.
- Define connection details explicitly. Crossplane v2 XRs should compose or aggregate a Secret intentionally instead of relying on implicit v1-style connection secret behavior.

### Template
```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: x<resource>s.<group>.bluesolution.es
spec:
  group: <group>.bluesolution.es
  names:
    kind: X<Resource>
    plural: x<resource>s
  # Optional: claimNames for namespace-scoped claims
  claimNames:
    kind: <Resource>
    plural: <resource>s
  scope: Cluster
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                namespace:
                  type: string
                # Add resource-specific properties here
```

### Examples in Project and Maturity Target

**cert-manager XRD** (`xrd_cert_manager.yaml`):
```yaml
spec:
  properties:
    namespace:
      type: string
```

**Keycloak XRD** (`xrd_keycloak.yaml`):
```yaml
spec:
  properties:
    hostname:
      type: string
      description: Base hostname for Keycloak ingress.
    replicas:
      type: integer
      default: 1
    namespace:
      type: string
    label:
      type: object
      properties:
        namespace:
          type: string
  required:
    - hostname
```

**PostgreSQL XRD** (`xrd_postgres.yaml`):
```yaml
spec:
  properties:
    namespace:
      type: string
    label:
      type: object
      properties:
        postgresNamespace:
          type: string
```

These examples are useful as early XRD sketches, but the target is richer typed APIs with defaults, enums, status, printer columns, and connection-secret contracts before any resource is promoted as a supported platform API.

---

## 4. Composition Pattern (Pipeline Mode)

All compositions use `mode: Pipeline` with function steps.

### Function Selection

| Need | Preferred function | Notes |
|---|---|---|
| Type-safe composition logic, package reuse, IDP model reuse | `function-kcl` | Preferred for complex platform APIs because this project already uses KCL as the platform language. Use pinned OCI/Git sources for production packages. |
| Template-heavy resource generation, loops, ExtraResources, context writes | `function-go-templating` | Good for Helm-like composition logic and XR status updates. |
| Simple field mapping and transforms | `function-patch-and-transform` | Use for straightforward provider-native managed resource patching, not for embedding large raw manifests. |
| Cross-step ordering | `function-sequencer` | Use when resources have explicit creation/deletion dependencies. |
| Readiness | `function-auto-ready` | Keep as the final readiness step unless a custom readiness contract is required. |
| Business-specific reconciliation logic | Custom Go function using `function-sdk-go` | Use only when KCL/templates/P&T cannot express the behavior clearly; must include Go unit tests and `crossplane render` fixtures. |

### Template
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: x<resource>-composition
spec:
  compositeTypeRef:
    apiVersion: <group>.bluesolution.es/v1alpha1
    kind: X<Resource>
  mode: Pipeline
  pipeline:
    - step: <step-name>
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: <resource-name>
            base:
              # Kubernetes Object or Helm Release
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.<field>
                toFieldPath: spec.forProvider.<target>
    - step: automatically-detect-readiness
      functionRef:
        name: function-auto-ready
```

### Pattern 1: Provider-Native Managed Resources (Preferred)

Use provider-native managed resources whenever Crossplane has a provider for the thing being managed: Upbound/AWS/GCP/Azure resources, provider-helm `Release` for off-the-shelf charts, or operator CRs when the operator owns the real reconciliation.

```yaml
- name: database
  base:
    apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    spec:
      instances: 1
      storage:
        size: 10Gi
  patches:
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.instances
      toFieldPath: spec.instances
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.storageSize
      toFieldPath: spec.storage.size
```

When the managed resource is not a Crossplane provider CRD, prefer an operator CRD or Helm Release with a typed values contract over rendering an entire application Deployment as an opaque nested manifest.

### Pattern 2: Function-Generated Resources

Use `function-kcl` or `function-go-templating` when the composition needs conditional resources, list expansion, defaulting beyond OpenAPI, reusable libraries, status updates, or connection-secret assembly.

```yaml
- step: render-platform-resources
  functionRef:
    name: function-kcl
  input:
    apiVersion: krm.kcl.dev/v1alpha1
    kind: KCLInput
    spec:
      source: oci://registry.example.com/idp/crossplane-postgres:v1.0.0
      run:
        sortKeys: true
        disableNone: true
- step: automatically-detect-readiness
  functionRef:
    name: function-auto-ready
```

Production function sources must be version pinned. Inline sources are acceptable for experiments and small examples, but supported APIs should move composition logic into reviewed, tested, versioned function packages.

### Pattern 3: Helm Release

Used for installing applications via Helm charts:

```yaml
- name: cert-manager-helm-release
  base:
    apiVersion: helm.crossplane.io/v1beta1
    kind: Release
    metadata:
      name: cert-manager
    spec:
      providerConfigRef:
        name: helm-provider
      forProvider:
        chart:
          name: cert-manager
          repository: https://charts.jetstack.io
          version: "v1.17.2"
        set:
          - name: installCRDs
            value: "true"
  patches:
    - type: FromCompositeFieldPath
      fromFieldPath: spec.namespace
      toFieldPath: spec.forProvider.namespace
```

### Pattern 4: Kubernetes Object (Restricted)

`provider-kubernetes` `Object` is allowed only for narrow cluster glue:

- Namespaces and lightweight RBAC needed by the composition.
- Bootstrap CRDs or operator-owned custom resources when no provider-native or Helm abstraction exists.
- Crossplane/provider bootstrap resources managed by the platform team.
- Temporary migration bridges with a documented removal path.

It is an anti-pattern to wrap full application Deployments, Services, ConfigMaps, or copied CRDs as large `Object.spec.forProvider.manifest` blobs. That creates nested reconciliation, hides status, weakens schema validation, and makes drift/debugging harder.

### Pattern 5: Multi-Step Pipeline

Used for resources that need ordered creation (e.g., namespace before deployment):

```yaml
pipeline:
  - step: create-namespace
    functionRef:
      name: function-patch-and-transform
    input:
      resources:
        - name: namespace
          base:
            apiVersion: kubernetes.crossplane.io/v1alpha2
            kind: Object
            spec:
              forProvider:
                manifest:
                  apiVersion: v1
                  kind: Namespace
  - step: automatically-detect-readiness
    functionRef:
      name: function-auto-ready
  - step: create-workload
    functionRef:
      name: function-patch-and-transform
    input:
      resources:
        - name: deployment
          base:
            # ... deployment definition
```

---

## 5. XR Instance (Claim) Pattern

Create instances of the composite resources. Prefer namespace-scoped Claims for product teams and reserve cluster-scoped XRs for platform-owned operations.

```yaml
apiVersion: koncept.bluesolution.es/v1alpha1
kind: XCertManager
metadata:
  name: cert-manager-workload
spec:
  namespace: cert-manager
```

```yaml
apiVersion: koncept.bluesolution.es/v1alpha1
kind: XKeycloak
metadata:
  name: blue-keycloak
spec:
  hostname: bluesolution.es
  replicas: 1
  namespace: keycloak
  label:
    namespace: keycloak
```

---

## 5.1 Connection Details and Status

Crossplane v2 compositions must model connection and status data explicitly:

- Composed managed resources that produce credentials should write to their own Secrets.
- The composition should aggregate the fields it exposes to consumers into a deliberate connection Secret.
- Secret names and namespaces should be derived from XR fields or safe defaults, never hardcoded credentials.
- XR status should surface operationally useful values such as endpoint, selected version, composed resource names, and readiness summary.
- Do not require users to inspect nested `Object.spec.forProvider.manifest.status`; if an output matters, patch or write it to the XR status.

---

## 6. Patch Types

| Patch Type | Direction | Usage |
|---|---|---|
| `FromCompositeFieldPath` | XR → Resource | Inject values from the claim into resources |
| `ToCompositeFieldPath` | Resource → XR | Expose resource values back to the claim |
| `CombineFromComposite` | Multiple XR fields → Resource | Combine fields into one |

### Standard Patch (Most Common)
```yaml
patches:
  - type: FromCompositeFieldPath
    fromFieldPath: spec.namespace
    toFieldPath: spec.forProvider.manifest.metadata.namespace
```

### Required Policy
```yaml
patches:
  - fromFieldPath: "spec.label.postgresNamespace"
    toFieldPath: "spec.forProvider.manifest.metadata.namespace"
    policy:
      fromFieldPath: "Required"  # Fail if field is missing
```

---

## 7. Provider Configuration

### Kubernetes Provider
```yaml
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: provider-kubernetes
spec:
  credentials:
    source: InjectedIdentity
```

### Helm Provider
```yaml
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: helm-provider
spec:
  credentials:
    source: InjectedIdentity
```

Both use `InjectedIdentity` — the provider runs in-cluster and uses the service account's permissions.

### Provider Selection Rules

| Resource class | Preferred approach | Avoid |
|---|---|---|
| Cloud infrastructure | Provider-native managed resources (`provider-family-aws`, `provider-family-gcp`, `provider-family-azure`, etc.) | Kubernetes `Object` wrappers for cloud-facing YAML |
| Off-the-shelf operator/app chart | `provider-helm` `Release` with a typed values contract | Copying chart-rendered manifests into `Object` |
| Operator-managed platform service | The operator CRD patched by a composition function or P&T | Reimplementing operator internals as raw Kubernetes resources |
| Application workloads | GitOps/Tier-1 YAML or a dedicated operator API | Crossplane wrapping every Deployment/Service |
| Cluster glue | `provider-kubernetes` `Object`, kept small and reviewed | Large opaque manifests or copied CRD catalogs |

---

## 8. Functions Reference

| Function | Version | API | Purpose |
|---|---|---|---|
| `function-patch-and-transform` | v0.9.0 | `pt.fn.crossplane.io/v1beta1` | Primary resource creation and patching |
| `function-auto-ready` | v0.5.0 | — | Automatically detect when composed resources are ready |
| `function-go-templating` | v0.10.0 | — | Go template-based resource rendering |
| `function-kcl` | v0.11.4 | — | KCL-based resource rendering |
| `function-sequencer` | v0.2.3 | — | Order pipeline steps |

Use these versions as the current project baseline, then pin exact package versions in installed `Function` resources. Do not use floating function package tags.

---

## 8.1 Local Rendering and Tests

No Crossplane v2 API is considered supported until it has tests at these levels:

| Level | Required proof |
|---|---|
| Static render | `koncept render crossplane` or `kcl run ... -D output=crossplane` produces XRD, Composition, XR, prerequisites, and no forbidden large `Object` wrappers. |
| Local composition render | `crossplane render xr.yaml composition.yaml functions.yaml --include-function-results` succeeds and shows expected desired composed resources. Use `--observed-resources`, `--required-resources`, `--context-files`, or `--context-values` for scenarios that need observed state. |
| Schema/API checks | XRD OpenAPI has required fields, defaults, enums where appropriate, descriptions, printer columns, and status/connection fields. |
| Reconciliation test | A kind or real test cluster installs Crossplane, pinned providers/functions, applies the package, creates an XR/Claim, and verifies Synced/Ready plus expected composed resources. |
| Management test | The test updates a field, verifies the composed resource changes, then deletes the XR/Claim and verifies composed resources are cleaned up or intentionally orphaned. |
| Drift/upgrade test | Composition changes are rendered through golden snapshots and, for supported APIs, tested against composition revisions or pinned `compositionRevisionRef` rollback. |

Recommended tooling:

- `crossplane render` for local function pipeline previews.
- Chainsaw or KUTTL for cluster reconciliation tests.
- Go tests for any custom composition function written with `function-sdk-go`.
- A future `koncept crossplane test` command should wrap the repository's standard render, lint, `crossplane render`, and optional cluster reconciliation checks so platform engineers have one supported entrypoint.

---

## 9. Managed Resources in This Project

| Resource | XRD | Composition | Key Infrastructure |
|---|---|---|---|
| **cert-manager** | `xcertmanagers.koncept.bluesolution.es` | Namespace + Helm Release | Jetstack cert-manager v1.17.2 |
| **Kafka (Strimzi)** | `xkafkastrimzis.koncept.bluesolution.es` | Helm Release (Strimzi operator) | Strimzi 0.46.0 OCI chart |
| **Keycloak** | `xkeycloaks.koncept.bluesolution.es` | Namespace + Auto-ready + CRD instance | Keycloak CRD (keycloak-operator 26.4.0) |
| **PostgreSQL** | `postgrescompositeworkloads.gitops.bluesolution.es` | Namespace + PVC + ConfigMaps + Deployment + Service | postgres:18-alpine3.22 |

---

## 10. Adding a New Crossplane Managed Resource

1. **Create XRD** (`xrd_<resource>.yaml`):
   - Define the API group, kind, scope, claimNames, versions, schema, defaults, descriptions, status, connection contract, and printer columns.
   - Include only intent-level configurable properties. Do not accept arbitrary raw manifests.

2. **Create Composition** (`x_<resource>.yaml`):
   - Reference the XRD via `compositeTypeRef`
   - Use Pipeline mode with function steps.
   - Prefer provider-native managed resources, Helm Release, operator CRDs, KCL/go-templating logic, and P&T patches.
   - Use provider-kubernetes Object only for small reviewed cluster glue.

3. **Create Instance** (`xr_instance_<resource>.yaml`):
   - Instantiate the XR or Claim with concrete values and expected status/connection outcomes.

4. **Register Functions** (if new functions needed):
   - Add function YAML in `functions/`
   - Pin exact package versions.

5. **Add tests before support**:
   - Static render test.
   - `crossplane render` fixture.
   - Cluster reconciliation/update/delete test for supported APIs.
   - Golden snapshot or equivalent drift gate for generated Crossplane output.

---

## 11. Common Mistakes (AI Hints)

| Mistake | Correct Pattern |
|---|---|
| Using `apiVersion: apiextensions.crossplane.io/v1` for XRDs | Use `v2` for newer XRDs |
| Missing `providerConfigRef` | Always specify `provider-kubernetes` or `helm-provider` |
| Not using `mode: Pipeline` | All compositions in this project use Pipeline mode |
| Copying Deployments, Services, ConfigMaps, or CRDs into `Object.spec.forProvider.manifest` | Use provider-native resources, Helm Release, operator CRDs, or function-generated typed resources; keep `Object` only for narrow cluster glue |
| Missing `function-auto-ready` step | Add as the last step for readiness detection |
| Helm Release without namespace patch | Always patch namespace from composite field |
| Exposing raw YAML fields in the XRD | Expose intent-level fields with OpenAPI validation, defaults, and descriptions |
| No update/delete test | Prove Crossplane can manage the resource lifecycle after initial creation |

---

## 12. Automated Crossplane Output (Current State and Target)

The manual `crossplane_v2/` directory contains hand-crafted compositions. The automated Crossplane output currently generates XRDs, Compositions, and XRs directly from stack definitions.

### Usage
```bash
cd projects/<project>/pre_releases/<release>
koncept render crossplane
```

This generates:
- `output/crossplane/xrd.yaml` — CompositeResourceDefinition with `koncept.bluesolution.es/v1alpha1`
- `output/crossplane/composition.yaml` — Pipeline composition (patch-and-transform → function-sequencer → auto-ready)
- `output/crossplane/xr.yaml` — Composite Resource claim instance
- `output/crossplane/prerequisites/infrastructure.yaml` — Provider + function installs

### How It Works
1. **KCL resolves** all configurations (kernel → profile → tenant → site merge)
2. **Stack modules** produce finalized K8s manifests
3. **`kcl_to_crossplane`** wraps each manifest in a `kubernetes.crossplane.io/v1alpha2 Object`
4. **`dependsOn`** ordering maps to `function-sequencer` rules with regex patterns
5. **Output** is static YAML — no in-cluster KCL execution needed

### Current Advantages
- **Automatic ordering** via function-sequencer (derived from `dependsOn`)
- **All module types** supported: namespaces, components, accessories, third-party
- **Consistent** with other output formats (same stack → different outputs)
- **Tested**: procedure tests in `framework/tests/procedures/crossplane_test.k`

### Maturity Gap

This output is still a bridge, not the final professional Crossplane model, when it wraps finalized Kubernetes manifests in `provider-kubernetes` Objects. The target is:

- Generate or maintain typed XRDs that expose platform intent, not rendered YAML.
- Map IDP modules to provider-native managed resources, Helm Releases, or operator CRDs wherever available.
- Move complex composition logic into versioned `function-kcl`, `function-go-templating`, or custom Go function packages.
- Keep provider-kubernetes Objects only for namespaces, small RBAC/bootstrap glue, or temporary compatibility bridges.
- Add Crossplane-specific tests that prove reconcile/update/delete behavior, not only render shape.

---

## 13. Reference Projects and Sources

- Official Crossplane docs: https://docs.crossplane.io/
- Composition functions: https://docs.crossplane.io/latest/composition/compositions/
- Function patch-and-transform: https://github.com/crossplane-contrib/function-patch-and-transform
- Function KCL: https://github.com/crossplane-contrib/function-kcl
- Function Go templating: https://github.com/crossplane-contrib/function-go-templating
- Function SDK for Go: https://github.com/crossplane/function-sdk-go
- Practitioner KCL-heavy Crossplane reference: https://github.com/vfarcic/crossplane-kubernetes
- Upbound AWS platform reference: https://github.com/upbound/platform-ref-aws
