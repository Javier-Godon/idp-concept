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
- [11. Phase 8 — Developer Portal: Backstage Catalog Foundation](#11-phase-8--developer-portal-backstage-catalog-foundation)
- [12. Phase 9 — Developer Portal: Plugin Integration & Auth](#12-phase-9--developer-portal-plugin-integration--auth)
- [13. Phase 10 — Developer Portal: Self-Service Scaffolder](#13-phase-10--developer-portal-self-service-scaffolder)
- [14. User Workflow Guides](#14-user-workflow-guides) — [Standalone: USER_WORKFLOW_GUIDES.md](./USER_WORKFLOW_GUIDES.md)
- [15. Work Matrix by User Profile](#15-work-matrix-by-user-profile) — [Standalone: WORK_MATRIX.md](./WORK_MATRIX.md)
- [16. Migration Guide: video_streaming → template pattern](#16-migration-guide-video_streaming--template-pattern) — [Standalone: MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)
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

| Aspect | Current (L2) | Target (L3) | How |
|---|---|---|---|
| **Investment** | Dedicated tooling (KCL, Nushell CLI) | Product-like platform with portal | Backstage instance + plugin ecosystem |
| **Interfaces** | CLI (`koncept`) requires knowledge of factory structure | CLI + Web portal (dual interface) | Backstage catalog + scaffolder wrapping `koncept` |
| **Operations** | Manual factory/builder creation per release | Automated provisioning, catalog sync | TeraSky Ingestor auto-syncs, scaffolder automates |
| **Adoption** | Engineers must learn KCL internals | Developers use portal for common tasks, CLI for power users | Backstage Templates → wizard-driven self-service |
| **Measurement** | No metrics | Track template usage, render times, adoption | Backstage analytics, `backstage.io/time-saved` annotation |

---

## 2. User Profiles

### Profile 1: Developer

**Role**: Application developer who deploys and configures their applications.

**Interaction**: Only Nushell CLI commands (`koncept`). Never edits `.k` files directly.

**Capabilities**:
- `koncept render argocd` — Generate K8s manifests for GitOps deployment
- `koncept render helmfile` — Generate Helm charts with parameterized values
- `koncept render kusion` — Generate Kusion spec
- `koncept render kustomize` — generates Kustomize structure
- `koncept render timoni` — generates Timoni CUE module (experimental)
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
| **No test infrastructure** | No `.test.k` files; regressions undetected | P2 | ✅ RESOLVED — 232 tests, full TDD workflow |
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
              │ kcl_to_kustomize(working)│
              │ kcl_to_timoni   (working)│
              │ kcl_to_crossplane(working)│
              └───────────────────────────┘
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
cd projects/<project>/pre_releases/manifests/<site>/

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

This phase replaces proof-of-concept raw manifests with production-grade Kubernetes operators and third-party Helm charts. The IDP must simplify deploying both **proprietary application code** AND **production infrastructure** (databases, messaging, caches, identity, secrets, search).

### 9.1 Infrastructure Operator Catalog

Every infrastructure service follows the same integration pattern:
1. **Install operator** — `ThirdParty` module for the operator's Helm chart
2. **Import CRDs** — `kcl import --mode crd` generates KCL schemas
3. **Create template** — `framework/templates/<service>.k` with sensible production defaults
4. **Add check blocks** — Compile-time validation (instances, storage, version pinning)
5. **Write tests** — TDD with `kcl test` for builder outputs

#### 9.1.1 PostgreSQL — CloudNativePG

| Detail | Value |
|---|---|
| **Operator** | [cloudnative-pg/cloudnative-pg](https://github.com/cloudnative-pg/cloudnative-pg) |
| **Stars / Contributors** | 8,300+ / 280+ |
| **License** | Apache-2.0 |
| **CNCF Status** | Sandbox → Incubation track |
| **CRDs** | `Cluster`, `Backup`, `ScheduledBackup`, `Pooler` |
| **Priority** | P0 — Most common database, Kubernetes-native HA, automated failover & backup |

```kcl
# Target API for Platform Engineer (High-Level):
schema MyPostgres(postgresql.PostgreSQLClusterModule):
    instances = 3
    storageSize = "50Gi"
    pgVersion = "16"
    backup = postgresql.BackupSpec {
        schedule = "0 3 * * *"
        retentionPolicy = "30d"
        destination = "s3://backups/pg"
    }
    monitoring = True
    pooler = postgresql.PoolerSpec {
        instances = 2
        pgbouncerPoolMode = "transaction"
    }
```

#### 9.1.2 MongoDB — MCK (MongoDB Controllers for Kubernetes)

| Detail | Value |
|---|---|
| **Operator** | [mongodb/mongodb-kubernetes](https://github.com/mongodb/mongodb-kubernetes) (MCK) |
| **Stars / Contributors** | 165 / 28 |
| **License** | Apache-2.0 |
| **CRDs** | `MongoDBCommunity`, `MongoDB` (Enterprise), `MongoDBMultiCluster` |
| **Priority** | P1 — Replaces deprecated `mongodb-kubernetes-operator` (EOL Nov 2025); unified Community+Enterprise |

> **Note**: MCK is the official successor. The old `mongodb/mongodb-kubernetes-operator` is deprecated. MCK supports replica sets, sharded clusters, TLS, SCRAM auth, and Prometheus monitoring out of the box.

```kcl
schema MyMongo(mongodb.MongoDBClusterModule):
    members = 3
    storageSize = "20Gi"
    version = "8.0.5"
    monitoring = True
    tls = True
```

#### 9.1.3 Kafka — Strimzi

| Detail | Value |
|---|---|
| **Operator** | [strimzi/strimzi-kafka-operator](https://github.com/strimzi/strimzi-kafka-operator) |
| **Stars / Contributors** | 4,900+ / 400+ |
| **License** | Apache-2.0 |
| **CNCF Status** | Sandbox |
| **CRDs** | `Kafka`, `KafkaTopic`, `KafkaUser`, `KafkaConnect`, `KafkaMirrorMaker2` |
| **Priority** | P1 — Already in project (`crossplane_v2/managed_resources/kafka_strimzi/`), needs template integration |

> Already partially integrated. Needs: KCL template wrapping existing CRDs into `KafkaClusterModule`.

#### 9.1.4 RabbitMQ — RabbitMQ Cluster Operator

| Detail | Value |
|---|---|
| **Operator** | [rabbitmq/cluster-operator](https://github.com/rabbitmq/cluster-operator) |
| **Stars / Contributors** | 1,100+ / 65 |
| **License** | MPL-2.0 |
| **CRDs** | `RabbitmqCluster` |
| **Priority** | P1 — Production-grade, official VMware/Broadcom project, v2.20.0, 81 releases |

```kcl
schema MyRabbitMQ(rabbitmq.RabbitMQClusterModule):
    replicas = 3
    storageSize = "10Gi"
    monitoring = True
    plugins = ["rabbitmq_management", "rabbitmq_prometheus"]
```

#### 9.1.5 OpenSearch — OpenSearch K8s Operator

| Detail | Value |
|---|---|
| **Operator** | [opensearch-project/opensearch-k8s-operator](https://github.com/opensearch-project/opensearch-k8s-operator) |
| **Stars / Contributors** | 534 / 134 |
| **License** | Apache-2.0 |
| **CRDs** | `OpenSearchCluster` |
| **Priority** | P2 — Search/analytics engine, supports Dashboards, TLS, multi-node pools, rolling upgrades |

```kcl
schema MyOpenSearch(opensearch.OpenSearchClusterModule):
    version = "2.19.2"
    dataPools = [opensearch.NodePool {
        component = "data"
        replicas = 3
        storageSize = "100Gi"
    }]
    dashboards = True
    monitoring = True
```

#### 9.1.6 HashiCorp Vault — Vault Secrets Operator (VSO)

| Detail | Value |
|---|---|
| **Operator** | [hashicorp/vault-secrets-operator](https://github.com/hashicorp/vault-secrets-operator) |
| **Stars / Contributors** | 577 / 45 |
| **License** | BUSL-1.1 (changed from MPL) |
| **CRDs** | `VaultStaticSecret`, `VaultDynamicSecret`, `VaultPKISecret`, `VaultAuth`, `VaultAuthGlobal`, `VaultConnection` |
| **Priority** | P1 — Syncs Vault secrets → K8s Secrets, integrates with ExternalSecrets pattern already in framework |

> **License warning**: BUSL-1.1 is NOT fully open-source. Free for non-competing use. Evaluate against your organization's policies. If BUSL is unacceptable, use **ExternalSecrets Operator** (Apache-2.0) as the Vault integration layer instead.

```kcl
schema MyVaultSecret(vault.VaultStaticSecretModule):
    mount = "secret"
    path = "data/myapp/config"
    destination = "myapp-secrets"
    refreshAfter = "1h"
```

#### 9.1.7 Valkey — Valkey Operator

| Detail | Value |
|---|---|
| **Operator** | [valkey-io/valkey-operator](https://github.com/valkey-io/valkey-operator) |
| **Stars / Contributors** | 157 / 14 |
| **License** | Apache-2.0 |
| **CRDs** | `Valkey` (v1alpha1) |
| **Priority** | P3 — **Early development, NOT production-ready**. No releases yet. |

> **⚠️ EARLY DEVELOPMENT**: The Valkey operator explicitly warns it is not ready for production. Monitor progress; for now use **OT-Container-Kit Redis Operator** (Redis/Valkey are protocol-compatible) or deploy Valkey via Helm chart as `ThirdParty` module.

**Fallback plan**: Valkey can run any Redis-compatible orchestration. Use OT Redis Operator with Valkey images, or deploy via Bitnami chart.

#### 9.1.8 Keycloak — Keycloak Operator (built into Keycloak)

| Detail | Value |
|---|---|
| **Operator** | [keycloak/keycloak](https://github.com/keycloak/keycloak) (operator directory in main repo) |
| **Stars / Contributors** | 25,000+ (main repo) |
| **License** | Apache-2.0 |
| **CNCF Status** | Incubation |
| **CRDs** | `Keycloak`, `KeycloakRealmImport` |
| **Priority** | P1 — Identity/SSO, CNCF Incubation, Quarkus-native, official operator ships with Keycloak |

> **Note**: The old `keycloak/keycloak-operator` repo is **archived** (Nov 2022, WildFly). The current operator lives inside the main `keycloak/keycloak` repository and uses the Quarkus distribution.

```kcl
schema MyKeycloak(keycloak.KeycloakModule):
    instances = 2
    hostname = "auth.example.com"
    database = keycloak.DatabaseSpec {
        vendor = "postgres"
        host = "pg-cluster-rw.data.svc"
        secretName = "keycloak-db-creds"
    }
    realmImports = ["realm-export.json"]
```

#### 9.1.9 QuestDB — Helm Chart (No Operator Available)

| Detail | Value |
|---|---|
| **Project** | [questdb/questdb](https://github.com/questdb/questdb) |
| **Stars** | 16,800+ |
| **License** | Apache-2.0 |
| **K8s Support** | Official Helm chart (no operator exists) |
| **Priority** | P3 — Time-series DB, niche use case, deploy as `ThirdParty` Helm chart |

> **No Kubernetes operator exists** for QuestDB. Deploy via the official Helm chart as a `ThirdParty` module. QuestDB is a single-node database (HA requires Enterprise edition).

```kcl
schema MyQuestDB(thirdparty.ThirdPartyHelmModule):
    chart = "questdb/questdb"
    version = "0.32.0"
    values = {
        persistence.size = "50Gi"
        service.$type = "ClusterIP"
        resources.requests.memory = "4Gi"
        resources.limits.memory = "8Gi"
    }
```

#### 9.1.10 Redis — OT-Container-Kit Operator

| Detail | Value |
|---|---|
| **Operator** | [OT-CONTAINER-KIT/redis-operator](https://github.com/OT-CONTAINER-KIT/redis-operator) |
| **Stars / Contributors** | 1,300+ / 50+ |
| **License** | Apache-2.0 |
| **CRDs** | `Redis`, `RedisCluster`, `RedisSentinel`, `RedisReplication` |
| **Priority** | P1 — Covers Redis AND Valkey (protocol-compatible), standalone/cluster/replication/sentinel modes |

```kcl
schema MyRedis(redis.RedisModule):
    mode = "cluster"                     # "standalone" | "cluster" | "replication" | "sentinel"
    clusterSize = 3
    storageSize = "10Gi"
    monitoring = True
    exporter = True
```

#### 9.1.11 MinIO — MinIO Operator (Archived) + Bitnami Helm Chart

| Detail | Value |
|---|---|
| **Operator** | [minio/operator](https://github.com/minio/operator) |
| **Stars / Contributors** | 1,400+ / 151 |
| **License** | AGPL-3.0 (free, open-source, copyleft) |
| **CRDs** | `Tenant` (`minio.min.io/v2`) |
| **Helm Alternative** | `oci://registry-1.docker.io/bitnamicharts/minio` (Apache-2.0) |
| **Priority** | P2 — S3-compatible object storage, high-performance, Kubernetes-native |

> **⚠️ ARCHIVED**: The minio/operator was archived March 20, 2026 (last release v7.1.1). The Tenant CRD still works on existing clusters but **no new features or security patches** will be released. The IDP template provides both approaches:
> - `MinIOTenantSpec` + `build_minio_tenant` — Uses the operator Tenant CRD (for clusters with the operator already installed)
> - `MinIOHelmSpec` + `build_minio_helm` — Uses the Bitnami Helm chart (recommended for new deployments)

```kcl
# Option 1: Operator Tenant CRD (existing operator installations)
schema MyMinIO:
    _spec = minio.MinIOTenantSpec {
        name = "my-minio"
        namespace = "storage"
        servers = 4
        volumesPerServer = 4
        storageSize = "100Gi"
    }
    manifests = [minio.build_minio_tenant(_spec)]

# Option 2: Bitnami Helm chart (recommended for new deployments)
schema MyMinIOHelm:
    _spec = minio.MinIOHelmSpec {
        name = "my-minio"
        namespace = "storage"
        mode = "distributed"
        replicas = 4
        storageSize = "100Gi"
    }
    manifests = [minio.build_minio_helm(_spec)]
```

#### 9.1.12 OpenTelemetry — OpenTelemetry Operator

| Detail | Value |
|---|---|
| **Operator** | [open-telemetry/opentelemetry-operator](https://github.com/open-telemetry/opentelemetry-operator) |
| **Stars / Contributors** | 1,700+ / 268 |
| **License** | Apache-2.0 |
| **CNCF Status** | Part of CNCF OpenTelemetry project (Graduated) |
| **CRDs** | `OpenTelemetryCollector`, `Instrumentation`, `OpAMPBridge`, `TargetAllocator` |
| **Helm Chart** | `open-telemetry/opentelemetry-operator` (chart v0.109.0, appVersion v0.148.0) |
| **Priority** | P1 — Unified observability (traces, metrics, logs), CNCF Graduated, auto-instrumentation for Java/Python/Node.js/.NET/Go |

> **Key capabilities**: The operator manages OpenTelemetry Collector instances (deployment, daemonset, statefulset, sidecar modes) and auto-instrumentation injection. The Target Allocator distributes Prometheus scrape targets across collector replicas. Supports ServiceMonitor/PodMonitor discovery from prometheus-operator ecosystem.

```kcl
# Deploy operator + collector + auto-instrumentation:
import framework.templates.opentelemetry as otel

_operator = otel.build_otel_operator(otel.OtelOperatorSpec {
    name = "opentelemetry-operator"
    namespace = "opentelemetry"
})

_collector = otel.build_otel_collector(otel.OtelCollectorSpec {
    name = "otel-collector"
    namespace = "opentelemetry"
    mode = "deployment"
    replicas = 2
})

_instrumentation = otel.build_instrumentation(otel.InstrumentationSpec {
    name = "auto-instrumentation"
    namespace = "apps"
    exporterEndpoint = "http://otel-collector.opentelemetry.svc:4317"
    propagators = ["tracecontext", "baggage", "b3"]
})
```

### 9.2 Infrastructure Catalog Summary

| Service | Operator / Chart | License | Stars | Maturity | Priority |
|---|---|---|---|---|---|
| **PostgreSQL** | CloudNativePG | Apache-2.0 | 8,300+ | CNCF Sandbox | P0 |
| **MongoDB** | MCK (mongodb-kubernetes) | Apache-2.0 | 165 | Official MongoDB | P1 |
| **Kafka** | Strimzi | Apache-2.0 | 4,900+ | CNCF Sandbox | P1 |
| **RabbitMQ** | cluster-operator | MPL-2.0 | 1,100+ | Official Broadcom | P1 |
| **Redis** | OT Redis Operator | Apache-2.0 | 1,300+ | Production | P1 |
| **Keycloak** | keycloak (built-in) | Apache-2.0 | 25,000+ | CNCF Incubation | P1 |
| **Vault** | VSO | BUSL-1.1 ⚠️ | 577 | HashiCorp Official | P1 |
| **OpenTelemetry** | opentelemetry-operator | Apache-2.0 | 1,700+ | CNCF Graduated | P1 |
| **MinIO** | minio/operator (archived) + Bitnami | AGPL-3.0 / Apache-2.0 | 1,400+ | ⚠️ Archived 2026 | P2 |
| **OpenSearch** | opensearch-k8s-operator | Apache-2.0 | 534 | OpenSearch Project | P2 |
| **Valkey** | valkey-operator | Apache-2.0 | 157 | ⚠️ Early dev | P3 |
| **QuestDB** | Helm chart (no operator) | Apache-2.0 | 16,800+ | Helm only | P3 |

### 9.3 ThirdParty Module Enhancement

Enhance `framework/models/modules/thirdparty.k`:

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

### 9.4 Observability Stack

```kcl
schema MonitoringStack:
    """Deploy Prometheus + Grafana + OpenTelemetry via kube-prometheus-stack."""
    prometheus: ThirdPartyHelmSpec = ThirdPartyHelmSpec {
        name = "prometheus"
        chart = "oci://registry-1.docker.io/bitnamicharts/kube-prometheus"
        version = "10.2.0"
    }
    grafana: ThirdPartyHelmSpec = ThirdPartyHelmSpec {
        name = "grafana"
        chart = "oci://registry-1.docker.io/bitnamicharts/grafana"
        version = "11.3.0"
    }
    serviceMonitors?: [ServiceMonitorSpec]
```

**OpenTelemetry integration**: The `framework/templates/opentelemetry.k` template provides:
- `OtelOperatorSpec` + `build_otel_operator` — Deploys the operator via Helm chart (`open-telemetry/opentelemetry-operator` v0.109.0)
- `OtelCollectorSpec` + `build_otel_collector` — Generates `OpenTelemetryCollector` CRDs (deployment/daemonset/statefulset/sidecar modes) with OTLP receivers, processors, and exporters
- `InstrumentationSpec` + `build_instrumentation` — Generates `Instrumentation` CRDs for auto-instrumentation injection (Java, Python, Node.js, .NET, Go)

The OpenTelemetry Collector integrates with Prometheus via the Target Allocator, enabling ServiceMonitor/PodMonitor-based metrics collection alongside the existing Prometheus stack.

### 9.5 Strategy: Operator vs Helm Chart

| Criteria | Use Operator | Use Helm Chart |
|---|---|---|
| **Stateful with HA** | PostgreSQL, Kafka, RabbitMQ, MongoDB | Simpler single-instance deployments |
| **Custom lifecycle** | Backup/restore, major upgrades, failover | Standard install/upgrade |
| **CRD-based API** | Need declarative K8s-native API | Standard values.yaml is sufficient |
| **License concerns** | All Apache-2.0 / MPL-2.0 ✅ | Vault VSO: BUSL-1.1 ⚠️ |
| **No operator exists** | — | QuestDB, Valkey (for now) |

**Recommended defaults**:
- PostgreSQL → **CloudNativePG** (CNCF, HA, backup)
- MongoDB → **MCK** (official Apache-2.0 operator)
- Kafka → **Strimzi** (already in project)
- RabbitMQ → **cluster-operator** (official, production-grade)
- Redis/Valkey → **OT Redis Operator** (compatible with both)
- Keycloak → **Keycloak Operator** (CNCF Incubation, built-in)
- Vault → **VSO** if BUSL acceptable; else **ExternalSecrets Operator** (Apache-2.0)
- OpenSearch → **opensearch-k8s-operator** (Apache-2.0)
- QuestDB → **Helm chart** as ThirdParty module
- Valkey → **OT Redis Operator** with Valkey images (until valkey-operator matures)

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

### 10.5 Timoni / CUE Output Format (`kcl_to_timoni`)

**Priority**: P3 — Experimental. [Timoni](https://timoni.sh/) is a CUE-powered Kubernetes package manager (1.9k stars, Apache-2.0, v0.26.0). It is an alternative to Helm that uses CUE instead of Go templates.

> **⚠️ MATURITY WARNING**: Timoni explicitly states "APIs may change in backwards incompatible manner." Treat this output format as experimental.

#### Why Timoni?

- **Type-safe** values (CUE constraints vs Helm's untyped `values.yaml`)
- **OCI-native** distribution (push/pull modules from OCI registries)
- **Drift detection** built-in
- **CRD import** support (`timoni mod vendor crds`)

#### Integration Approach

KCL→CUE is NOT an automatic language conversion. KCL and CUE are different configuration languages with different type systems. The integration strategy:

**Option A — Generate raw YAML, wrap in CUE module** (recommended, simpler):
1. Use existing `kcl_to_yaml` to produce K8s manifests
2. Generate a minimal Timoni module structure that embeds the YAML as CUE values
3. Create `timoni.cue`, `values.cue`, and `templates/` with raw manifest embedding

```
output/timoni/<stack-name>/
├── timoni.cue                    # Module metadata (apiVersion, name, version)
├── values.cue                    # Generated from IDP config (tenant/site overrides)
├── templates/
│   ├── config.cue                # Module config schema
│   └── resources.cue             # K8s manifests as CUE objects
└── README.md                     # Auto-generated module docs
```

**Option B — Generate native CUE** (complex, higher fidelity):
1. Map KCL schemas → CUE definitions
2. Generate `values.cue` constraints from BaseConfigurations + check blocks
3. Generate resource templates using `timoni.sh/core` schemas

#### Implementation

```kcl
# framework/procedures/kcl_to_timoni.k
_timoni_module = lambda stack: RenderStack, configs: any -> {str:any} {
    # Generate Timoni module structure
    _manifests = [m for module in stack.modules for m in module.manifests]
    {
        "timoni.cue" = _generate_timoni_metadata(stack)
        "values.cue" = _generate_values_cue(configs)
        "templates/resources.cue" = _generate_resources_cue(_manifests)
    }
}
```

```nushell
# CLI integration in platform_cli/koncept
# koncept render timoni
"timoni" => {
    let output_path = $"($output_dir)/timoni/($stack_name)"
    mkdir $output_path
    ^kcl run factory/ -D output=timoni | save $"($output_path)/module.cue"
}
```

#### Deliverables

- `framework/procedures/kcl_to_timoni.k` — CUE module generation from Stack
- `render.k` updated with `output == "timoni"` branch
- `platform_cli/koncept` updated with `timoni` render target
- Tests: `framework/tests/procedures/kcl_to_timoni_test.k`
- Documentation in `docs/DEVELOPER_GUIDE.md` under output formats

---

## 11. Phase 8 — Developer Portal: Backstage Catalog Foundation

**Owner**: Platform Engineer (Low-Level) for procedures; Platform Engineer (High-Level) for configuration
**CNCF Target**: Level 2 → Level 3 (Scalable) — Self-service interfaces
**Prerequisite**: Phases 1-7 completed ✅
**Reference**: [docs/BACKSTAGE_ADOPTION_ANALYSIS.md](./BACKSTAGE_ADOPTION_ANALYSIS.md)

> Backstage (CNCF Incubation, 33k+ stars, Apache-2.0) is the only viable free OSS developer portal. It provides a service catalog, software templates (scaffolder), TechDocs, and 205+ active plugins. See the full analysis in `BACKSTAGE_ADOPTION_ANALYSIS.md`.

### 11.1 `kcl_to_backstage` Output Procedure (TDD)

New output procedure to generate Backstage `catalog-info.yaml` descriptors from the KCL Stack model. Follows the same TDD pattern as all existing procedures.

**Entity mapping**:

| idp-concept Model | Backstage Kind | `spec.type` |
|---|---|---|
| Project | Domain | `product-area` |
| Stack | System | `product` |
| Component (APPLICATION) | Component | `service` |
| Component (INFRASTRUCTURE) | Resource | `database`, `cache`, `message-queue` |
| Accessory (CRD) | Resource | `kubernetes-crd` |
| Accessory (SECRET) | Resource | `secret` |
| ThirdParty (HELM) | Component | `library` |
| Pre-release | `spec.lifecycle` | `experimental` |
| Release | `spec.lifecycle` | `production` |

**Implementation**:

```kcl
# framework/procedures/kcl_to_backstage.k
import models.stack as stack

_BACKSTAGE_API_VERSION = "backstage.io/v1alpha1"

generate_backstage_component = lambda name: str, spec: any, system_name: str -> {str:any} {
    apiVersion = _BACKSTAGE_API_VERSION
    kind = "Component"
    metadata = {
        name = name
        annotations = {
            "backstage.io/kubernetes-id" = name
            "koncept.io/module-type" = spec.moduleType or "Component"
        }
    }
    spec = {
        type = "service"
        lifecycle = spec.lifecycle or "production"
        owner = spec.owner or "platform-team"
        system = system_name
    }
}

generate_backstage_resource = lambda name: str, resource_type: str, system_name: str -> {str:any} {
    apiVersion = _BACKSTAGE_API_VERSION
    kind = "Resource"
    metadata.name = name
    spec = {
        type = resource_type
        lifecycle = "production"
        owner = "platform-team"
        system = system_name
    }
}

generate_backstage_system = lambda stack_name: str, domain_name: str -> {str:any} {
    apiVersion = _BACKSTAGE_API_VERSION
    kind = "System"
    metadata.name = stack_name
    spec = {
        owner = "platform-team"
        domain = domain_name
    }
}

generate_backstage_domain = lambda project_name: str -> {str:any} {
    apiVersion = _BACKSTAGE_API_VERSION
    kind = "Domain"
    metadata.name = project_name
    spec.owner = "platform-team"
}

generate_catalog_from_stack = lambda input_stack: stack.Stack, project_name: str -> [any] {
    # Compose all entity types from stack into a catalog-info document
    _domain = generate_backstage_domain(project_name)
    _system = generate_backstage_system(input_stack.name, project_name)
    _components = [generate_backstage_component(c.name, c, input_stack.name) for c in input_stack.components if c.kind == "APPLICATION"]
    _resources = [generate_backstage_resource(c.name, "database", input_stack.name) for c in input_stack.components if c.kind == "INFRASTRUCTURE"]
    _accessory_resources = [generate_backstage_resource(a.name, "kubernetes-crd", input_stack.name) for a in input_stack.accessories]
    [_domain, _system] + _components + _resources + _accessory_resources
}
```

**Deliverables**:
- `framework/procedures/kcl_to_backstage.k`
- `framework/tests/procedures/backstage_test.k` — 10+ tests
- Integration into `framework/factory/render.k` (`output == "backstage"` branch)
- CLI support: `koncept render backstage`

### 11.2 Backstage Annotations in K8s Manifests

Add annotations to generated K8s manifests so the TeraSky Kubernetes Ingestor can auto-create catalog entities from deployed resources.

**Annotations to add**:

```yaml
metadata:
  annotations:
    terasky.backstage.io/owner: "platform-team"
    terasky.backstage.io/system: "<stack-name>"
    terasky.backstage.io/lifecycle: "production"
    terasky.backstage.io/component-type: "service"
    terasky.backstage.io/source-code-repo-url: "<git-repo-url>"
```

**Changes**:
- Extend `framework/models/configurations.k` `BaseConfigurations` with optional `backstageOwner: str`, `backstageSystem: str`
- Update `framework/builders/deployment.k` to inject these as annotations when present
- Source values from factory_seed context (project name, git repo URL, tenant)

### 11.3 Backstage Instance Setup

Deploy a Backstage instance to the target cluster:

- **PostgreSQL**: Use existing CloudNativePG template (`framework/templates/postgresql.k`)
- **Backstage app**: Node.js + React, deployed via Helm chart ([backstage/charts](https://github.com/backstage/charts))
- **app-config.yaml**: Catalog locations pointing to monorepo `catalog-info.yaml` files
- **Authentication**: GitHub OAuth or Keycloak (Red Hat plugin) for SSO

**Infrastructure as KCL**:
- New `framework/templates/backstage.k` template (or ThirdPartyHelmSpec wrapping the Backstage Helm chart)
- PostgreSQL instance from `framework/templates/postgresql.k`
- Ingress configuration

---

## 12. Phase 9 — Developer Portal: Plugin Integration & Auth

**Owner**: Platform Engineer (High-Level) for configuration; Developer for testing

### 12.1 Core Plugin Installation (Tier 1 — Day One)

| Plugin | By | Purpose |
|---|---|---|
| **Kubernetes** | Backstage Core | View pods, deployments, objects across clusters |
| **Kubernetes Ingestor** | TeraSky | Auto-create catalog entities from deployed K8s resources and Crossplane claims |
| **Crossplane Resources** | TeraSky | View Crossplane claim/XR/managed resource graph and YAML |
| **Argo CD** | Roadie | View ArgoCD sync status and health per application |
| **Catalog Graph** | SDA SE | Visualize entity relationships (dependency graphs) |

### 12.2 Auth & RBAC via Keycloak

- Install Keycloak auth plugin (Red Hat) for SSO
- Map Keycloak roles to Backstage permissions:
  - `developer` → read-only catalog + template usage
  - `platform-engineer` → full catalog + admin access
  - `manager` → read-only catalog + metrics
- Use existing Keycloak instance (already have Keycloak template in `framework/templates/keycloak.k`)

### 12.3 TechDocs

- Configure TechDocs to read Markdown from `docs/` directory
- Add `backstage.io/techdocs-ref` annotation to catalog entities
- Generate TechDocs from existing documentation (DEVELOPER_GUIDE.md, DEVELOPER_QUICKSTART.md, PROJECT_ARCHITECTURE.md)

### 12.4 Observability Plugin Stack (Tier 2)

| Plugin | Purpose |
|---|---|
| **Kafka** | Monitor Strimzi clusters and topics |
| **Vault** | Visualize secrets |
| **Grafana** | Embed monitoring dashboards per service |
| **Prometheus** | Metrics and alerts per service |
| **GitHub Actions** | CI/CD pipeline status |

---

## 13. Phase 10 — Developer Portal: Self-Service Scaffolder

**Owner**: Platform Engineer (Low-Level) for custom actions; Platform Engineer (High-Level) for templates

### 13.1 Custom Scaffolder Actions (TypeScript)

Create TypeScript actions wrapping the `koncept` Nushell CLI. Actions follow the Backstage `createTemplateAction` pattern:

```typescript
// backstage-plugin-koncept/src/actions/render.ts
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { z } from 'zod';

export const konceptRenderAction = createTemplateAction({
  id: 'koncept:render',
  description: 'Render KCL manifests using koncept CLI',
  schema: {
    input: z.object({
      output: z.enum(['argocd', 'helmfile', 'kusion', 'crossplane', 'kustomize', 'timoni', 'backstage']),
      factory: z.string().optional(),
    }),
  },
  async handler(ctx) {
    const { output, factory } = ctx.input;
    // Execute koncept render (Nushell CLI wrapping KCL)
    // Never pass raw user input to shell — sanitize via zod schema
  },
});
```

**Actions to implement**:
- `koncept:render` — render manifests in specified format
- `koncept:validate` — validate configurations
- `koncept:init` — scaffold new project/release
- `koncept:publish` — publish KCL module to OCI registry

### 13.2 Backstage Templates (Scaffolder Wizard)

Map our KCL framework templates to Backstage Software Templates:

| Backstage Template | KCL Template | What it creates |
|---|---|---|
| "New Web Application" | `WebAppModule` | Service + Deployment + ConfigMap |
| "New PostgreSQL Database" | `PostgreSQLClusterModule` | CloudNativePG Cluster |
| "New Kafka Cluster" | `KafkaClusterModule` | Strimzi Kafka + topics |
| "New Redis Cache" | `RedisModule` | Redis standalone/cluster |
| "New MongoDB" | `MongoDBCommunityModule` | MongoDB Community Operator |
| "New RabbitMQ Cluster" | `RabbitMQClusterModule` | RabbitMQ cluster-operator |
| "New Release" | `koncept init` | Complete factory structure |
| "Deploy to Environment" | `koncept render` | Rendered manifests for target |

Each template is a YAML file with `spec.parameters` (wizard form fields) and `spec.steps` (actions to execute):

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: new-web-application
  title: New Web Application
  description: Create a new web application using the KCL WebAppModule template
  tags: [kcl, kubernetes, webapp]
spec:
  owner: platform-team
  type: service
  parameters:
    - title: Application Details
      properties:
        name:
          title: Application Name
          type: string
        port:
          title: Port
          type: integer
          default: 8080
        replicas:
          title: Replicas
          type: integer
          default: 1
  steps:
    - id: scaffold
      name: Scaffold KCL module
      action: koncept:init
      input:
        template: webapp
        name: ${{ parameters.name }}
    - id: render
      name: Render manifests
      action: koncept:render
      input:
        output: argocd
    - id: publish
      name: Open Pull Request
      action: publish:github:pull-request
      input:
        repoUrl: ${{ parameters.repoUrl }}
        title: "feat: add ${{ parameters.name }}"
```

### 13.3 Self-Service Workflow (End-to-End)

```
Developer clicks "New Web Application" in Backstage
    ↓
Backstage Template wizard collects: name, port, replicas, environment
    ↓
Step 1: koncept:init → creates KCL module from WebAppModule template
Step 2: koncept:validate → validates generated configuration
Step 3: koncept:render → generates K8s manifests
Step 4: publish:github:pull-request → creates PR in Git repo
    ↓
Platform engineer reviews and merges PR
    ↓
ArgoCD syncs manifests to cluster
    ↓
TeraSky Kubernetes Ingestor auto-creates catalog entity in Backstage
    ↓
Developer sees their new service in Backstage catalog with health status
```

### 13.4 CLI and Portal Coexistence

The `koncept` Nushell CLI remains the primary build/render tool. Backstage is the self-service UI layer:

| Use CLI (`koncept`) | Use Portal (Backstage) |
|---|---|
| Platform engineer developing templates | Developer creating a new service |
| CI/CD pipeline rendering manifests | Developer deploying to a new environment |
| Debugging a failed render | Viewing deployment health |
| Publishing a KCL module | Discovering what services exist |
| Offline/local development | New team member onboarding |

---

## 14. User Workflow Guides

> Developer-oriented documentation for each of the three user profiles. Each section describes **what the user does**, **how they do it**, and **what they should never need to know**.

### 14.1 Developer Workflow

**Goal**: Deploy and configure applications with zero Kubernetes knowledge.

#### 14.1.1 Day-to-Day Commands

```bash
# 1. Navigate to your release
cd projects/my-project/pre_releases/manifests/dev/factory

# 2. Validate configuration (catch errors before rendering)
koncept validate

# 3. Render manifests for GitOps
koncept render argocd          # Plain K8s YAML → commit to Git → ArgoCD syncs

# 4. Render Helm charts for environment customization
koncept render helmfile        # Helm charts + values.yaml + helmfile.yaml

# 5. Check what changed
koncept diff                   # (Phase 4) Compare current vs previous render
```

#### 14.1.2 What Developers Configure

Developers customize their applications through **site configuration files** (YAML-friendly KCL). They never write raw K8s manifests.

| What to Change | Where | Example |
|---|---|---|
| Replicas | `sites/<site>/site_def.k` | `replicas = 3` |
| Environment variables | `sites/<site>/site_def.k` | `springProfile = "production"` |
| Resource limits | `sites/<site>/site_def.k` | `memoryLimit = "4Gi"` |
| Feature flags | `tenants/<tenant>/tenant_def.k` | `featureNewUI = True` |
| Image version | `sites/<site>/site_def.k` | `version = "2.1.0"` |

#### 14.1.3 What Developers Never Touch

- `framework/` — Platform internals
- `modules/*_module_def.k` — Module schemas (contact Platform Eng)
- `factory/` — Auto-generated builder files
- `stacks/` — Stack composition (contact Platform Eng)
- `kcl.mod` — Package dependencies

#### 14.1.4 Troubleshooting for Developers

| Problem | Solution |
|---|---|
| `koncept validate` fails | Check error message — usually a config value out of range or missing |
| `koncept render` fails with KCL error | Run `koncept validate` first; if still fails, contact Platform Engineer |
| "Cannot find module" error | You're in the wrong directory — `cd` to the `factory/` folder |
| Application not deploying | Check ArgoCD UI → sync status; check events for K8s errors |
| Need a new environment variable | Add to site config file, run `koncept render`, commit to Git |

### 14.2 Platform Engineer (High-Level) Workflow

**Goal**: Compose deployment topologies — stacks, tenants, sites, modules — using pre-built templates.

#### 14.2.1 Creating a New Project

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

#### 14.2.2 Creating a Module (Using Templates)

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

#### 14.2.3 Adding a Database (Operator-Managed)

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

#### 14.2.4 Composing a Stack

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

#### 14.2.5 What High-Level PEs Never Touch

- `framework/builders/` — Builder lambdas (Low-Level PE territory)
- `framework/procedures/` — Output format procedures
- `framework/models/` — Core domain schemas
- `kcl.mod` at framework level

#### 14.2.6 Decision Matrix

| Scenario | Action |
|---|---|
| New microservice | Create `WebAppModule` in `modules/` |
| New database | Choose operator template or Bitnami wrapper |
| New environment | Create `sites/<env>/site_def.k` |
| New customer | Create `tenants/<customer>/tenant_def.k` |
| New deployment target | Create `pre_releases/` or `releases/` with factory |
| Custom infra component | Ask Low-Level PE to create builder/template |

### 14.3 Platform Engineer (Low-Level) Workflow

**Goal**: Design and maintain framework internals — schemas, builders, templates, procedures, and the output pipeline.

#### 14.3.1 Creating a New Builder

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

#### 14.3.2 Creating a New Template

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

#### 14.3.3 Adding a New Output Procedure

```kcl
# framework/procedures/kcl_to_<format>.k
import models.stack as stack

generate_<format> = lambda input_stack: stack.Stack -> any {
    # Transform stack components/accessories/namespaces into target format
    # Return serializable output
}
```

#### 14.3.4 Importing Operator CRDs

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

#### 14.3.5 Maintaining the Module System

```bash
# Verify all kcl.mod files resolve correctly
cd framework && kcl run main.k

# Run full test suite
cd framework && kcl test ./...

# Validate all projects compile
cd projects/erp_back/pre_releases/manifests/dev/factory && kcl run yaml_builder.k | kubeconform -summary

# After adding dependencies, delete lock file and re-resolve
rm kcl.mod.lock && kcl run main.k
```

#### 14.3.6 Low-Level PE Checklist for New Features

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

**287 unit tests** covering the full framework, all passing via `kcl test ./...`.

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
| **Templates** | `tests/templates/observability_test.k` | 8 | PASS |
| **Procedures** | `tests/procedures/kustomize_test.k` | 8 | PASS |
| **Models** | `tests/models/modules/thirdparty_helm_test.k` | 5 | PASS |
| **Templates** | `tests/templates/postgresql_test.k` | 10 | PASS |
| **Templates** | `tests/templates/mongodb_test.k` | 6 | PASS |
| **Templates** | `tests/templates/rabbitmq_test.k` | 7 | PASS |
| **Templates** | `tests/templates/redis_test.k` | 6 | PASS |
| **Templates** | `tests/templates/keycloak_test.k` | 5 | PASS |
| **Templates** | `tests/templates/opensearch_test.k` | 8 | PASS |
| **Templates** | `tests/templates/vault_test.k` | 7 | PASS |
| **Templates** | `tests/templates/questdb_test.k` | 4 | PASS |
| **Templates** | `tests/templates/minio_test.k` | 8 | PASS |
| **Templates** | `tests/templates/opentelemetry_test.k` | 13 | PASS |
| **Procedures** | `tests/procedures/timoni_test.k` | 11 | PASS |
| **Procedures** | `tests/procedures/crossplane_test.k` | 25 | PASS |
| **Procedures** | `tests/procedures/backstage_test.k` | 14 | PASS |
| **Templates** | `tests/templates/backstage_test.k` | 5 | PASS |

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
| `koncept init` scaffolding | `platform_cli/koncept` | DONE — Copies render.k from framework, generates factory_seed.k template |

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
| erp_back stg environment | `sites/development/stg_cluster/`, `pre_releases/manifests/stg/` | DONE — Full stg site config + factory with render.k |
| erp_back releases structure | `releases/v1_0_0_production/`, `stacks/versioned/v1_0_0/` | DONE — Versioned stack, production site, transitive deps via `erp_back = { path = "../" }` |
| CLI render.k auto-detection | `platform_cli/koncept` | DONE — `has_render_k` function; new pattern uses `-D output=TYPE`, legacy falls back to per-builder files |
| erp_back dev factory cleanup | `pre_releases/manifests/dev/factory/` | DONE — Removed 4 old builder files, replaced with render.k + factory_seed.k |

### Kubeconform Validation Results

| Project | Manifests | Valid | Invalid | Errors |
|---|---|---|---|---|
| erp_back (dev) | 8 | 8 | 0 | 0 |
| erp_back (stg) | 8 | 8 | 0 | 0 |
| erp_back (release v1.0.0) | 8 | 8 | 0 | 0 |
| video_streaming (dev) | 5 | 5 | 0 | 0 |

### Phase 6 Completed Items

| Item | File(s) | Status |
|---|---|---|
| ThirdPartyHelmSpec schema | `framework/models/modules/thirdparty_helm.k` | DONE — `ThirdPartyHelmSpec` + `build_thirdparty_helm` → HelmRelease manifests |
| ThirdPartyHelm tests | `framework/tests/models/modules/thirdparty_helm_test.k` | DONE — 5 tests |
| PostgreSQL template (TDD) | `framework/templates/postgresql.k` | DONE — `CNPGClusterSpec`, `PoolerSpec`, `BackupSpec`, `build_cnpg_cluster`, `build_pooler`, `build_scheduled_backup` (CloudNativePG `postgresql.cnpg.io/v1`) |
| PostgreSQL tests | `framework/tests/templates/postgresql_test.k` | DONE — 10 tests (defaults, backup, bootstrap, image, monitoring, pg_params, wal_storage, pooler, scheduled_backup, validation) |
| MongoDB template (TDD) | `framework/templates/mongodb.k` | DONE — `MongoDBCommunitySpec`, `build_mongodb_community`, `MongoDBCommunityModule` (`mongodbcommunity.mongodb.com/v1`) |
| MongoDB tests | `framework/tests/templates/mongodb_test.k` | DONE — 6 tests (basic, resources, storage_class, user, validation x2) |
| RabbitMQ template (TDD) | `framework/templates/rabbitmq.k` | DONE — `RabbitMQClusterSpec`, `build_rabbitmq_cluster`, `RabbitMQClusterModule` (`rabbitmq.com/v1beta1`) |
| RabbitMQ tests | `framework/tests/templates/rabbitmq_test.k` | DONE — 7 tests (basic, defaults, config, image, plugins, resources, storage_class, validation x2) |
| Redis template (TDD) | `framework/templates/redis.k` | DONE — `RedisSpec`, `build_redis`, standalone/cluster modes (`redis.redis.opstreelabs.in/v1beta2`) |
| Redis tests | `framework/tests/templates/redis_test.k` | DONE — 6 tests (standalone, cluster, image, resources, storage_class, validation x2) |
| Keycloak template (TDD) | `framework/templates/keycloak.k` | DONE — `KeycloakSpec`, `build_keycloak`, `KeycloakModule` (`k8s.keycloak.org/v2alpha1`) |
| Keycloak tests | `framework/tests/templates/keycloak_test.k` | DONE — 5 tests (basic, defaults, db, http, realm_import, validation x2) |
| OpenSearch template (TDD) | `framework/templates/opensearch.k` | DONE — `OpenSearchClusterSpec`, `NodePoolSpec`, `DashboardsSpec`, `build_opensearch_cluster`, `OpenSearchClusterModule` (`opensearch.org/v1`) |
| OpenSearch tests | `framework/tests/templates/opensearch_test.k` | DONE — 8 tests (basic, dashboards, multi_pool, config, monitoring, validation x3) |
| Vault VSO template (TDD) | `framework/templates/vault.k` | DONE — `VaultConnectionSpec`, `VaultAuthSpec`, `VaultStaticSecretSpec`, 3 build lambdas (`secrets.hashicorp.com/v1beta1`) ⚠️ BUSL-1.1 |
| Vault tests | `framework/tests/templates/vault_test.k` | DONE — 7 tests (connection basic/TLS, auth kubernetes, static secret, custom dest, validation x2) |
| QuestDB template (TDD) | `framework/templates/questdb.k` | DONE — `QuestDBSpec`, `build_questdb_release` wrapping ThirdPartyHelmSpec (Helm chart, no operator) |
| QuestDB tests | `framework/tests/templates/questdb_test.k` | DONE — 4 tests (default, custom, ports, service_type) |
| MinIO template (TDD) | `framework/templates/minio.k` | DONE — `MinIOTenantSpec` + `build_minio_tenant` (Operator CRD `minio.min.io/v2`) + `MinIOHelmSpec` + `build_minio_helm` (Bitnami chart fallback) |
| MinIO tests | `framework/tests/templates/minio_test.k` | DONE — 8 tests (default, custom_pools, resources, storage_class, no_autocert, env_vars, validation, helm_fallback) |
| Observability stack (TDD) | `framework/templates/observability.k` | DONE — `PrometheusSpec`, `GrafanaSpec`, `ServiceMonitorSpec` + 3 build lambdas (Bitnami Helm charts + Prometheus CRD) |
| Observability tests | `framework/tests/templates/observability_test.k` | DONE — 8 tests (prometheus default/custom/alertmanager, grafana default/custom/ingress, service_monitor basic/interval) |
| OpenTelemetry template (TDD) | `framework/templates/opentelemetry.k` | DONE — `OtelOperatorSpec` + `build_otel_operator` (Helm chart `open-telemetry/opentelemetry-operator` v0.109.0), `OtelCollectorSpec` + `build_otel_collector` (`opentelemetry.io/v1beta1`), `InstrumentationSpec` + `build_instrumentation` (`opentelemetry.io/v1alpha1`) |
| OpenTelemetry tests | `framework/tests/templates/opentelemetry_test.k` | DONE — 13 tests (operator default/auto_cert/custom_image/validation, collector default/daemonset/custom_config/target_allocator/invalid_mode/sidecar, instrumentation default/custom_endpoint/custom_images) |

### Phase 7 Completed Items

| Item | File(s) | Status |
|---|---|---|
| Kustomize output procedure (TDD) | `framework/procedures/kcl_to_kustomize.k` | DONE — `generate_kustomization`, `generate_kustomization_from_stack`, `generate_overlay_patch` |
| Kustomize tests | `framework/tests/procedures/kustomize_test.k` | DONE — 8 tests (single, multiple, accessories, labels, from_stack, resource_names, empty, overlay_patch) |
| render.k kustomize support | `framework/factory/render.k` | DONE — Added `-D output=kustomize` block |
| CLI kustomize render | `platform_cli/koncept` | DONE — `koncept render kustomize` generates `base/kustomization.yaml` + individual manifest files |
| CLI OCI publish | `platform_cli/koncept` | DONE — `koncept publish <module> --output <version>` wraps `kcl mod push` |
| Timoni output procedure (TDD) | `framework/procedures/kcl_to_timoni.k` | DONE — `generate_timoni_metadata`, `generate_timoni_values`, `generate_timoni_resources`, `generate_timoni_module_from_stack` |
| Timoni tests | `framework/tests/procedures/timoni_test.k` | DONE — 11 tests (metadata, version, values components/accessories/namespaces, resources single/multiple/empty, module from_stack/empty/components_only) |
| render.k timoni support | `framework/factory/render.k` | DONE — Added `-D output=timoni` block |
| CLI timoni render | `platform_cli/koncept` | DONE — `koncept render timoni` generates Timoni module directory structure |
| Standalone User Workflow Guides | `docs/USER_WORKFLOW_GUIDES.md` | DONE — Developer, High-Level PE, Low-Level PE workflows |
| Standalone Work Matrix | `docs/WORK_MATRIX.md` | DONE — Tasks mapped by user profile across all phases |
| Standalone Migration Guide | `docs/MIGRATION_GUIDE.md` | DONE — video_streaming → template pattern step-by-step |
| Crossplane output procedure (TDD) | `framework/procedures/kcl_to_crossplane.k` | DONE — `generate_xrd`, `generate_composition`, `generate_xr`, `generate_prerequisites`, `generate_crossplane_from_stack` |
| Crossplane tests | `framework/tests/procedures/crossplane_test.k` | DONE — 25 tests (xr_kind, xrd_structure, composition pipeline, sequencer rules, object wrapping, full_stack, prerequisites) |
| render.k crossplane support | `framework/factory/render.k` | DONE — Added `-D output=crossplane` block |
| CLI crossplane render | `platform_cli/koncept` | DONE — `koncept render crossplane` generates xrd.yaml, composition.yaml, xr.yaml, prerequisites/ |

### Phase 8 Completed Items

| Item | File(s) | Status |
|---|---|---|
| Backstage output procedure (TDD) | `framework/procedures/kcl_to_backstage.k` | DONE — `generate_domain`, `generate_system`, `generate_component_entity`, `generate_resource_from_component`, `generate_resource_from_accessory`, `generate_resource_from_namespace`, `generate_catalog_from_stack` |
| Backstage procedure tests | `framework/tests/procedures/backstage_test.k` | DONE — 14 tests (domain, system, component, infra resource, CRD accessory, SECRET accessory, namespace, full catalog, empty stack, components only, lifecycle/owner, repo_url, techdocs annotation, no techdocs when empty) |
| Backstage fields in BaseConfigurations | `framework/models/configurations.k` | DONE — Added `backstageOwner`, `backstageSystem`, `backstageLifecycle` optional fields |
| Deployment annotations support | `framework/builders/deployment.k` | DONE — Added `annotations?: {str:str}` to DeploymentSpec, conditional injection in `build_deployment` |
| render.k backstage support | `framework/factory/render.k` | DONE — Added `-D output=backstage` block with TechDocs ref parameter |
| CLI backstage render | `platform_cli/koncept` | DONE — `koncept render backstage` generates `catalog-info.yaml` with all entities |
| Backstage Helm template (TDD) | `framework/templates/backstage.k` | DONE — `BackstageHelmSpec` + `build_backstage_release` wrapping official Backstage Helm chart |
| Backstage template tests | `framework/tests/templates/backstage_test.k` | DONE — 5 tests (default, host/ingress, postgres, resources, custom version) |
| TechDocs annotation support | `framework/procedures/kcl_to_backstage.k` | DONE — `generate_domain` and `generate_system` accept `techdocs_ref` parameter |
| mkdocs.yml for TechDocs | `mkdocs.yml` | DONE — Site navigation for Backstage TechDocs integration |
| Document justified `any` types (Phase 3 gap) | `project.k`, `tenant.k`, `site.k`, `stack.k`, `seed.k`, `configurations.k` | DONE — `# framework-generic` comments on all intentional `any` types |

### Phase 9 Completed Items

| Item | File(s) | Status |
|---|---|---|
| Plugin Integration Guide | `docs/BACKSTAGE_PLUGIN_GUIDE.md` | DONE — Kubernetes, TeraSky Ingestor, Crossplane Resources, ArgoCD, Catalog Graph plugins |
| Keycloak auth guide | `docs/BACKSTAGE_PLUGIN_GUIDE.md` §3 | DONE — Plugin installation, realm config, role mapping, permission framework |
| TechDocs configuration guide | `docs/BACKSTAGE_PLUGIN_GUIDE.md` §4 | DONE — TechDocs setup, mkdocs.yml, annotation integration |
| Observability plugins guide | `docs/BACKSTAGE_PLUGIN_GUIDE.md` §5 | DONE — Grafana, Prometheus, Kafka, GitHub Actions plugins |
| Complete app-config.yaml reference | `docs/BACKSTAGE_PLUGIN_GUIDE.md` §6 | DONE — Full config template with all plugin sections |
| Entity annotations cheat sheet | `docs/BACKSTAGE_PLUGIN_GUIDE.md` §6 | DONE — All annotations with source and purpose |

### Phase 10 Completed Items

| Item | File(s) | Status |
|---|---|---|
| Custom scaffolder actions (TypeScript) | `backstage/plugins/koncept-actions/src/actions/` | DONE — `koncept:render`, `koncept:validate`, `koncept:init`, `koncept:publish` |
| CLI executor library | `backstage/plugins/koncept-actions/src/lib/executor.ts` | DONE — Safe process spawning (no shell interpolation) |
| Plugin package setup | `backstage/plugins/koncept-actions/package.json` | DONE — TypeScript project with Backstage dependencies |
| New Web Application template | `backstage/templates/new-web-application.yaml` | DONE — Wizard for WebAppModule (name, port, replicas, resources, health checks, environment) |
| New PostgreSQL Database template | `backstage/templates/new-postgresql-database.yaml` | DONE — Wizard for PostgreSQLClusterModule (instances, version, storage, backup) |
| New Kafka Cluster template | `backstage/templates/new-kafka-cluster.yaml` | DONE — Wizard for KafkaClusterModule (replicas, storage, topics) |
| New Redis Cache template | `backstage/templates/new-redis-cache.yaml` | DONE — Wizard for RedisModule (standalone/cluster, replicas, storage) |
| New MongoDB Database template | `backstage/templates/new-mongodb-database.yaml` | DONE — Wizard for MongoDBCommunityModule (members, version, storage) |
| New RabbitMQ Cluster template | `backstage/templates/new-rabbitmq-cluster.yaml` | DONE — Wizard for RabbitMQClusterModule (replicas, storage, plugins) |
| New Release template | `backstage/templates/new-release.yaml` | DONE — Wizard for creating versioned releases with backstage catalog generation |
| Deploy to Environment template | `backstage/templates/deploy-to-environment.yaml` | DONE — Wizard for environment promotion (dev → stg → production) |
| Backstage catalog locations | `backstage/catalog-info.yaml` | DONE — Location file referencing all template YAML files |

### Strategy Document

Full testing strategy: [`docs/TESTING_STRATEGY.md`](./TESTING_STRATEGY.md)

---

## 15. Work Matrix by User Profile

### Developer

| Phase | Task | Input | Output |
|---|---|---|---|
| 4 | Use `koncept validate` before rendering | CLI command | Validation result |
| 4 | Use `koncept render helmfile` for param charts | CLI command | Helm charts + values.yaml |
| 4 | Create per-environment value overrides | `env/<env>.yaml` files | Customized deployments |
| 5 | Report configuration issues via `koncept validate` | CLI output | Bug reports |
| 6 | Configure operator-managed database resources | Site/tenant YAML configs | Custom DB settings per env |
| 7 | Use `koncept render kustomize` (future) | CLI command | Kustomize overlays |
| 8-10 | Create a new service via Backstage portal | Backstage Template wizard | Scaffolded service + PR |
| 8-10 | Deploy to new environment via portal | Backstage Template wizard | Rendered manifests |
| 8-10 | Browse service catalog and dependencies | Backstage Catalog UI | Discovery + health status |

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
| 8 | Configure Backstage annotations in BaseConfigurations | `configurations.k` | Backstage-annotated manifests |
| 9 | Install and configure Backstage plugins | Plugin configs | Working Backstage portal |
| 9 | Configure Keycloak auth for Backstage | Keycloak instance | SSO + RBAC |
| 10 | Create Backstage Templates for KCL templates | Template YAML files | Self-service wizards |

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
| 8 | Implement `kcl_to_backstage.k` procedure (TDD) | Stack schema | catalog-info.yaml generation |
| 8 | Add Backstage annotations to deployment builder | Builder schemas | TeraSky Ingestor-compatible manifests |
| 8 | Set up Backstage instance (Helm chart + PostgreSQL) | Framework templates | Running Backstage portal |
| 10 | Create custom scaffolder actions (TypeScript) | `koncept` CLI commands | Backstage actions wrapping CLI |
| 10 | Update CLI for `koncept render backstage` | Nushell script | New render target |

---

## 16. Migration Guide: video_streaming → template pattern

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

### Backstage (CNCF Incubation)

Backstage is the de-facto standard OSS developer portal (33k+ stars, 1,867 contributors, Apache-2.0). Key integration points for idp-concept:
- **TeraSky Kubernetes Ingestor**: Auto-ingests deployed K8s workloads and Crossplane Claims as Backstage catalog entities. Auto-creates Templates from XRDs.
- **TeraSky Crossplane Resources**: Graph view of Crossplane claim/XR/managed resources.
- **Custom Scaffolder Actions**: Wrap `koncept` CLI in TypeScript actions for self-service.
- **Catalog Entity Model**: 9 entity kinds (Component, API, Resource, System, Domain, Group, User, Template, Location) map directly to our framework models.
- See [docs/BACKSTAGE_ADOPTION_ANALYSIS.md](./BACKSTAGE_ADOPTION_ANALYSIS.md) for the full analysis.

---

## Appendix B: Implementation Priority

```
Phase 1 (Foundation) ✅             Phase 2 (Helmfile) ✅
├─ Security fixes (P0) ✅          ├─ HelmValues extraction ✅
├─ imagePullPolicy fix ✅           ├─ kcl_to_helmfile.k implementation ✅
└─ Code style cleanup ✅            ├─ kcl_to_helm.k expansion ✅
                                    ├─ Static Helm templates ✅
Phase 3 (Code Quality) ✅          ├─ values_builder.k implementation ✅
├─ EnvVar schema ✅                 └─ CLI update for helmfile flow ✅
├─ check validation blocks ✅
├─ Document any types               Phase 4 (Developer Experience) ✅
└─ Test infrastructure ✅           ├─ koncept validate ✅
                                    ├─ koncept init (nice-to-have) ✅
Phase 5 (Advanced) ✅               ├─ Configurable builder names ✅
├─ kcl_to_argocd.k ✅               ├─ Generic render.k + CLI support ✅
├─ NetworkPolicy builder ✅         └─ DEVELOPER_QUICKSTART.md ✅
├─ PDB builder ✅
├─ Secret management schemas ✅
└─ Multi-component Helm charts

Phase 6 (Production Infrastructure) ✅  Phase 7 (Ecosystem) ✅
├─ P0: CloudNativePG (PostgreSQL) ✅  ├─ kcl_to_kustomize.k ✅
├─ P1: MCK (MongoDB) ✅               ├─ KCL plugin integration (docs)
├─ P1: Strimzi (Kafka) — integrate    ├─ OCI artifact publishing ✅
├─ P1: RabbitMQ cluster-operator ✅   ├─ Jsonnet bundle consumption
├─ P1: OT Redis Operator ✅           └─ kcl_to_timoni.k ✅ [experimental]
├─ P1: Keycloak Operator (CNCF) ✅        ├─ CUE module generation ✅
├─ P1: Vault VSO (⚠️ BUSL-1.1) ✅        ├─ Timoni module structure ✅
├─ P2: MinIO (operator+Bitnami) ✅       └─ CLI render target ✅
├─ P2: OpenSearch k8s-operator ✅    kcl_to_crossplane.k ✅
├─ P3: Valkey (not ready — use Redis)    ├─ XRD + Composition + XR generation ✅
├─ P3: QuestDB (Helm chart only) ✅      ├─ function-sequencer ordering ✅
├─ ThirdPartyHelmSpec enhancement ✅     └─ CLI render target ✅
├─ P2: OpenSearch k8s-operator ✅
├─ P3: Valkey (not ready — use Redis)
├─ P3: QuestDB (Helm chart only) ✅
├─ ThirdPartyHelmSpec enhancement ✅
├─ ExternalSecrets operator ✅
└─ Observability stack ✅

Phase 8 (Portal: Catalog)          Phase 9 (Portal: Plugins)
├─ kcl_to_backstage procedure       ├─ K8s + Ingestor + Crossplane plugins
├─ Backstage annotations in K8s     ├─ ArgoCD + Catalog Graph plugins
├─ Backstage instance setup          ├─ Keycloak auth + RBAC
└─ catalog-info.yaml generation      ├─ TechDocs integration
                                     └─ Observability plugins (Kafka, Vault,
Phase 10 (Portal: Self-Service)         Grafana, Prometheus)
├─ Custom scaffolder actions
│   (koncept:render, :validate,
│    :init, :publish)
├─ Backstage Templates mapping
│   KCL templates → wizard forms
├─ Self-service end-to-end workflow
└─ CLI + Portal coexistence docs
```

### Proof-of-Concept → Production Transition Map

```
POC (current)                        Production Target
─────────────                        ──────────────────
Raw Deployments/StatefulSets    →    K8s Operators (CNPG, Strimzi, MCK, OT Redis, ...)
Hand-crafted all manifests      →    Operator CRDs + ThirdParty Helm charts
Hardcoded secrets in code       →    ExternalSecrets + Vault VSO / Cloud KMS
No object storage               →    MinIO Operator (Tenant CRD) + Bitnami Helm
No identity management          →    Keycloak Operator (CNCF Incubation)
No messaging beyond Kafka       →    RabbitMQ cluster-operator
No search/analytics             →    OpenSearch k8s-operator
No monitoring                   →    Prometheus + Grafana + OpenTelemetry (auto-configured)
No network policies             →    NetworkPolicy per component
No HA guarantees                →    PDB + topology spread constraints
Single output format (YAML)     →    YAML + Helm + Helmfile + Kustomize + ArgoCD + Timoni + Crossplane ✅
Manual project setup            →    `koncept init` scaffolding ✅
No validation before deploy     →    `koncept validate` + check blocks + kubeconform ✅
No tests                        →    268 unit tests + integration validation ✅
CLI-only interface              →    CLI + Backstage developer portal (self-service)
No service catalog              →    Backstage catalog (auto-ingested via TeraSky Ingestor)
No self-service for developers  →    Backstage Templates wrapping KCL templates
No dependency visualization     →    Backstage Catalog Graph + Crossplane resource graph
No centralized docs             →    TechDocs from Markdown alongside code
```
