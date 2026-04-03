# idp-concept — Project Architecture & Documentation

## Table of Contents

- [1. Project Vision & Goals](#1-project-vision--goals)
- [2. How It Works — The Big Picture](#2-how-it-works--the-big-picture)
- [3. Architecture Overview](#3-architecture-overview)
- [4. Technology Stack](#4-technology-stack)
- [5. Framework Layer](#5-framework-layer)
- [6. Project Layer](#6-project-layer)
- [7. Platform CLI](#7-platform-cli)
- [8. Crossplane Layer](#8-crossplane-layer)
- [9. Output Formats](#9-output-formats)
- [10. Data Flow End-to-End](#10-data-flow-end-to-end)
- [11. Adding a New Project](#11-adding-a-new-project)
- [12. Adding a New Module](#12-adding-a-new-module)
- [13. Adding a New Output Format](#13-adding-a-new-output-format)

---

## 1. Project Vision & Goals

**idp-concept** is an Internal Developer Platform (IDP) designed to solve the "technology lock-in" problem in Kubernetes deployment workflows.

### The Problem

When teams adopt a specific deployment tool (e.g., Helmfile with Go templates), they become locked into that technology. If a better tool appears, or if the team wants to adopt GitOps, they must rewrite everything. Developers also face unnecessary complexity managing Helm charts, versioning, and infrastructure manifests.

### The Solution

Define **all configuration in KCL** (Kusion Configuration Language) as a **single source of truth**. From this single definition, automatically generate manifests in **9 output formats**:

| Output Format | Use Case |
|---|---|
| **Plain YAML** | GitOps with ArgoCD, direct `kubectl apply` |
| **ArgoCD** | ArgoCD Application CRDs for GitOps pipelines |
| **Helm Charts** | Traditional Helm-based deployments |
| **Helmfile** | Multi-chart orchestration with Helmfile |
| **Kusion Spec** | Kusion-based infrastructure-as-code |
| **Kustomize** | Kustomize overlay-based deployments |
| **Timoni** | CUE-powered Helm alternative |
| **Crossplane** | Kubernetes-native infrastructure provisioning |
| **Backstage** | Backstage catalog-info.yaml for developer portal |

### Key Benefits

- **No technology lock-in**: Switch output formats without rewriting configurations
- **Separation of concerns**: Developers define *what* to deploy; the platform handles *how*
- **Multi-tenant**: Same application, different configurations per customer
- **Multi-environment**: Deploy the same version to different sites with site-specific overrides
- **Versioned releases**: Immutable release snapshots tied to specific versions
- **DRY**: 17 pre-built templates reduce 200+ lines of YAML to ~30 lines of KCL

---

## 2. How It Works — The Big Picture

Imagine you have a web API backed by a PostgreSQL database. To deploy it to Kubernetes, you need
Deployments, Services, ConfigMaps, PersistentVolumes, Namespaces, and more.  In this project:

1. **You describe your app once** using a simple KCL schema (30 lines).
2. **The framework generates everything** — all K8s manifests, in any format.
3. **You customise per-environment** — dev gets 1 replica, prod gets 3 — by overlaying configurations.

```
You write this (30 lines):                    The platform generates this:
┌──────────────────────────┐                  ┌──────────────────────────────────┐
│ schema ErpApi(WebApp):   │                  │ Deployment (with probes, env,    │
│   port = 8080            │   ──build──►     │   resources, volumes)            │
│   replicas = 1           │                  │ Service (ClusterIP:8080)         │
│   env = [...]            │                  │ ConfigMap (optional)             │
│   resources = {...}      │                  │ ServiceAccount (optional)        │
│   livenessProbe = {...}  │                  │ ...in YAML, Helm, ArgoCD, etc.  │
└──────────────────────────┘                  └──────────────────────────────────┘
```

### Configuration Layering

Configurations merge in 4 layers. Later layers override earlier ones:

```
1. kernel   — project-wide defaults (project name, git repo URL)
       ↓ merged with
2. profile  — deployment mode (dev resources, prod replicas)
       ↓ merged with
3. tenant   — customer-specific (branding, feature flags)
       ↓ merged with
4. site     — environment-specific (hostnames, storage class, cluster)
       =
   Final merged config → passed to the stack → generates manifests
```

This uses KCL's union operator (`|`): `kernel | profile | tenant | site`.
Later values override earlier ones for the same key.

---

## 3. Architecture Overview

The platform has three main layers:

```
┌──────────────────────────────────────────────────────────────────────┐
│                        FRAMEWORK LAYER                               │
│  Reusable schemas, builders, templates, and output procedures        │
│                                                                      │
│  models/           builders/          templates/        procedures/   │
│  ┌──────────┐     ┌──────────────┐   ┌──────────────┐ ┌───────────┐ │
│  │ Project   │     │ Deployment   │   │ WebApp       │ │ → YAML    │ │
│  │ Tenant    │     │ Service      │   │ Database     │ │ → ArgoCD  │ │
│  │ Site      │     │ ConfigMap    │   │ Kafka        │ │ → Helm    │ │
│  │ Profile   │     │ Storage      │   │ PostgreSQL   │ │ → Helmfile│ │
│  │ Stack     │     │ SA           │   │ MongoDB      │ │ → Kusion  │ │
│  │ Component │     │ NetworkPol.  │   │ RabbitMQ     │ │ → Kustom. │ │
│  │ Accessory │     │ PDB          │   │ Redis        │ │ → Timoni  │ │
│  │ Namespace │     │ Leader       │   │ Keycloak     │ │ → Crosspl.│ │
│  │ ThirdParty│     └──────────────┘   │ OpenSearch   │ │ → Backstg.│ │
│  └──────────┘                         │ Vault,MinIO  │ └───────────┘ │
│                                       │ QuestDB,...  │               │
│                                       └──────────────┘               │
└────────────────────────────┬─────────────────────────────────────────┘
                             │ imports
┌────────────────────────────▼─────────────────────────────────────────┐
│                        PROJECT LAYER                                 │
│  Your application definitions, configurations, and release factories │
│                                                                      │
│  kernel/        core_sources/    modules/        stacks/             │
│  ┌──────────┐  ┌────────────┐  ┌────────────┐  ┌────────────────┐   │
│  │ Project   │  │ Config     │  │ ErpApi     │  │ Dev stack      │   │
│  │ defaults  │  │ schema +   │  │ (WebApp)   │  │ (what to       │   │
│  │           │  │ merge fn   │  │ Postgres   │  │  deploy)       │   │
│  └─────┬────┘  └─────┬──────┘  │ (Database) │  └──────┬─────────┘   │
│        └──────┬───────┘         └──────┬─────┘         │             │
│               │                        │               │             │
│  tenants/     │  sites/        ┌───────▼───────────────▼──────┐      │
│  ┌────────┐   │  ┌────────┐   │  pre_releases/ & releases/    │      │
│  │customer│───┘  │cluster │   │  factory/ → render.k → OUTPUT │      │
│  │configs │      │configs │   └───────────────────────────────┘      │
│  └────────┘      └────────┘                                          │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────────────┐
│                       PLATFORM CLI (Nushell)                         │
│  koncept render yaml|argocd|helmfile|helm|kusion|kustomize|...       │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 4. Technology Stack

| Technology | Role | Documentation |
|---|---|---|
| **KCL** | Configuration language — single source of truth | https://www.kcl-lang.io/docs/ |
| **Nushell** | CLI scripting language (`koncept` tool) | https://www.nushell.sh/book/ |
| **Kubernetes** 1.31.2 | Target deployment platform (K8s schemas) | https://kubernetes.io/docs/ |
| **Crossplane** | Kubernetes-native infrastructure provisioning | https://docs.crossplane.io/ |
| **ArgoCD** | GitOps continuous delivery | https://argo-cd.readthedocs.io/ |
| **Helm** / **Helmfile** | Package manager / multi-chart orchestration | https://helm.sh/docs/ |
| **Kusion** | Intent-driven infrastructure-as-code | https://www.kusionstack.io/docs/ |
| **Backstage** | Developer portal (catalog + scaffolder) | https://backstage.io/docs/ |
| **go-task** | Task runner (Taskfile YAML) | https://taskfile.dev/ |

---

## 5. Framework Layer

The framework (`framework/`) is the shared library that every project imports.  It is organised into five areas:

### 5.1 Models (`framework/models/`) — Domain Concepts

Models define the vocabulary of the platform.  Every model follows a **Schema + Instance** pattern (see [FRAMEWORK_SCHEMAS.md](./FRAMEWORK_SCHEMAS.md) for full reference):

| Schema | Purpose | Think of it as… |
|---|---|---|
| **Project** | A deployable product | "Video Streaming", "ERP Back" |
| **Tenant** | A customer/organisation | "Germany", "Spain", "vendor" |
| **Site** | A deployment target | "dev_cluster", "berlin", "staging" |
| **Profile** | A deployment mode | "development", "v1_0_0" |
| **Stack** | All modules for one deployment | "dev stack = API + Postgres + Kafka" |
| **Release** | Versioned snapshot | Stack + config for a specific site/version |

**Module models** (`models/modules/`) define the building blocks:

| Schema | Kind | What it represents |
|---|---|---|
| **Component** | `APPLICATION` / `INFRASTRUCTURE` | Deployable workloads (Deployments, Services) |
| **Accessory** | `CRD` / `SECRET` | Supporting resources (Kafka, MongoDB, PVs) |
| **K8sNamespace** | `Namespace` | Kubernetes namespaces |
| **ThirdParty** | varies | Vendor-managed (Helm charts, Kustomize bases) |

All Leader types (ComponentLeader, AccessoryLeader, K8sNamespaceLeader) share a common **Leader** base schema that identifies the primary K8s resource for dependency ordering.

### 5.2 Builders (`framework/builders/`) — K8s Manifest Generators

Builders are **lambda functions** that take a spec schema and return a typed K8s manifest. They eliminate YAML boilerplate:

| Builder | Input Schema | Output | What it generates |
|---|---|---|---|
| `build_deployment` | `DeploymentSpec` | `apps/v1 Deployment` | Container, probes, resources, volumes, env |
| `build_service` | `ServiceSpec` | `v1 Service` | ClusterIP/NodePort/LoadBalancer |
| `build_configmap` | `ConfigMapSpec` | `v1 ConfigMap` | Configuration data |
| `build_pv_and_pvc` | `PersistentVolumeSpec` | PV + PVC | Persistent storage |
| `build_service_account` | `ServiceAccountSpec` | `v1 ServiceAccount` | With imagePullSecrets |
| `build_network_policy` | `NetworkPolicySpec` | `NetworkPolicy` | Ingress/egress rules |
| `build_pdb` | `PDBSpec` | `PodDisruptionBudget` | Availability guarantees |
| `build_leader` | name, namespace, kind | `Leader` | Dependency identifier |

### 5.3 Templates (`framework/templates/`) — Pre-Built Patterns

Templates **compose builders** into complete modules. Instead of writing 200 lines of K8s YAML, you write ~30 lines:

| Template | Extends | What it generates automatically |
|---|---|---|
| `WebAppModule` | Component | Deployment + Service + ConfigMap + ServiceAccount |
| `SingleDatabaseModule` | Accessory | Deployment + Service + PV + PVC |
| `KafkaClusterModule` | Accessory | Strimzi Kafka CRD + KafkaTopic CRDs |
| `PostgreSQLClusterModule` | Accessory | CloudNativePG Cluster + Backup + Pooler |
| `MongoDBCommunityModule` | Accessory | MongoDB ReplicaSet CRD |
| `RabbitMQClusterModule` | Accessory | RabbitmqCluster CRD |
| `RedisModule` | Accessory | OT Redis/RedisCluster CRD |
| `KeycloakModule` | Accessory | Keycloak CRD + RealmImport |
| `OpenSearchClusterModule` | Accessory | OpenSearchCluster CRD + Dashboards |
| `VaultStaticSecretModule` | Accessory | Vault VSO SecretSync CRDs |
| `QuestDBModule` | Accessory | Helm chart wrapper |
| `MinIOTenantSpec/HelmSpec` | Accessory | MinIO Operator CRD / Bitnami Helm |
| `BackstageHelmModule` | ThirdPartyHelmSpec | Backstage Helm chart |
| `ObservabilityStackModule` | Accessory | Prometheus + Grafana Helm charts |

### 5.4 Procedures (`framework/procedures/`) — Output Format Converters

Procedures transform a stack's manifests into a specific output format:

| Procedure | Output |
|---|---|
| `kcl_to_yaml` | Multi-document K8s YAML (for `kubectl apply` / ArgoCD) |
| `kcl_to_argocd` | ArgoCD Application + AppProject CRDs |
| `kcl_to_helm` | Chart.yaml + values.yaml per component |
| `kcl_to_helmfile` | helmfile.yaml with per-component releases |
| `kcl_to_kusion` | Kusion spec with dependency graph |
| `kcl_to_kustomize` | kustomization.yaml + resource manifests |
| `kcl_to_timoni` | Timoni CUE module structure |
| `kcl_to_crossplane` | XRD + Composition + Composite Resource |
| `kcl_to_backstage` | catalog-info.yaml with Component entities |

### 5.5 Factory (`framework/factory/`) — Generic Renderer

The factory provides two files that every release directory copies:

- **`render.k`** — routes to the correct procedure based on `-D output=<format>`
- **`seed.k`** — `FactorySeed` schema that merges 4 config layers and creates a `Release`

### 5.6 Assembly (`framework/assembly/`) — Helpers

Convenience functions for common operations:
- `create_namespace(name, config)` — creates a `K8sNamespaceInstance` in one line
- `create_namespace_from_config(field, config)` — reads namespace name from a config field

---

## 6. Project Layer

Projects live in `projects/` and import from the framework.  There are two example projects:

- **`erp_back/`** — Recommended reference.  Uses framework templates (`WebAppModule`, `SingleDatabaseModule`).
- **`video_streaming/`** — Older example.  Builds modules "raw" (without templates).

### 6.1 Project Structure (erp_back)

```
projects/erp_back/
├── kcl.mod                           # Package declaration + framework dependency
├── kernel/                           # ① Project identity + base config
│   ├── project_def.k                 #    Project { name, description, configurations }
│   └── configurations.k             #    Kernel-level defaults (project name, DB, git URL)
├── core_sources/                     # ② Config schema + merge function
│   ├── erp_back_configurations.k    #    schema ErpBackConfigurations(BaseConfigurations)
│   └── merge_configurations.k       #    merge = kernel | profile | tenant | site
├── modules/                          # ③ What to deploy
│   ├── appops/erp_api/              #    ErpApiModule(WebAppModule): port, probes, env
│   └── infrastructure/postgres/     #    PostgresModule(SingleDatabaseModule): port, storage
├── stacks/                           # ④ Which modules go together
│   └── development/                 #    ErpBackDevelopmentStack: [api] + [postgres] + [ns]
├── tenants/vendor/                   # ⑤ Customer overrides (branding, features)
├── sites/development/dev_cluster/    # ⑥ Environment overrides (hostnames, replicas)
└── pre_releases/                     # ⑦ Factory that merges everything → output
    ├── configurations_dev.k         #    Merges kernel | profile | tenant | site
    └── manifests/dev/factory/       #    factory_seed.k + render.k
```

### 6.2 How the Pieces Connect

```
① kernel/configurations.k              →  ErpBackConfigurations { projectName = "erp_back", ... }
② core_sources/merge_configurations.k  →  merge(kernel, profile, tenant, site) → final config
③ modules/erp_api/                     →  ErpApiModule(WebAppModule) { port = 8080, env = [...] }
④ stacks/development/stack_def.k       →  ErpBackDevelopmentStack { components = [erp_api], accessories = [postgres] }
⑤ tenants/vendor/                      →  Tenant { configurations = { brandIcon = "vendor.png" } }
⑥ sites/dev_cluster/                   →  Site { configurations = { postgresHost = "...", siteName = "dev" } }
⑦ factory/ → render.k -D output=yaml  →  kcl_to_yaml → K8s YAML manifests
```

---

## 7. Platform CLI

### 7.1 koncept (Primary CLI)

Location: `platform_cli/koncept` (Nushell script)

```bash
# Navigate to a factory directory, then:
koncept render <format>

# Formats: yaml, argocd, helmfile, helm, kusion, kustomize, timoni, crossplane, backstage
```

The CLI calls `kcl run render.k -D output=<format>` inside the factory directory.

### 7.2 koncepttask (Task Runner Variant)

Location: `platform_cli/koncepttask` (wraps go-task)

Delegates to Taskfile YAML templates in `platform_cli/taskfiles/` for more complex workflows
(building charts, publishing, validation).

---

## 8. Crossplane Layer

The `crossplane_v2/` directory contains Kubernetes-native infrastructure definitions for
provisioning managed resources via Crossplane.

| Kind | API Group | Provisions |
|---|---|---|
| `XCertManager` | `koncept.bluesolution.es/v1alpha1` | cert-manager via Helm |
| `XKafkaStrimzi` | `koncept.bluesolution.es/v1alpha1` | Strimzi Kafka operator |
| `XKeycloak` | `koncept.bluesolution.es/v1alpha1` | Keycloak identity server |
| `PostgresCompositeWorkload` | `gitops.bluesolution.es/v1alpha1` | PostgreSQL deployment |

All compositions use `mode: Pipeline` with function steps (patch-and-transform, auto-ready,
go-templating, KCL, sequencer). Providers: `provider-kubernetes` and `provider-helm`
with `InjectedIdentity` credentials.

---

## 9. Output Formats

All formats are generated from the **same KCL source**. Run `koncept render <format>`:

| Format | Command | What it generates |
|---|---|---|
| **yaml** | `koncept render yaml` | Multi-document K8s YAML (`kubectl apply -f`) |
| **argocd** | `koncept render argocd` | ArgoCD Application + AppProject CRDs |
| **helm** | `koncept render helm` | Chart.yaml + values.yaml per component |
| **helmfile** | `koncept render helmfile` | helmfile.yaml + per-component Helm charts |
| **kusion** | `koncept render kusion` | Kusion spec with dependency graph |
| **kustomize** | `koncept render kustomize` | kustomization.yaml + resource files |
| **timoni** | `koncept render timoni` | Timoni CUE module structure |
| **crossplane** | `koncept render crossplane` | XRD + Composition + Composite Resource |
| **backstage** | `koncept render backstage` | catalog-info.yaml with entities |

---

## 10. Data Flow End-to-End

Example: Generating plain YAML for erp_back development environment:

```
kernel/configurations.k
  → ErpBackConfigurations { projectName = "erp_back", gitRepoUrl = "...", ... }

stacks/development/profile_def.k
  → Profile { configurations = { springProfile = "default", ... } }

tenants/vendor/tenant_def.k
  → Tenant { configurations = { brandIcon = "vendor.png" } }

sites/dev_cluster/site_def.k
  → Site { configurations = { postgresHost = "erp-postgres.erp-postgres.svc...", ... } }

pre_releases/configurations_dev.k
  → merged = kernel | profile | tenant | site = final config

stacks/development/stack_def.k
  → ErpBackDevelopmentStack {
      k8snamespaces = [erp-apps-ns, erp-postgres-ns]
      components = [erp-api (Deployment + Service)]
      accessories = [erp-postgres (Deployment + Service + PV + PVC)]
    }

factory/render.k -D output=yaml
  → kcl_to_yaml.yaml_stream_stack(stack)
  → Multi-document YAML: 2 Namespaces + 2 Deployments + 2 Services + PV + PVC
```

---

## 11. Adding a New Project

See the [Developer Guide](./DEVELOPER_GUIDE.md) for detailed instructions. Summary:

1. Create `projects/<name>/` with `kcl.mod` (depends on `framework`)
2. Create `kernel/` — project definition + base configurations
3. Create `core_sources/` — config schema extending `BaseConfigurations` + merge function
4. Create `modules/` — use templates (`WebAppModule`, `SingleDatabaseModule`, etc.)
5. Create `stacks/` — assemble modules into a stack
6. Create `tenants/` and `sites/` — customer and environment overrides
7. Create `pre_releases/` — factory directory with `factory_seed.k` + `render.k`

---

## 12. Adding a New Module

### Using a template (recommended)

```kcl
import framework.templates.webapp as webapp

schema MyApi(webapp.WebAppModule):
    port = 8080
    replicas = 1
    resources = deploy.ResourceSpec { cpuRequest = "500m", memoryRequest = "512Mi" }
    env = [{ name = "APP_ENV", value = configurations.springProfile }]
```

This auto-generates: Deployment + Service + optional ConfigMap + optional ServiceAccount.

### Using raw manifests (full control)

```kcl
import framework.models.modules.component as component
import framework.builders.leader as leader

schema MyModule(component.Component):
    kind = "APPLICATION"
    leaders = [leader.build_component_leader(name, namespace)]
    manifests = [
        # build_deployment(...), build_service(...), etc.
    ]
```

Then add the module to your stack:
```kcl
_my_api = MyApi { name = "api", namespace = _ns.name, asset = { image = "...", version = "1.0" }, configurations = instanceConfigurations, dependsOn = [_ns] }.instance
components = [_my_api]
```

---

## 13. Adding a New Output Format

1. Create `framework/procedures/kcl_to_<format>.k` — transformation lambda
2. Optionally create `framework/custom/<format>/` — format-specific schemas
3. Add a new `if _output == "<format>":` block to `framework/factory/render.k`
4. Copy updated `render.k` to all existing factory directories
5. Add the format to `platform_cli/koncept` CLI
