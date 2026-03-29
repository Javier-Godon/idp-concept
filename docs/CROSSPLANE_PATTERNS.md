# Crossplane Patterns for idp-concept

> This document describes the Crossplane composition patterns used in `crossplane_v2/`.
> Reference: https://docs.crossplane.io/

---

## 1. Architecture Overview

The Crossplane layer provides **Kubernetes-native infrastructure provisioning** as an alternative to the KCL-generated manifests. Instead of generating YAML files externally, Crossplane defines custom APIs (XRDs) and compositions that create resources directly on the cluster.

```
┌──────────────────────────────────────────────────┐
│              Custom APIs (XRDs)                   │
│  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ XCertManager │  │ PostgresCompositeWorkload │  │
│  │ XKafkaStrimzi│  │ XKeycloak                 │  │
│  └──────┬───────┘  └──────────┬───────────────┘  │
│         │  Compositions       │                   │
│  ┌──────▼───────────────────▼─────────────────┐  │
│  │          Pipeline Functions                  │  │
│  │  patch-and-transform │ auto-ready           │  │
│  │  go-templating       │ kcl                  │  │
│  │  sequencer                                  │  │
│  └───────────────────┬────────────────────────┘  │
│                      │ Providers                  │
│  ┌───────────────────▼────────────────────────┐  │
│  │ provider-kubernetes │ provider-helm          │  │
│  │  (InjectedIdentity)  (InjectedIdentity)     │  │
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

### Examples in Project

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

---

## 4. Composition Pattern (Pipeline Mode)

All compositions use `mode: Pipeline` with function steps.

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

### Pattern 1: Kubernetes Object (Direct Manifest)

Used for creating raw K8s resources (Namespaces, Deployments, Services, etc.):

```yaml
- name: my-deployment
  base:
    apiVersion: kubernetes.crossplane.io/v1alpha2
    kind: Object
    spec:
      providerConfigRef:
        name: provider-kubernetes
      forProvider:
        manifest:
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: my-app
            namespace: default
          spec:
            # ... standard K8s deployment spec
  patches:
    - fromFieldPath: "spec.label.namespace"
      toFieldPath: "spec.forProvider.manifest.metadata.namespace"
      policy:
        fromFieldPath: "Required"
```

### Pattern 2: Helm Release

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

### Pattern 3: Multi-Step Pipeline

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

Create instances of the composite resources:

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

---

## 8. Functions Reference

| Function | Version | API | Purpose |
|---|---|---|---|
| `function-patch-and-transform` | v0.9.0 | `pt.fn.crossplane.io/v1beta1` | Primary resource creation and patching |
| `function-auto-ready` | v0.5.0 | — | Automatically detect when composed resources are ready |
| `function-go-templating` | v0.10.0 | — | Go template-based resource rendering |
| `function-kcl` | v0.11.4 | — | KCL-based resource rendering |
| `function-sequencer` | v0.2.3 | — | Order pipeline steps |

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
   - Define the API group, kind, and schema
   - Include all configurable properties in the OpenAPI schema

2. **Create Composition** (`x_<resource>.yaml`):
   - Reference the XRD via `compositeTypeRef`
   - Use Pipeline mode with function steps
   - Add patches for dynamic values

3. **Create Instance** (`xr_instance_<resource>.yaml`):
   - Instantiate the XR with concrete values

4. **Register Functions** (if new functions needed):
   - Add function YAML in `functions/`

---

## 11. Common Mistakes (AI Hints)

| Mistake | Correct Pattern |
|---|---|
| Using `apiVersion: apiextensions.crossplane.io/v1` for XRDs | Use `v2` for newer XRDs |
| Missing `providerConfigRef` | Always specify `provider-kubernetes` or `helm-provider` |
| Not using `mode: Pipeline` | All compositions in this project use Pipeline mode |
| Direct resource creation without Object wrapper | Wrap K8s manifests in `kubernetes.crossplane.io/v1alpha2 Object` |
| Missing `function-auto-ready` step | Add as the last step for readiness detection |
| Helm Release without namespace patch | Always patch namespace from composite field |
