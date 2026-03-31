# IDP Evolution Plan

> Single-source-of-truth roadmap to evolve **idp-concept** from a functional prototype into a production-grade Internal Developer Platform.

## Table of Contents

- [1. Vision & Principles](#1-vision--principles)
- [2. User Profiles](#2-user-profiles)
- [3. Current State Assessment](#3-current-state-assessment)
- [4. Phase 1 — Foundation Hardening](#4-phase-1--foundation-hardening)
- [5. Phase 2 — Helmfile Parameterization](#5-phase-2--helmfile-parameterization)
- [6. Phase 3 — KCL Code Quality](#6-phase-3--kcl-code-quality)
- [7. Phase 4 — Developer Experience](#7-phase-4--developer-experience)
- [8. Phase 5 — Advanced Platform Features](#8-phase-5--advanced-platform-features)
- [9. Phase 6 — Production Infrastructure (Operators & Third-Party)](#9-phase-6--production-infrastructure-operators--third-party)
- [10. Phase 7 — Multi-Format Output & Ecosystem Integration](#10-phase-7--multi-format-output--ecosystem-integration)
- [11. User Workflow Guides](#11-user-workflow-guides)
- [12. Work Matrix by User Profile](#12-work-matrix-by-user-profile)
- [13. Migration Guide: video_streaming → template pattern](#13-migration-guide-video_streaming--template-pattern)
- [Implementation Progress — Testing & TDD](#implementation-progress--testing--tdd)

---

## 1. Vision & Principles

### Vision

A KCL-powered IDP where:
- **Developers** deploy and configure applications using only `nu` commands — zero Kubernetes knowledge required
- **Platform Engineers (High-Level)** compose stacks, tenants, and sites using pre-built templates and schemas
- **Platform Engineers (Low-Level)** design framework internals, builders, templates, and output procedures

### Production-Readiness Goals

The platform must evolve from **proof-of-concept** to **production-grade**:

1. **Stateful services via operators** — Database, cache, and messaging clusters managed by Kubernetes operators (CloudNativePG, Redis Operator, Strimzi) instead of raw StatefulSets
2. **Third-party chart reuse** — Leverage production-hardened Helm charts (Bitnami, official operator charts) instead of building everything from scratch
3. **Multi-format ecosystem** — Support consuming and producing Kustomize, Jsonnet, OCI artifacts alongside Helm/Helmfile
4. **Observable infrastructure** — Prometheus metrics, Grafana dashboards, structured logging from day one
5. **Secret management** — Integration with external secret stores (Vault, AWS Secrets Manager, Azure Key Vault) via ExternalSecrets operator
6. **Network security** — NetworkPolicies, PodSecurityStandards, mTLS via service mesh
7. **High availability** — PodDisruptionBudgets, topology spread constraints, anti-affinity rules

### Design Principles

1. **Single Source of Truth** — KCL models define everything; outputs (YAML, Helm, Helmfile, Kusion, ArgoCD) are derived
2. **Progressive Disclosure** — Each user profile sees only the complexity appropriate to their role
3. **Type Safety at Compile Time** — Catch misconfigurations in KCL, not at Kubernetes deployment time
4. **Parameterized Outputs** — Generate Helm charts with configurable values, not flattened final manifests
5. **Secure by Default** — No hardcoded secrets, `IfNotPresent` image pull, least-privilege RBAC

### CNCF Platform Engineering Maturity Model Alignment

Current state: **Level 2 (Operationalized)** — dedicated tooling, but manual processes and limited self-service.

Target state: **Level 3 (Scalable)** — product-like platform with self-service interfaces, measurable adoption, and tested user experiences.

| Aspect | Current (L2) | Target (L3) |
|---|---|---|
| **Interfaces** | CLI (`koncept`) requires knowledge of factory structure | Self-service: developers run `koncept deploy <app>` |
| **Operations** | Manual factory/builder creation per release | Automated: `koncept init` scaffolds everything |
| **Adoption** | Engineers must learn KCL internals | Developers use `nu` commands only |
| **Measurement** | No metrics | Track render success/failure, build times, config drift |

---

## 2. User Profiles

### Profile 1: Developer

**Role**: Application developer who deploys and configures their applications.

**Interaction**: Only Nushell CLI commands (`koncept`). Never edits `.k` files directly.

**Capabilities**:
- `koncept render argocd` — Generate K8s manifests for GitOps deployment
- `koncept render helmfile` — Generate Helm charts with parameterized values
- `koncept render kusion` — Generate Kusion spec
- `koncept status` — (NEW) Check current release status
- `koncept validate` — (NEW) Validate configurations before rendering
- `koncept diff` — (NEW) Show what changed between current and previous render

**What they configure**: Application-level settings via site/tenant YAML overrides (port, replicas, environment variables, feature flags).

**What they never touch**: Framework schemas, builders, templates, procedures.

### Profile 2: Platform Engineer — High-Level

**Role**: Designs the deployment topology — which components go where, with what configuration layers.

**Interaction**: KCL files in `projects/<name>/` directories (stacks, tenants, sites, modules using templates).

**Capabilities**:
- Define new stacks combining existing modules
- Create tenants and sites with configuration overrides
- Compose modules using framework templates (`WebAppModule`, `SingleDatabaseModule`, `KafkaClusterModule`)
- Define new pre-releases and releases
- Extend `BaseConfigurations` with project-specific fields

**What they never touch**: Framework builders, procedures, core model schemas.

### Profile 3: Platform Engineer — Low-Level

**Role**: Designs and maintains the framework internals — schemas, builders, templates, output procedures.

**Interaction**: KCL files in `framework/` directories.

**Capabilities**:
- Create/modify builder lambdas (`build_deployment`, `build_service`, etc.)
- Design new templates (`WebAppModule`, etc.)
- Implement output procedures (`kcl_to_helm`, `kcl_to_helmfile`, `kcl_to_argocd`)
- Define core model schemas (`Component`, `Accessory`, `Stack`, `Release`)
- Design the factory pattern and assembly helpers
- Maintain `kcl.mod` dependency graphs
- Write KCL validation rules (`check` blocks)
- Design Crossplane compositions

---

## 3. Current State Assessment

### What Works Well

| Component | Status | Quality |
|---|---|---|
| Configuration merge (4-layer union) | Working | Good |
| YAML output (`kcl_to_yaml`) | Working | Good |
| Kusion output (`kcl_to_kusion`) | Working | Excellent |
| Framework builders | Working | Excellent |
| Framework templates | Working | Excellent |
| erp_back project (template pattern) | Working | Excellent |
| CLI `koncept render argocd` | Working | Functional |
| CLI `koncept render kusion` | Working | Functional |
| Helm/Helmfile schemas | Defined | Complete but unused |
| Factory/seed pattern | Working | Good |

### Critical Gaps

| Gap | Impact | Priority | Status |
|---|---|---|---|
| **Helmfile generates flat manifests** | Cannot customize deployments per environment without editing KCL | P0 | ✅ RESOLVED — Strategy B with values.yaml extraction |
| **`kcl_to_helmfile.k` is EMPTY** | No automated Helmfile generation from Stack | P0 | ✅ RESOLVED — `generate_helmfile` implemented |
| **`kcl_to_argocd.k` is EMPTY** | No automated ArgoCD Application CRD generation | P1 | ✅ RESOLVED — `generate_application` + `generate_app_project` |
| **`values_builder.k` is EMPTY** | No values.yaml extraction from component configs | P0 | ✅ RESOLVED — `extract_helm_values` in `helm_values.k` |
| **Helm only extracts raw manifests** | `kcl_to_helm.k` doesn't generate Chart.yaml or parameterized templates | P0 | ✅ RESOLVED — `generate_charts_from_stack` + static Go templates |
| **Hardcoded secrets in video_streaming** | MongoDB credentials in source code | P0 (security) | ✅ RESOLVED — Replaced with `secretKeyRef` |
| **No `check` validation blocks** | Config errors caught at K8s deploy time, not compile time | P1 | ✅ RESOLVED — DeploymentSpec, ServiceSpec, PVSpec, EnvVar check blocks |
| **`any` types for env vars/volumes** | No compile-time type checking for K8s fields | P1 | ✅ RESOLVED — EnvVar schema with KeySelector, EnvVarSource |
| **CLI hardcoded builder filenames** | Different project structures break the CLI | P2 | ✅ RESOLVED — `resolve_builder` with `koncept.yaml` config |
| **No test infrastructure** | No `.test.k` files; regressions undetected | P2 | ✅ RESOLVED — 130 tests, full TDD workflow |
| **Hardcoded Git repo URL** | ArgoCD builders can't be forked/multi-tenanted | P2 | ✅ RESOLVED — `gitRepoUrl` in BaseConfigurations |

### Architecture Diagram (Current → Target)

```
CURRENT (Proof of Concept):
┌──────────────────────────────────────────────────────────────────┐
│ KCL Source → builders → raw manifests → kcl_to_yaml / kusion    │
│ All resources hand-crafted (Deployment, Service, StatefulSet)    │
│ No operators, no third-party charts, flat YAML output            │
└──────────────────────────────────────────────────────────────────┘

TARGET (Production-Grade):
┌──────────────────────────────────────────────────────────────────┐
│                     DEVELOPER (nu commands)                       │
│  koncept deploy <app> | koncept validate | koncept status         │
└─────────────────────────────┬────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                     FACTORY (per release)                          │
│  factory_seed.k → merge all config layers → instantiate stack     │
└─────────────────────────────┬────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌──────────────┐     ┌──────────────┐      ┌──────────────┐
│  Components  │     │  Accessories │      │  ThirdParty  │
│ WebAppModule │     │ Operator CRs │      │ Helm Charts  │
│ (templates)  │     │ (CNPG, Redis │      │ (Bitnami,    │
│              │     │  Strimzi)    │      │  official)   │
└──────┬───────┘     └──────┬───────┘      └──────┬───────┘
       │                    │                     │
       └────────────────────┼─────────────────────┘
                            ▼
              ┌──────────────────────────┐
              │    Output Procedures      │
              ├──────────────────────────┤
              │ kcl_to_yaml     (working)│
              │ kcl_to_kusion   (working)│
              │ kcl_to_helm     (working)│
              │ kcl_to_helmfile (working)│
              │ kcl_to_argocd   (working)│
              │ kcl_to_kustomize(future) │
              └──────────────────────────┘
```

---

## 4. Phase 1 — Foundation Hardening

**Owner**: Platform Engineer (Low-Level)

### 4.1 Security Fixes (P0)

#### 4.1.1 Remove hardcoded credentials from video_streaming

**Files to fix**:
- `projects/video_streaming/modules/infrastructure/mongodb/mongodb_single_instance_module_def.k`
- `projects/video_streaming/modules/appops/video_collector_mongodb_python/video_collector_mongodb_python_module_def.k`

**Pattern** — Replace:
```kcl
# ❌ CURRENT
env = [
    { name = "MONGO_INITDB_ROOT_USERNAME", value = "admin" }
    { name = "MONGO_INITDB_ROOT_PASSWORD", value = "admin" }
]
```

With:
```kcl
# ✅ TARGET
env = [
    { name = "MONGO_INITDB_ROOT_USERNAME"
      valueFrom = { secretKeyRef = { name = "mongo-credentials", key = "username" } } }
    { name = "MONGO_INITDB_ROOT_PASSWORD"
      valueFrom = { secretKeyRef = { name = "mongo-credentials", key = "password" } } }
]
```

#### 4.1.2 Externalize Git repository URL in ArgoCD builders

Add `gitRepoUrl: str` to `BaseConfigurations` and pass it via site configs.

### 4.2 Fix `imagePullPolicy` inconsistency

**File**: `framework/templates/database.k`

Change `imagePullPolicy` default from `"Always"` to `"IfNotPresent"`. Document that `"Always"` should only be used for mutable tags during development.

### 4.3 Fix code style inconsistencies

**File**: `framework/models/modules/accessory.k`

Fix inconsistent spacing in instance construction:
```kcl
# ❌ CURRENT
instance = AccessoryInstance {
    name=name
    kind=kind
    namespace =namespace
}

# ✅ TARGET
instance: AccessoryInstance = AccessoryInstance {
    name = name
    kind = kind
    namespace = namespace
}
```

---

## 5. Phase 2 — Helmfile Parameterization

**Owner**: Platform Engineer (Low-Level) for procedures; Platform Engineer (High-Level) for project integration

This is the core architectural change: generate Helm charts with **parameterized values** instead of flat/final manifests.

### 5.1 Problem Statement

Currently, `koncept render helmfile` produces:
1. A `Chart.yaml` with metadata (working)
2. A `templates/manifests.yaml` containing **fully resolved K8s manifests** (all values baked in)
3. An **empty** `values.yaml`
4. A `helmfile.yaml` with **hardcoded dummy releases**

This means every environment gets identical manifests. To customize per-environment, you must re-run KCL with different configs — defeating the purpose of Helm's parameterization.

### 5.2 Target Architecture

```
koncept render helmfile
       │
       ├─ Chart.yaml                      ← metadata from Release/Stack
       ├─ values.yaml                     ← extracted configurable parameters
       │    replicaCount: 2
       │    image:
       │      repository: ghcr.io/org/app
       │      tag: "1.0.0"
       │    service:
       │      type: ClusterIP
       │      port: 8080
       │    env:
       │      SPRING_PROFILES_ACTIVE: dev
       │      DATABASE_HOST: postgres.svc.local
       │    resources:
       │      requests: { cpu: "250m", memory: "512Mi" }
       │      limits: { cpu: "1", memory: "2Gi" }
       │
       ├─ templates/
       │    ├─ deployment.yaml             ← K8s manifest with {{ .Values.* }} placeholders
       │    ├─ service.yaml
       │    ├─ configmap.yaml
       │    ├─ serviceaccount.yaml
       │    └─ _helpers.tpl                ← common labels, selectors
       │
       └─ helmfile.yaml                   ← auto-generated from Stack releases
            repositories: [...]
            releases:
              - name: erp-api
                chart: ./charts/erp-api
                values: [./charts/erp-api/values.yaml]
                # Per-environment overrides via helmfile environments
```

### 5.3 Implementation Steps

#### Step 1: Create `HelmValues` extraction schema

**New file**: `framework/procedures/helm_values.k`

This lambda extracts configurable values from component instances:

```kcl
import models.modules.component

schema HelmValues:
    """Extracted Helm values from a component."""
    replicaCount?: int
    image?: {str:str}
    service?: {str:any}
    env?: {str:str}
    resources?: {str:any}
    probes?: {str:any}
    configMap?: {str:str}

extract_helm_values = lambda comp: component.ComponentInstance -> HelmValues {
    # Extract the first deployment's configurable fields
    _deploy = [m for m in comp.manifests if m.kind == "Deployment"][0] if [m for m in comp.manifests if m.kind == "Deployment"] else Undefined
    _svc = [m for m in comp.manifests if m.kind == "Service"][0] if [m for m in comp.manifests if m.kind == "Service"] else Undefined
    _container = _deploy?.spec?.template?.spec?.containers?[0] if _deploy else Undefined

    HelmValues {
        if _container:
            replicaCount = _deploy?.spec?.replicas
            image = {
                repository = _container.image.rsplit(":")[0] if ":" in _container.image else _container.image
                tag = _container.image.rsplit(":")[1] if ":" in _container.image else "latest"
            }
            if _container.env:
                env = {e.name: e.value for e in _container.env if e.value}
            if _container.resources:
                resources = _container.resources
        if _svc:
            service = {
                $type = _svc.spec?.$type or "ClusterIP"
                port = _svc.spec?.ports?[0]?.port
            }
    }
}
```

> **Note**: The exact implementation will depend on verifying KCL's `rsplit` and optional chaining syntax against official docs. This is pseudocode illustrating the data flow — validate each KCL function call before implementation.

#### Step 2: Create `HelmTemplate` generation procedure

**New file**: `framework/procedures/kcl_to_helm_template.k`

This converts a component's manifests into Helm-templated YAML with `{{ .Values.* }}` placeholders:

```kcl
import models.modules.component
import models.stack as stack
import manifests

schema HelmTemplateOutput:
    """Output structure for a single Helm template file."""
    filename: str
    content: str

generate_helm_templates = lambda comp: component.ComponentInstance -> [HelmTemplateOutput] {
    # For each manifest in the component, generate a Helm template
    # that references {{ .Values.* }} instead of hardcoded values
    _templates = []
    _templates += [_deployment_template(m, comp.name) for m in comp.manifests if m.kind == "Deployment"]
    _templates += [_service_template(m, comp.name) for m in comp.manifests if m.kind == "Service"]
    _templates += [_configmap_template(m, comp.name) for m in comp.manifests if m.kind == "ConfigMap"]
    _templates += [_serviceaccount_template(m, comp.name) for m in comp.manifests if m.kind == "ServiceAccount"]
    _templates
}
```

> **Note**: KCL generates static YAML, not Go templates. The approach here is to generate Helm template files where specific values (image, port, replicas, env) are replaced with `{{ .Values.* }}` Helm syntax. Since KCL outputs strings, the template text will be string-interpolated KCL that produces Go template syntax. See Step 4 for the alternative approach.

#### Step 3: Implement `kcl_to_helmfile.k`

**File**: `framework/procedures/kcl_to_helmfile.k`

```kcl
import models.stack as stack
import models.modules.component
import custom.helmfile.helmfile as hf
import manifests

generate_helmfile_from_stack = lambda input_stack: stack.Stack, chart_base_path: str -> hf.Helmfile {
    _releases = [
        hf.Release {
            name = comp.name
            namespace = comp.namespace
            chart = "${chart_base_path}/charts/${comp.name}"
            values = ["${chart_base_path}/charts/${comp.name}/values.yaml"]
            createNamespace = True
        }
        for comp in input_stack.components
    ] if input_stack.components else []

    hf.Helmfile {
        releases = _releases
    }
}

helmfile_yaml_stream = lambda input_stack: stack.Stack, chart_base_path: str -> any {
    _helmfile = generate_helmfile_from_stack(input_stack, chart_base_path)
    manifests.yaml_stream([_helmfile])
}
```

#### Step 4: Dual-strategy approach for Helm templates

There are two valid approaches. Choose based on your team's preference:

**Strategy A — KCL generates Go template strings (recommended for this project)**:

KCL outputs `.yaml` files containing Helm `{{ .Values.* }}` placeholders as literal strings. The builder generates each template file's content as a KCL string that contains Go template syntax.

Pros: Full control, one tool generates everything.
Cons: KCL string manipulation complexity; must escape `{{ }}` properly.

**Strategy B — KCL generates values.yaml only; templates are static**:

KCL extracts configurable values into `values.yaml`. The Helm template files in `templates/` are hand-written Go templates that reference those values. KCL only generates the data layer.

Pros: Simpler KCL code, standard Helm workflow, templates are reviewable by Helm users.
Cons: Template files maintained separately from KCL models.

**Recommendation**: Start with **Strategy B** (simpler, more standard), then evolve to Strategy A if full automation is needed. Strategy B aligns better with the Developer profile — they already know Helm.

#### Step 5: Update `kcl_to_helm.k`

Expand the current 15-line procedure to support both raw manifests and parameterized output:

```kcl
import models.modules.component
import models.stack as stack
import custom.helm.helm
import manifests

# Existing: raw manifest extraction (for ArgoCD/YAML output)
generate_helm_components_templates_from_stack = lambda input_stack: stack.Stack -> any {
    modules = get_helm_components(input_stack.components)
    manifests.yaml_stream(modules)
}

get_helm_components = lambda components: [component.ComponentInstance] -> [any] {
    [element.manifests for element in components] if components else []
}

# NEW: Chart.yaml generation from stack metadata
generate_chart_from_component = lambda comp: component.ComponentInstance, version: str -> helm.Chart {
    helm.Chart {
        apiVersion = "v2"
        name = comp.name
        description = "Helm chart for ${comp.name}"
        $type = "application"
        version = version
        appVersion = version
    }
}

# NEW: values.yaml generation from component configs
generate_values_from_component = lambda comp: component.ComponentInstance -> helm.HelmChartValues {
    _deploy = [m for m in comp.manifests if m.kind == "Deployment"]
    _svc = [m for m in comp.manifests if m.kind == "Service"]
    _container = _deploy[0]?.spec?.template?.spec?.containers?[0] if _deploy else Undefined

    helm.HelmChartValues {
        if _container:
            replicaCount = _deploy[0]?.spec?.replicas
            image = helm.Image {
                repository = comp.name
                tag = "latest"
                pullPolicy = "IfNotPresent"
            }
            resources = helm.Resources {
                requests = _container?.resources?.requests
                limits = _container?.resources?.limits
            }
        if _svc:
            service = helm.Service {
                $type = _svc[0]?.spec?.$type or "ClusterIP"
                port = _svc[0]?.spec?.ports?[0]?.port or 8080
            }
    }
}
```

> **Important caveat**: KCL's optional chaining (`?.`) support must be verified against official docs. The lambda pseudo-code above illustrates the data extraction intent. Validate the actual KCL syntax for list indexing with conditionals and optional field access before implementing.

#### Step 6: Create Helm template files (Strategy B static templates)

**New directory**: `framework/templates/helm/`

Create standard Helm Go templates that reference `{{ .Values.* }}`:

**`framework/templates/helm/deployment.yaml.tpl`** (reference template, not KCL):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "chart.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "chart.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "chart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "chart.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.port }}
          {{- if .Values.env }}
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          {{- end }}
          {{- if .Values.resources }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- end }}
          {{- if .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          {{- end }}
          {{- if .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          {{- end }}
```

These static templates are **copied** into the output `charts/<name>/templates/` directory during `koncept render helmfile`. KCL only generates `Chart.yaml` and `values.yaml`.

#### Step 7: Update CLI `koncept render helmfile`

```nushell
"helmfile" => {
    let output_dir = (if $output != null { $output } else { "output" })

    # For each component, generate a chart directory
    print "[Helmfile] Generating parameterized Helm charts..."

    # 1. Generate Chart.yaml per component
    kcl run $"($factory_dir)/chart_builder.k" -o $"($output_dir)/charts/Chart.yaml"

    # 2. Generate values.yaml per component (NEW)
    kcl run $"($factory_dir)/values_builder.k" -o $"($output_dir)/charts/values.yaml"

    # 3. Copy static Helm templates
    let templates_src = ($koncept_dir | path join "templates/helm")
    let templates_dst = $"($output_dir)/charts/templates"
    mkdir $templates_dst
    cp $"($templates_src)/*.tpl" $templates_dst

    # 4. Generate helmfile.yaml (NEW — from Stack, not hardcoded)
    kcl run $"($factory_dir)/helmfile_builder.k" -o $"($output_dir)/helmfile.yaml"

    print "[Helmfile] Done."
}
```

### 5.4 Output Structure (Target)

```
output/
├── helmfile.yaml                    ← auto-generated from Stack.components
└── charts/
    └── erp-api/
        ├── Chart.yaml               ← from chart_builder.k
        ├── values.yaml              ← extracted from component configs (NEW)
        └── templates/
            ├── _helpers.tpl          ← standard Helm helpers
            ├── deployment.yaml       ← Go template with {{ .Values.* }}
            ├── service.yaml
            ├── configmap.yaml
            └── serviceaccount.yaml
```

### 5.5 Per-Environment Values Overrides

With parameterized Helm charts, per-environment customization becomes standard Helmfile:

```yaml
# helmfile.yaml (generated)
releases:
  - name: erp-api
    chart: ./charts/erp-api
    values:
      - ./charts/erp-api/values.yaml          # base values from KCL
      - ./env/{{ .Environment.Name }}.yaml     # per-environment overrides
```

**Per-environment files** (created by Platform Engineer — High-Level):
```yaml
# env/production.yaml
replicaCount: 3
image:
  tag: "1.2.0"
resources:
  requests:
    cpu: "1"
    memory: "2Gi"
env:
  SPRING_PROFILES_ACTIVE: production
  DATABASE_HOST: prod-postgres.rds.amazonaws.com
```

---

## 6. Phase 3 — KCL Code Quality

**Owner**: Platform Engineer (Low-Level)

### 6.1 Add Type Safety

#### 6.1.1 Create `EnvVar` schema

**File**: `framework/models/modules/common.k` (new)

```kcl
schema EnvVar:
    """Kubernetes environment variable specification."""
    name: str
    value?: str
    valueFrom?: EnvVarSource

    check:
        value or valueFrom, "env var must have either value or valueFrom"
        not (value and valueFrom), "env var cannot have both value and valueFrom"

schema EnvVarSource:
    secretKeyRef?: KeySelector
    configMapKeyRef?: KeySelector

schema KeySelector:
    name: str
    key: str
```

Then update `framework/builders/deployment.k`:
```kcl
# ❌ CURRENT
env?: [any]

# ✅ TARGET (import common.EnvVar)
env?: [EnvVar]
```

#### 6.1.2 Add validation `check` blocks

**File**: `framework/builders/deployment.k` — add to `DeploymentSpec`:
```kcl
check:
    replicas >= 1 if replicas, "replicas must be at least 1"
    1 <= port <= 65535 if port, "port must be 1-65535"
```

**File**: `framework/builders/service.k` — add to `ServiceSpec`:
```kcl
check:
    1 <= port <= 65535, "port must be 1-65535"
    serviceType in ["ClusterIP", "NodePort", "LoadBalancer"] if serviceType, "invalid service type"
```

**File**: `framework/builders/storage.k` — add to `PersistentVolumeSpec`:
```kcl
check:
    size, "storage size is required"
    hostPath, "hostPath is required"
```

### 6.2 Document Justified `any` Types

The following `any` usages in framework models are **intentional by design** (the framework must support arbitrary project config schemas):

| File | Field | Reason |
|---|---|---|
| `configurations.k` | Lambda params `kernel: any` etc. | Generic merge across project schemas |
| `project.k` | `configurations: any` | Project-specific config schema |
| `tenant.k` | `configurations: any` | Tenant-specific config schema |
| `site.k` | `configurations: any` | Site-specific config schema |
| `stack.k` | `instanceConfigurations: any` | Merged config from all layers |
| `factory/seed.k` | `mergeFunc: any`, `stackSchema: any` | Higher-order function parameters |

Add a `# framework-generic: accepts any project config schema` comment to each.

### 6.3 KCL Test Infrastructure

**New directory**: `framework/tests/`

KCL supports testing with `kcl test`. Create test files:

```kcl
# framework/tests/builders_test.k
import framework.builders.deployment as deploy

_test_spec = deploy.DeploymentSpec {
    name = "test-app"
    namespace = "test-ns"
    image = "test/image"
    version = "1.0.0"
    port = 8080
}

_result = deploy.build_deployment(_test_spec)

# Assertions
assert _result.metadata.name == "test-app"
assert _result.metadata.namespace == "test-ns"
assert _result.spec.template.spec.containers[0].image == "test/image:1.0.0"
```

> **Note**: Verify `kcl test` command syntax and assertion patterns against official KCL docs before implementing. The KCL test runner may use a different assertion API.

---

## 7. Phase 4 — Developer Experience

**Owner**: Platform Engineer (Low-Level) for CLI; Platform Engineer (High-Level) for documentation

### 7.1 CLI Improvements

#### 7.1.1 `koncept validate` — Pre-render validation

```nushell
"validate" => {
    print "[Validate] Checking factory configuration..."
    let result = (^kcl run $"($factory_dir)/factory_seed.k" --output json | complete)
    if $result.exit_code != 0 {
        print $"❌ Validation failed:\n($result.stderr)"
        exit 1
    }
    print "✅ Configuration is valid"
}
```

#### 7.1.2 `koncept init` — Scaffold new pre-release/release

```nushell
"init" => {
    let template_type = $render_type  # "argocd" | "helmfile" | "kusion"
    print $"[Init] Scaffolding ($template_type) factory..."
    # Copy template factory files from platform_cli/templates/
    # Replace placeholders with project-specific values
}
```

#### 7.1.3 Remove hardcoded builder filenames

**Current** (brittle):
```nushell
kcl run $"($factory_dir)/kubernetes_manifests_builder.k"
```

**Target** (configurable):
```nushell
# Read builder name from factory/koncept.yaml or convention
let builder = (if ($"($factory_dir)/koncept.yaml" | path exists) {
    open $"($factory_dir)/koncept.yaml" | get builders.yaml
} else {
    "yaml_builder.k"   # default convention
})
kcl run $"($factory_dir)/($builder)"
```

#### 7.1.4 Error handling and user feedback

```nushell
# Wrap all kcl run calls with error handling
def kcl_run [file: string, ...args: string] {
    let result = (^kcl run $file ...$args | complete)
    if $result.exit_code != 0 {
        print $"❌ KCL compilation failed for ($file):"
        print $result.stderr
        exit 1
    }
    $result.stdout
}
```

### 7.2 Developer-Facing Documentation

Create `docs/DEVELOPER_QUICKSTART.md`:

```markdown
# Developer Quickstart

## Deploying Your Application

### 1. Navigate to your release directory
cd projects/<project>/pre_releases/gitops/<site>/

### 2. Validate configuration
koncept validate

### 3. Render manifests
koncept render argocd          # Plain K8s YAML for GitOps
koncept render helmfile        # Helm charts with values
koncept render kusion          # Kusion spec

### 4. Review output
ls output/

### What You Can Configure (as a developer)
- Application replicas, resource limits
- Environment variables (via site configurations)
- Feature flags (via tenant configurations)

### What You Should NOT Edit
- Files in framework/ (contact platform engineers)
- Files in modules/ (contact platform engineers)
- Factory builder files (auto-generated)
```

---

## 8. Phase 5 — Advanced Platform Features

**Owner**: Platform Engineer (Low-Level)

### 8.1 Implement `kcl_to_argocd.k`

Generate ArgoCD `Application` CRDs automatically from Stack:

```kcl
import models.stack as stack
import models.modules.component
import custom.argocd.models.v1alpha1.argocd_application as app
import manifests

generate_argocd_applications = lambda input_stack: stack.Stack, repo_url: str, base_path: str, target_revision: str -> [any] {
    _apps = [
        app.ArgocdApplication {
            metadata = {
                name = comp.name
                namespace = "argocd"
            }
            spec = {
                project = "default"
                source = {
                    repoURL = repo_url
                    targetRevision = target_revision
                    path = "${base_path}/${comp.name}"
                }
                destination = {
                    server = "https://kubernetes.default.svc"
                    namespace = comp.namespace
                }
                syncPolicy = {
                    automated = { prune = True, selfHeal = True }
                }
            }
        }
        for comp in input_stack.components
    ] if input_stack.components else []

    manifests.yaml_stream(_apps)
}
```

> **Note**: Verify the exact ArgoCD Application schema structure from `framework/custom/argocd/models/v1alpha1/` before implementing. The field names above are illustrative.

### 8.2 Network Policies

Add `NetworkPolicy` builder to `framework/builders/`:

```kcl
schema NetworkPolicySpec:
    name: str
    namespace: str
    podSelector: {str:str}
    ingressRules?: [any]   # Allow specific ingress
    egressRules?: [any]    # Allow specific egress

build_network_policy = lambda spec: NetworkPolicySpec -> any {
    {
        apiVersion = "networking.k8s.io/v1"
        kind = "NetworkPolicy"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            podSelector = { matchLabels = spec.podSelector }
            if spec.ingressRules:
                ingress = spec.ingressRules
            if spec.egressRules:
                egress = spec.egressRules
            policyTypes = [
                "Ingress" if spec.ingressRules
                "Egress" if spec.egressRules
            ]
        }
    }
}
```

### 8.3 Pod Disruption Budgets

Add `PDB` builder for HA deployments:

```kcl
schema PDBSpec:
    name: str
    namespace: str
    matchLabels: {str:str}
    minAvailable?: int | str     # "50%" or 1
    maxUnavailable?: int | str

build_pdb = lambda spec: PDBSpec -> any {
    {
        apiVersion = "policy/v1"
        kind = "PodDisruptionBudget"
        metadata = { name = spec.name, namespace = spec.namespace }
        spec = {
            selector = { matchLabels = spec.matchLabels }
            if spec.minAvailable:
                minAvailable = spec.minAvailable
            if spec.maxUnavailable:
                maxUnavailable = spec.maxUnavailable
        }
    }
}
```

### 8.4 Secret Management Schema

Formalize how secrets are referenced:

```kcl
schema SecretReference:
    """Reference to a Kubernetes Secret."""
    secretName: str
    key: str
    optional?: bool = False

schema ExternalSecret:
    """Reference to an external secret store (e.g., Vault, AWS Secrets Manager)."""
    store: str                  # "vault" | "aws-secrets-manager" | "azure-key-vault"
    key: str
    property?: str
    refreshInterval?: str = "1h"
```

### 8.5 Multi-Component Helm Charts

For stacks with multiple components, generate a parent chart with subcharts:

```
output/
├── helmfile.yaml
└── charts/
    └── my-stack/
        ├── Chart.yaml           ← parent chart with dependencies
        ├── values.yaml          ← aggregated values
        └── charts/
            ├── erp-api/         ← subchart
            │   ├── Chart.yaml
            │   ├── values.yaml
            │   └── templates/
            └── erp-db/          ← subchart
                ├── Chart.yaml
                ├── values.yaml
                └── templates/
```

---

## 9. Phase 6 — Production Infrastructure (Operators & Third-Party)

**Owner**: Platform Engineer (Low-Level) for framework; Platform Engineer (High-Level) for project integration

This phase replaces proof-of-concept raw manifests with production-grade Kubernetes operators and third-party Helm charts. See [`REFERENCE_RESOURCES.md`](./REFERENCE_RESOURCES.md) for the full evaluation of each tool.

### 9.1 Operator-Managed Databases

Replace hand-crafted StatefulSets/Deployments for databases with Kubernetes operators.

#### 9.1.1 PostgreSQL via CloudNativePG

**Priority**: P1 — Most common database; CNCF Sandbox project; Kubernetes-native design.

1. **Install operator**: Create a `ThirdParty` module for the CloudNativePG Helm chart
2. **Import CRDs**: `kcl import --mode crd` from CloudNativePG CRDs → generates KCL schemas
3. **Create template**: `framework/templates/postgresql.k` — `PostgreSQLClusterModule(Accessory)` with sensible production defaults
4. **Builder lambda**: `framework/builders/postgresql.k` — generates `Cluster` CR with backup, monitoring, HA settings
5. **Check blocks**: Validate `instances >= 1`, `storageSize` required, backup config when `instances > 1`

```kcl
# Target API for Platform Engineer (High-Level):
schema MyPostgres(postgresql.PostgreSQLClusterModule):
    instances = 3                        # HA: 3 replicas
    storageSize = "50Gi"
    pgVersion = "16"
    backup = postgresql.BackupSpec {
        schedule = "0 3 * * *"           # Daily 3 AM
        retentionPolicy = "30d"
        destination = "s3://backups/pg"
    }
    monitoring = True                    # Enable Prometheus metrics
    pooler = postgresql.PoolerSpec {
        instances = 2
        pgbouncerPoolMode = "transaction"
    }
```

#### 9.1.2 Redis via OT-Container-Kit Operator

**Priority**: P2 — Common cache/session store.

1. **Install operator**: `ThirdParty` module for redis-operator Helm chart
2. **Import CRDs**: Generate KCL schemas from Redis/RedisCluster/RedisSentinel/RedisReplication CRDs
3. **Create template**: `framework/templates/redis.k` — modes: standalone, cluster, replication, sentinel
4. **Check blocks**: Validate mode-specific requirements (e.g., cluster needs `clusterSize >= 3`)

```kcl
# Target API:
schema MyRedis(redis.RedisModule):
    mode = "cluster"                     # "standalone" | "cluster" | "replication" | "sentinel"
    clusterSize = 3
    storageSize = "10Gi"
    monitoring = True
    exporter = True                      # Redis exporter sidecar
```

#### 9.1.3 MongoDB via New Operator or Bitnami

**Priority**: P2 — Replace deprecated `mongodb-kubernetes-operator`.

> **CRITICAL**: The `mongodb/mongodb-kubernetes-operator` was **deprecated in December 2025**. The recommended path is either the new `mongodb/mongodb-kubernetes` repo or the Bitnami MongoDB Helm chart.

Two options:
- **Option A**: Use new `mongodb/mongodb-kubernetes` operator — import CRDs, create template
- **Option B**: Use `bitnami/mongodb` Helm chart as `ThirdParty` module — simpler, well-tested

#### 9.1.4 MinIO / Object Storage

**Priority**: P3 — Less common, consider Bitnami chart.

> **NOTE**: The `minio/operator` was **archived in March 2026**. Use Bitnami MinIO Helm chart instead.

### 9.2 Third-Party Helm Chart Integration

The `ThirdParty` module type already exists in the framework but needs production patterns.

#### 9.2.1 ThirdParty Module Enhancement

Enhance `framework/models/modules/thirdparty.k` to support:

```kcl
schema ThirdPartyHelmSpec:
    """Specification for deploying a third-party Helm chart."""
    name: str
    namespace: str
    chart: str                           # "oci://registry-1.docker.io/bitnamicharts/mongodb"
    version: str                         # Pinned version (MANDATORY)
    repository?: str                     # For non-OCI charts
    values?: {str:any}                   # Override values
    valuesFiles?: [str]                  # Paths to values files
    createNamespace?: bool = True
    wait?: bool = True
    timeout?: str = "10m"

    check:
        version, "Helm chart version must be pinned — no 'latest' or floating tags"
        "latest" not in version, "version must not contain 'latest'"
```

#### 9.2.2 Bitnami Chart Catalog

Create a catalog of pre-configured Bitnami chart wrappers in `framework/templates/thirdparty/`:

```
framework/templates/thirdparty/
├── bitnami_postgresql.k     # Wraps bitnami/postgresql with IDP defaults
├── bitnami_redis.k          # Wraps bitnami/redis
├── bitnami_mongodb.k        # Wraps bitnami/mongodb (replacement for deprecated operator)
├── bitnami_minio.k          # Wraps bitnami/minio
├── bitnami_keycloak.k       # Wraps bitnami/keycloak
└── bitnami_kafka.k          # Wraps bitnami/kafka (alternative to Strimzi)
```

Each wrapper provides:
- Sensible production defaults (resource limits, security context, persistence)
- IDP-standard labels and annotations
- Check blocks for version pinning and required security settings
- Integration with the configuration merge pipeline (values from tenant/site configs)

### 9.3 Observability Stack

#### 9.3.1 Monitoring Template

```kcl
schema MonitoringStack:
    """Deploy Prometheus + Grafana via Bitnami or kube-prometheus-stack."""
    prometheus: ThirdPartyHelmSpec = ThirdPartyHelmSpec {
        name = "prometheus"
        chart = "oci://registry-1.docker.io/bitnamicharts/kube-prometheus"
        version = "10.2.0"  # Pin to specific version
    }
    grafana: ThirdPartyHelmSpec = ThirdPartyHelmSpec {
        name = "grafana"
        chart = "oci://registry-1.docker.io/bitnamicharts/grafana"
        version = "11.3.0"
    }
    serviceMonitors?: [ServiceMonitorSpec]  # Auto-generated from components
```

#### 9.3.2 ExternalSecrets Operator Integration

Replace in-cluster `Secret` references with external secret management:

```kcl
schema ExternalSecretSpec:
    """Spec for ExternalSecrets operator to sync from external stores."""
    name: str
    namespace: str
    secretStoreRef: SecretStoreRef
    target: str                          # K8s Secret name to create
    data: [ExternalSecretData]
    refreshInterval?: str = "1h"

schema SecretStoreRef:
    name: str                            # ClusterSecretStore or SecretStore name
    kind: str = "ClusterSecretStore"     # "SecretStore" | "ClusterSecretStore"

schema ExternalSecretData:
    secretKey: str                       # Key in the K8s Secret
    remoteRef: RemoteRef                 # Reference in external store

schema RemoteRef:
    key: str                             # Path in vault/AWS/Azure
    property?: str                       # Specific property within the key
```

### 9.4 Strategy: Operator vs Helm Chart

Decision matrix for when to use operators vs direct Helm charts:

| Criteria | Use Operator | Use Helm Chart (Bitnami) |
|---|---|---|
| **Stateful with HA** | PostgreSQL, Kafka (failover, backup) | Simpler deployments without HA |
| **Custom lifecycle** | Backup/restore, major upgrades | Standard deployments |
| **CRD-based API** | Need declarative K8s-native API | Standard values.yaml is sufficient |
| **Team expertise** | Team knows operators, has cluster-admin | Team prefers standard Helm |
| **Complexity** | Can afford operator overhead | Minimize operational burden |

**Recommended defaults for idp-concept**:
- PostgreSQL → **CloudNativePG operator** (HA, backup, CNCF)
- Redis → **OT Redis Operator** or Bitnami chart (depends on HA needs)
- MongoDB → **Bitnami chart** (operator deprecated)
- Kafka → **Strimzi operator** (already in project)
- MinIO → **Bitnami chart** (operator archived)
- Keycloak → **Bitnami chart** or Crossplane managed resource

---

## 10. Phase 7 — Multi-Format Output & Ecosystem Integration

**Owner**: Platform Engineer (Low-Level)

This phase extends the IDP to produce and consume multiple K8s packaging formats.

### 10.1 Kustomize Output (`kcl_to_kustomize`)

Generate Kustomize-compatible output structure from KCL:

```
output/
├── base/
│   ├── kustomization.yaml              # Generated from Stack
│   ├── deployment.yaml                 # Component manifests
│   ├── service.yaml
│   └── configmap.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml          # Patches from site config
    │   └── replica-patch.yaml
    └── production/
        ├── kustomization.yaml
        └── resource-patch.yaml
```

Key implementation:
- `framework/procedures/kcl_to_kustomize.k` — generates `kustomization.yaml` + base manifests
- Overlay patches derived from configuration diff between base profile and site-specific configs
- Strategic merge patches for resources, replicas, env vars

### 10.2 KCL Plugin Integration

Support using KCL as a mutation layer for externally-managed charts:

```
External Helm Chart (e.g., bitnami/postgresql)
    ↓ helm template
Raw manifests
    ↓ helm-kcl plugin
KCL mutation (add labels, inject sidecars, enforce policies)
    ↓
Final manifests
```

This enables the IDP to:
1. Consume any third-party chart without forking
2. Apply organization-wide policies (network policies, security contexts)
3. Inject standard labels, annotations, and monitoring sidecars

### 10.3 OCI Artifact Publishing

Publish IDP modules to OCI registries for reuse across teams:

```nushell
# Publish a KCL module as OCI artifact
def "main publish" [module: string, version: string, --registry: string = "ghcr.io"] {
    ^kcl mod push $"oci://($registry)/($module):($version)"
}
```

### 10.4 Jsonnet Bundle Consumption

For teams with existing Jsonnet bundles (e.g., kube-prometheus mixins):

```kcl
schema JsonnetBundle(ThirdParty):
    packageManager = "JSONNET"
    bundlePath: str                # Path to jsonnet bundle
    extVars?: {str:str}           # External variables for jsonnet
    tlaVars?: {str:str}           # Top-level argument variables
```

---

## 11. User Workflow Guides

> Developer-oriented documentation for each of the three user profiles. Each section describes **what the user does**, **how they do it**, and **what they should never need to know**.

### 11.1 Developer Workflow

**Goal**: Deploy and configure applications with zero Kubernetes knowledge.

#### 11.1.1 Day-to-Day Commands

```bash
# 1. Navigate to your release
cd projects/my-project/pre_releases/gitops/dev/factory

# 2. Validate configuration (catch errors before rendering)
koncept validate

# 3. Render manifests for GitOps
koncept render argocd          # Plain K8s YAML → commit to Git → ArgoCD syncs

# 4. Render Helm charts for environment customization
koncept render helmfile        # Helm charts + values.yaml + helmfile.yaml

# 5. Check what changed
koncept diff                   # (Phase 4) Compare current vs previous render
```

#### 11.1.2 What Developers Configure

Developers customize their applications through **site configuration files** (YAML-friendly KCL). They never write raw K8s manifests.

| What to Change | Where | Example |
|---|---|---|
| Replicas | `sites/<site>/site_def.k` | `replicas = 3` |
| Environment variables | `sites/<site>/site_def.k` | `springProfile = "production"` |
| Resource limits | `sites/<site>/site_def.k` | `memoryLimit = "4Gi"` |
| Feature flags | `tenants/<tenant>/tenant_def.k` | `featureNewUI = True` |
| Image version | `sites/<site>/site_def.k` | `version = "2.1.0"` |

#### 11.1.3 What Developers Never Touch

- `framework/` — Platform internals
- `modules/*_module_def.k` — Module schemas (contact Platform Eng)
- `factory/` — Auto-generated builder files
- `stacks/` — Stack composition (contact Platform Eng)
- `kcl.mod` — Package dependencies

#### 11.1.4 Troubleshooting for Developers

| Problem | Solution |
|---|---|
| `koncept validate` fails | Check error message — usually a config value out of range or missing |
| `koncept render` fails with KCL error | Run `koncept validate` first; if still fails, contact Platform Engineer |
| "Cannot find module" error | You're in the wrong directory — `cd` to the `factory/` folder |
| Application not deploying | Check ArgoCD UI → sync status; check events for K8s errors |
| Need a new environment variable | Add to site config file, run `koncept render`, commit to Git |

### 11.2 Platform Engineer (High-Level) Workflow

**Goal**: Compose deployment topologies — stacks, tenants, sites, modules — using pre-built templates.

#### 11.2.1 Creating a New Project

```bash
# 1. Start with the template project (erp_back is the reference)
cp -r projects/erp_back projects/my_new_project

# 2. Define the project kernel
# Edit: projects/my_new_project/kernel/project_def.k
#   Set: name, domain, team, base configurations

# 3. Define configuration schema
# Edit: projects/my_new_project/core_sources/config.k
#   Extend BaseConfigurations with project-specific fields

# 4. Create application modules
# Edit: projects/my_new_project/modules/
#   Use framework templates: WebAppModule, SingleDatabaseModule, etc.

# 5. Compose a stack
# Edit: projects/my_new_project/stacks/
#   Declare which modules + namespaces go into the stack

# 6. Create tenant and site configs
# Edit: projects/my_new_project/tenants/ and sites/

# 7. Create pre-release
# Edit: projects/my_new_project/pre_releases/
#   Wire factory_seed.k → builder files
```

#### 11.2.2 Creating a Module (Using Templates)

```kcl
# For a web application:
import framework.templates.webapp as webapp
import framework.builders.deployment as deploy

schema MyApiService(webapp.WebAppModule):
    port = 8080
    serviceType = "ClusterIP"
    replicas = 2
    configData = {
        "application.yaml" = "server.port: 8080\nspring.profiles.active: ${SPRING_PROFILE}"
    }
    env = [
        { name = "SPRING_PROFILE", value = "dev" }
        { name = "DB_PASSWORD", valueFrom = { secretKeyRef = { name = "db-creds", key = "password" } } }
    ]
    resources = deploy.ResourceSpec {
        cpuRequest = "500m"
        memoryRequest = "1Gi"
        cpuLimit = "2"
        memoryLimit = "4Gi"
    }
    livenessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health"
        port = 8080
        initialDelaySeconds = 60
    }

my_api_service = MyApiService {
    name = "my-api"
    namespace = "apps"
    image = "ghcr.io/org/my-api"
    version = "1.0.0"
}
```

#### 11.2.3 Adding a Database (Operator-Managed)

```kcl
# Phase 6: Use operator template
import framework.templates.postgresql as pg

schema MyDatabase(pg.PostgreSQLClusterModule):
    instances = 3
    storageSize = "100Gi"
    pgVersion = "16"
    monitoring = True

my_db = MyDatabase {
    name = "my-db"
    namespace = "data"
}
```

```kcl
# Alternative: Use Bitnami Helm chart
import framework.templates.thirdparty.bitnami_postgresql as bpg

schema MyDatabase(bpg.BitnamiPostgreSQL):
    chartVersion = "16.4.3"
    values = {
        primary.persistence.size = "100Gi"
        auth.existingSecret = "pg-credentials"
        metrics.enabled = True
    }
```

#### 11.2.4 Composing a Stack

```kcl
import framework.assembly.helpers as asm
import framework.models.stack as stack_model

# Create namespaces
_apps_ns = asm.create_namespace("apps", instanceConfigurations)
_data_ns = asm.create_namespace("data", instanceConfigurations)

# Import modules
import modules.my_api as api
import modules.my_database as db

# Compose stack
my_stack = stack_model.Stack {
    components = [api.my_api_service.instance]
    accessories = [db.my_db.instance]
    namespaces = [_apps_ns, _data_ns]
}
```

#### 11.2.5 What High-Level PEs Never Touch

- `framework/builders/` — Builder lambdas (Low-Level PE territory)
- `framework/procedures/` — Output format procedures
- `framework/models/` — Core domain schemas
- `kcl.mod` at framework level

#### 11.2.6 Decision Matrix

| Scenario | Action |
|---|---|
| New microservice | Create `WebAppModule` in `modules/` |
| New database | Choose operator template or Bitnami wrapper |
| New environment | Create `sites/<env>/site_def.k` |
| New customer | Create `tenants/<customer>/tenant_def.k` |
| New deployment target | Create `pre_releases/` or `releases/` with factory |
| Custom infra component | Ask Low-Level PE to create builder/template |

### 11.3 Platform Engineer (Low-Level) Workflow

**Goal**: Design and maintain framework internals — schemas, builders, templates, procedures, and the output pipeline.

#### 11.3.1 Creating a New Builder

Builders are low-level lambdas that generate a single K8s manifest:

```kcl
# framework/builders/my_resource.k

schema MyResourceSpec:
    name: str
    namespace: str
    # ... resource-specific fields

    check:
        # Always add validation
        len(name) > 0, "name is required"

build_my_resource = lambda spec: MyResourceSpec -> any {
    {
        apiVersion = "my.api/v1"
        kind = "MyResource"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {
                "app.kubernetes.io/name" = spec.name
                "app.kubernetes.io/managed-by" = "idp-concept"
            }
        }
        spec = {
            # ... resource spec
        }
    }
}
```

**Testing requirement**: Every builder must have a matching `*_test.k` file:
```kcl
# framework/builders/my_resource_test.k
import builders.my_resource as res

test_build_my_resource = lambda {
    _spec = res.MyResourceSpec { name = "test", namespace = "ns" }
    _result = res.build_my_resource(_spec)
    assert _result.metadata.name == "test"
    assert _result.kind == "MyResource"
}
```

#### 11.3.2 Creating a New Template

Templates compose multiple builders into a high-level module:

```kcl
# framework/templates/my_template.k
import models.modules.component as component
import builders.deployment as deploy
import builders.service as svc
import builders.leader as leader

schema MyModule(component.Component):
    port: int
    serviceType: str = "ClusterIP"

    # Private computed fields
    _deployment = deploy.build_deployment(deploy.DeploymentSpec {
        name = name; namespace = namespace; image = image; version = version
        port = port
    })
    _service = svc.build_service(svc.ServiceSpec {
        name = name; namespace = namespace; port = port
        serviceType = serviceType
    })
    _leader = leader.build_component_leader(name, namespace)

    kind = "APPLICATION"
    leaders = [_leader]
    manifests = [_deployment, _service]
```

**Testing**: Due to the `kcl test` bug with auto-computed `instance` fields, test builder outputs individually (see `TESTING_STRATEGY.md`).

#### 11.3.3 Adding a New Output Procedure

```kcl
# framework/procedures/kcl_to_<format>.k
import models.stack as stack

generate_<format> = lambda input_stack: stack.Stack -> any {
    # Transform stack components/accessories/namespaces into target format
    # Return serializable output
}
```

#### 11.3.4 Importing Operator CRDs

When adding support for a new operator:

```bash
# 1. Download CRDs from operator
kubectl get crds -o yaml | grep "group: <operator-group>" > /tmp/crds.yaml
# Or download from GitHub release

# 2. Import to KCL schemas
kcl import --mode crd -f /tmp/crds.yaml -o framework/custom/<operator>/models/

# 3. Review generated schemas — may need manual tweaks
# 4. Create a template that wraps the CRDs with sensible defaults
# 5. Write tests for the new template
# 6. Update kcl.mod if new dependencies are needed
```

#### 11.3.5 Maintaining the Module System

```bash
# Verify all kcl.mod files resolve correctly
cd framework && kcl run main.k

# Run full test suite
cd framework && kcl test ./...

# Validate all projects compile
cd projects/erp_back/pre_releases/gitops/dev/factory && kcl run yaml_builder.k | kubeconform -summary

# After adding dependencies, delete lock file and re-resolve
rm kcl.mod.lock && kcl run main.k
```

#### 11.3.6 Low-Level PE Checklist for New Features

- [ ] Create builder with `check` blocks
- [ ] Write `*_test.k` file with tests for valid and invalid inputs
- [ ] Run `kcl test ./...` — all tests must pass
- [ ] Run `kubeconform` on at least one project's output
- [ ] Update `framework-builders.instructions.md` if new builder
- [ ] Update `copilot-instructions.md` directory mapping if new directory
- [ ] Update `IDP_EVOLUTION_PLAN.md` implementation progress if completing a planned item

---

## Implementation Progress — Testing & TDD

> This section tracks completed implementation work with dates and test evidence.

### Testing Infrastructure (Implemented)

**130 unit tests** covering the full framework, all passing via `kcl test ./...`.

| Layer | Test File | Tests | Status |
|---|---|---|---|
| **Builders** | `tests/builders/deployment_test.k` | 23 | PASS |
| **Builders** | `tests/builders/service_test.k` | 9 | PASS |
| **Builders** | `tests/builders/configmap_test.k` | 2 | PASS |
| **Builders** | `tests/builders/storage_test.k` | 5 | PASS |
| **Builders** | `tests/builders/service_account_test.k` | 2 | PASS |
| **Builders** | `tests/builders/leader_test.k` | 3 | PASS |
| **Models** | `tests/models/configurations_test.k` | 4 | PASS |
| **Models** | `tests/models/configurations_git_test.k` | 4 | PASS |
| **Models** | `tests/models/modules/k8snamespace_test.k` | 4 | PASS |
| **Models** | `tests/models/modules/common_test.k` | 7 | PASS |
| **Assembly** | `tests/assembly/helpers_test.k` | 3 | PASS |
| **Procedures** | `tests/procedures/helper_test.k` | 3 | PASS |
| **Procedures** | `tests/procedures/kusion_test.k` | 8 | PASS |
| **Procedures** | `tests/procedures/yaml_test.k` | 5 | PASS |
| **Procedures** | `tests/procedures/helm_values_test.k` | 5 | PASS |
| **Procedures** | `tests/procedures/helmfile_test.k` | 5 | PASS |
| **Procedures** | `tests/procedures/helm_test.k` | 5 | PASS |
| **Procedures** | `tests/procedures/argocd_test.k` | 5 | PASS |
| **Templates** | `tests/templates/webapp_test.k` | 8 | PASS |
| **Templates** | `tests/templates/database_test.k` | 8 | PASS |
| **Builders** | `tests/builders/network_policy_test.k` | 4 | PASS |
| **Builders** | `tests/builders/pdb_test.k` | 4 | PASS |
| **Models** | `tests/models/modules/secrets_test.k` | 6 | PASS |

#### Known Limitation: `kcl test` + Schema Instance Bug

Template schemas (WebAppModule, SingleDatabaseModule) cannot be directly instantiated in `kcl test` lambdas due to a KCL bug: when a parent schema (Component/Accessory) has an auto-computed `instance` field that references `manifests`, and `manifests` is computed from builder lambdas, `kcl test` evaluates the `instance` default before the child schema's private computed fields are resolved, causing `UndefinedType` errors. `kcl run` handles this correctly. **Workaround**: Template tests validate the individual builder outputs that templates compose. Full template integration is validated via `kcl run` + `kubeconform`.

### Phase 1 Completed Items

| Item | File(s) | Status |
|---|---|---|
| Remove hardcoded credentials | `mongodb_single_instance_module_def.k`, `video_collector_mongodb_python_module_def.k` | DONE — Replaced with `secretKeyRef` |
| Fix `imagePullPolicy` | `framework/templates/database.k` | DONE — Changed default `"Always"` → `"IfNotPresent"` |
| Fix code style | `framework/models/modules/accessory.k` | DONE — Consistent spacing |
| Fix `imagePullPolicy` (mongodb) | `mongodb_single_instance_module_def.k` | DONE — Changed `"Always"` → `"IfNotPresent"` |
| Externalize Git repo URL | `framework/models/configurations.k`, `erp_back/kernel/configurations.k`, `erp_back/.../argocd_builder.k` | DONE — Added `gitRepoUrl` to BaseConfigurations, removed hardcoded URL |

### Phase 2 Completed Items

| Item | File(s) | Status |
|---|---|---|
| Helm values extraction | `framework/procedures/helm_values.k` | DONE — `extract_helm_values` + `generate_chart` lambdas |
| Helmfile generation | `framework/procedures/kcl_to_helmfile.k` | DONE — `generate_helmfile` from components + accessories |
| kcl_to_helm expansion | `framework/procedures/kcl_to_helm.k` | DONE — `generate_chart_data` + `generate_charts_from_stack` lambdas |
| Static Helm Go templates | `framework/templates/helm/` | DONE — deployment, service, configmap, serviceaccount, pvc, _helpers.tpl |
| erp_back helmfile builder | `erp_back/.../factory/helmfile_builder.k` | DONE — Generates helmfile.yaml with per-component releases |
| erp_back chart+values builder | `erp_back/.../factory/chart_values_builder.k` | DONE — Uses `generate_charts_from_stack` |
| CLI `koncept render helmfile` | `platform_cli/koncept` | DONE — Strategy B pipeline: chart data + static templates + helmfile |
| Helm values tests (TDD) | `framework/tests/procedures/helm_values_test.k` | DONE — 5 tests |
| Helmfile tests (TDD) | `framework/tests/procedures/helmfile_test.k` | DONE — 5 tests |
| kcl_to_helm tests (TDD) | `framework/tests/procedures/helm_test.k` | DONE — 5 tests |
| Helm lint validation | erp-api chart | DONE — `helm lint` + `helm template` + kubeconform 2/2 valid |

### Phase 3 Completed Items

| Item | File(s) | Status |
|---|---|---|
| Check blocks: DeploymentSpec | `framework/builders/deployment.k` | DONE — port 1-65535, replicas >= 1 |
| Check blocks: ServiceSpec | `framework/builders/service.k` | DONE — port range, serviceType enum |
| Check blocks: PersistentVolumeSpec | `framework/builders/storage.k` | DONE — accessMode enum, reclaimPolicy enum |
| EnvVar schema + validation | `framework/models/modules/common.k` | DONE — KeySelector, EnvVarSource, EnvVar with check blocks |

### Phase 4 Completed Items

| Item | File(s) | Status |
|---|---|---|
| Configurable builder filenames | `platform_cli/koncept` | DONE — `resolve_builder` reads `koncept.yaml` or uses convention defaults |
| `koncept validate` command | `platform_cli/koncept` | DONE — Validates factory_seed.k compilation |
| CLI error handling wrapper | `platform_cli/koncept` | DONE — `kcl_run` wrapper with clear error messages |
| ArgoCD render default changed | `platform_cli/koncept` | DONE — Default builder is `yaml_builder.k` (not `kubernetes_manifests_builder.k`) |
| Generic render.k CLI support | `platform_cli/koncept` | DONE — Auto-detects `render.k` pattern, uses `-D output=TYPE` |
| Developer quickstart docs | `docs/DEVELOPER_QUICKSTART.md` | DONE — Prerequisites, commands, project structure, troubleshooting |

### Phase 5 Completed Items

| Item | File(s) | Status |
|---|---|---|
| ArgoCD Application generation | `framework/procedures/kcl_to_argocd.k` | DONE — `generate_application`, `generate_applications_from_stack`, `generate_app_project` |
| ArgoCD procedure tests (TDD) | `framework/tests/procedures/argocd_test.k` | DONE — 5 tests |
| erp_back ArgoCD builder refactor | `erp_back/.../factory/argocd_builder.k` | DONE — Uses framework procedure, generates for all components |
| NetworkPolicy builder (TDD) | `framework/builders/network_policy.k` | DONE — `NetworkPolicySpec` schema + `build_network_policy` lambda, dynamic policyTypes |
| NetworkPolicy tests | `framework/tests/builders/network_policy_test.k` | DONE — 4 tests (ingress, egress, both, deny-all) |
| PDB builder (TDD) | `framework/builders/pdb.k` | DONE — `PDBSpec` schema + `build_pdb` lambda, int|str support |
| PDB tests | `framework/tests/builders/pdb_test.k` | DONE — 4 tests (minAvailable, maxUnavailable, percentage, both) |
| Secret management schemas (TDD) | `framework/models/modules/secrets.k` | DONE — `SecretReference`, `ExternalSecret`, `build_external_secret` with check block validation |
| Secret management tests | `framework/tests/models/modules/secrets_test.k` | DONE — 6 tests (basic, optional, vault, custom refresh, invalid store, manifest generation) |

### Architecture Restructuring Completed Items

| Item | File(s) | Status |
|---|---|---|
| Generic render.k pattern | `framework/factory/render.k` | DONE — Single file replaces 5 builder files per factory; uses `option("output")` for yaml/argocd/helmfile/helm |
| Factory Seed Contract | All `factory_seed.k` files | DONE — Standardized exports: `_stack`, `_project_name`, `_git_repo_url`, `_manifest_path` |
| erp_back stg environment | `sites/development/stg_cluster/`, `pre_releases/gitops/stg/` | DONE — Full stg site config + factory with render.k |
| erp_back releases structure | `releases/v1_0_0_production/`, `stacks/versioned/v1_0_0/` | DONE — Versioned stack, production site, transitive deps via `erp_back = { path = "../" }` |
| CLI render.k auto-detection | `platform_cli/koncept` | DONE — `has_render_k` function; new pattern uses `-D output=TYPE`, legacy falls back to per-builder files |
| erp_back dev factory cleanup | `pre_releases/gitops/dev/factory/` | DONE — Removed 4 old builder files, replaced with render.k + factory_seed.k |

### Kubeconform Validation Results

| Project | Manifests | Valid | Invalid | Errors |
|---|---|---|---|---|
| erp_back (dev) | 8 | 8 | 0 | 0 |
| erp_back (stg) | 8 | 8 | 0 | 0 |
| erp_back (release v1.0.0) | 8 | 8 | 0 | 0 |
| video_streaming (dev) | 5 | 5 | 0 | 0 |

### Strategy Document

Full testing strategy: [`docs/TESTING_STRATEGY.md`](./TESTING_STRATEGY.md)

---

## 12. Work Matrix by User Profile

### Developer

| Phase | Task | Input | Output |
|---|---|---|---|
| 4 | Use `koncept validate` before rendering | CLI command | Validation result |
| 4 | Use `koncept render helmfile` for param charts | CLI command | Helm charts + values.yaml |
| 4 | Create per-environment value overrides | `env/<env>.yaml` files | Customized deployments |
| 5 | Report configuration issues via `koncept validate` | CLI output | Bug reports |
| 6 | Configure operator-managed database resources | Site/tenant YAML configs | Custom DB settings per env |
| 7 | Use `koncept render kustomize` (future) | CLI command | Kustomize overlays |

### Platform Engineer — High-Level

| Phase | Task | Input | Output |
|---|---|---|---|
| 1 | Fix hardcoded secrets in video_streaming modules | Module `.k` files | Secure `secretKeyRef` patterns |
| 1 | Add `gitRepoUrl` to project configurations | `BaseConfigurations` extension | Configurable ArgoCD sources |
| 2 | Create project-specific `values_builder.k` | Component configs | Generated `values.yaml` |
| 2 | Create project-specific `helmfile_builder.k` | Stack definition | Generated `helmfile.yaml` |
| 2 | Define per-environment value overrides | `env/*.yaml` files | Environment-specific configs |
| 3 | Migrate video_streaming modules to template pattern | Raw modules | Template-based modules |
| 4 | Write developer quickstart documentation | Architecture knowledge | `DEVELOPER_QUICKSTART.md` |
| 6 | Create operator-backed modules (PostgreSQL, Redis) | Operator CRDs + templates | Production database modules |
| 6 | Add Bitnami chart wrappers to stacks | ThirdParty module configs | Third-party integrations |
| 6 | Configure ExternalSecrets for vault integration | Secret store configs | Externalized secrets |

### Platform Engineer — Low-Level

| Phase | Task | Input | Output |
|---|---|---|---|
| 1 | Fix `imagePullPolicy` defaults | `database.k` | Consistent defaults |
| 1 | Fix accessory.k code style | `accessory.k` | Clean formatting |
| 2 | Implement `kcl_to_helmfile.k` procedure | Stack schema | Helmfile YAML generation |
| 2 | Expand `kcl_to_helm.k` with Chart + Values generation | Component schema | Helm Chart generation |
| 2 | Create Helm value extraction lambdas | Component manifests | `HelmValues` schema |
| 2 | Create static Helm template files | Builder patterns | `templates/*.tpl` |
| 2 | Update CLI `koncept render helmfile` flow | Nushell script | Full Helmfile pipeline |
| 3 | Create `EnvVar` schema + type safety | `common.k` | Typed env declarations |
| 3 | Add `check` validation blocks to builders | Builder schemas | Compile-time validation |
| 3 | Document justified `any` types | Framework models | Clear intent markers |
| 3 | Create KCL test infrastructure | Test patterns | `framework/tests/` |
| 4 | Implement `koncept validate` | CLI command | Pre-render validation |
| 4 | Implement `koncept init` scaffolding | CLI command | Project scaffolding |
| 4 | Remove hardcoded builder filenames | CLI refactor | Configurable builders |
| 5 | Implement `kcl_to_argocd.k` | Stack schema | ArgoCD Application CRDs |
| 5 | Create NetworkPolicy builder | Builder pattern | Network isolation |
| 5 | Create PDB builder | Builder pattern | HA guarantees |
| 5 | Design secret management schemas | Security patterns | Formalized secret refs |
| 6 | Import operator CRDs → KCL schemas | Operator CRDs | KCL schema definitions |
| 6 | Create PostgreSQL/Redis/MongoDB templates | Operator models | Production templates |
| 6 | Create ThirdPartyHelmSpec schema | Framework models | Helm chart integration |
| 6 | Create Bitnami chart catalog templates | Bitnami charts | IDP wrappers |
| 6 | Create ExternalSecret builder/template | Security models | Secret management |
| 7 | Implement `kcl_to_kustomize.k` procedure | Stack schema | Kustomize output |
| 7 | Implement KCL plugin integration layer | helm-kcl/kustomize-kcl | Mutation pipeline |
| 7 | Create OCI artifact publishing pipeline | Nushell CLI | `koncept publish` command |

---

## 13. Migration Guide: video_streaming → template pattern

The `video_streaming` project predates framework templates. Its modules use raw manifests (~190 lines each). The `erp_back` project demonstrates the recommended template pattern (~50 lines each, 74% reduction).

### Migration Steps Per Module

1. **Identify the module type**: APPLICATION → `WebAppModule`, database → `SingleDatabaseModule`, Kafka → `KafkaClusterModule`

2. **Create new module definition** using templates:
```kcl
import framework.templates.webapp as webapp
import framework.builders.deployment as deploy

schema MyAppModule(webapp.WebAppModule):
    port = 8080
    serviceType = "ClusterIP"
    resources = deploy.ResourceSpec {
        cpuRequest = "250m"
        memoryRequest = "512Mi"
    }
    livenessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/health"
        port = 8080
    }
    env = [
        { name = "DB_HOST", valueFrom = { secretKeyRef = { name = "db-creds", key = "host" } } }
    ]
```

3. **Compare outputs**: Run `kcl run` on both old and new module definitions, diff the YAML output.

4. **Replace module reference** in stack definition (update `.instance` reference).

5. **Remove old module file** once validated.

### Priority Order

| Module | Type | Complexity | Estimated Effort |
|---|---|---|---|
| `kafka_video_consumer_mongodb_python` | APPLICATION | Medium (env vars, MongoDB deps) | 1-2 hours |
| `mongodb_single_instance` | INFRASTRUCTURE | Low (basic DB pattern) | 30 min |
| `kafka_strimzi` | CRD | Requires `KafkaClusterModule` | 1 hour |

---

## Appendix A: Reference Patterns

### vfarcic/crossplane-kubernetes Pattern

Viktor Farcic's project (66% KCL + 30.6% Nushell) demonstrates:
- KCL source → generated YAML pipeline (`just package-generate`)
- Per-provider Compositions with KCL functions
- Kyverno Chainsaw testing for infrastructure
- `CLAUDE.md` with AI instruction patterns

**Applicable to our project**: Their KCL→YAML generation pipeline is similar to our `kcl_to_yaml` approach. Their testing with Chainsaw could inspire our test infrastructure.

### CNCF Platform Engineering Maturity Model

Key takeaways for our platform:
- **Level 3 target**: Treat the platform as a product — measure adoption, test user experience, publish roadmap
- **Self-service interfaces**: `koncept` CLI must enable developers without K8s knowledge
- **Measurable outcomes**: Track render success/failure rates, configuration drift detection

### Score Workload Specification

Score defines a platform-agnostic workload spec. While we use KCL as our spec language, Score's mental model (declare what you need, not how to deploy it) aligns with our template pattern where developers set `port`, `replicas`, `env` and the framework handles the rest.

---

## Appendix B: Implementation Priority

```
Phase 1 (Foundation) ✅            Phase 2 (Helmfile) ✅
├─ Security fixes (P0) ✅         ├─ HelmValues extraction ✅
├─ imagePullPolicy fix ✅          ├─ kcl_to_helmfile.k implementation ✅
└─ Code style cleanup ✅           ├─ kcl_to_helm.k expansion ✅
                                   ├─ Static Helm templates ✅
Phase 3 (Code Quality) ✅         ├─ values_builder.k implementation ✅
├─ EnvVar schema ✅                └─ CLI update for helmfile flow ✅
├─ check validation blocks ✅
├─ Document any types              Phase 4 (Developer Experience) ✅
└─ Test infrastructure ✅          ├─ koncept validate ✅
                                   ├─ koncept init (nice-to-have)
Phase 5 (Advanced) ✅              ├─ Configurable builder names ✅
├─ kcl_to_argocd.k ✅              ├─ Generic render.k + CLI support ✅
├─ NetworkPolicy builder ✅        └─ DEVELOPER_QUICKSTART.md ✅
├─ PDB builder ✅
├─ Secret management schemas ✅   Phase 6 (Production Infrastructure)
└─ Multi-component Helm charts    ├─ CloudNativePG operator template
                                  ├─ Redis operator template
Phase 7 (Ecosystem)               ├─ MongoDB (Bitnami chart wrapper)
├─ kcl_to_kustomize.k            ├─ ThirdPartyHelmSpec schema
├─ KCL plugin integration        ├─ Bitnami chart catalog
│  (helm-kcl, kustomize-kcl)     ├─ ExternalSecrets operator
├─ OCI artifact publishing        └─ Observability stack (Prometheus/Grafana)
└─ Jsonnet bundle consumption
```

### Proof-of-Concept → Production Transition Map

```
POC (current)                        Production Target
─────────────                        ──────────────────
Raw Deployments/StatefulSets    →    K8s Operators (CNPG, Redis, Strimzi)
Hand-crafted all manifests      →    Bitnami charts + operator CRDs
Hardcoded secrets in code       →    ExternalSecrets + Vault/Cloud KMS
No monitoring                   →    Prometheus + Grafana (auto-configured)
No network policies             →    NetworkPolicy per component
No HA guarantees                →    PDB + topology spread constraints
Single output format (YAML)     →    YAML + Helm + Helmfile + Kustomize + ArgoCD
Manual project setup            →    `koncept init` scaffolding
No validation before deploy     →    `koncept validate` + check blocks + kubeconform
No tests                        →    130 unit tests + integration validation
```
