# idp-concept — Project Architecture & Documentation

## Table of Contents

- [1. Project Vision & Goals](#1-project-vision--goals)
- [2. Architecture Overview](#2-architecture-overview)
- [3. Technology Stack](#3-technology-stack)
- [4. Framework Layer](#4-framework-layer)
- [5. Project Layer (video_streaming)](#5-project-layer-video_streaming)
- [6. Platform CLI](#6-platform-cli)
- [7. Crossplane Layer](#7-crossplane-layer)
- [8. Output Formats](#8-output-formats)
- [9. Data Flow End-to-End](#9-data-flow-end-to-end)
- [10. Adding a New Project](#10-adding-a-new-project)
- [11. Adding a New Module](#11-adding-a-new-module)
- [12. Adding a New Output Format](#12-adding-a-new-output-format)

---

## 1. Project Vision & Goals

**idp-concept** is an Internal Developer Platform (IDP) designed to solve the "technology lock-in" problem in Kubernetes deployment workflows.

### The Problem
When teams adopt a specific deployment tool (e.g., Helmfile with Go templates), they become locked into that technology. If a better tool appears, or if the team wants to adopt GitOps, they must rewrite everything. Developers also face unnecessary complexity managing Helm charts, versioning, and infrastructure manifests.

### The Solution
Define **all configuration in KCL** (Kusion Configuration Language) as a **single source of truth**. From this single definition, automatically generate manifests in any output format:

| Output Format | Use Case |
|---|---|
| **Plain YAML** | GitOps with ArgoCD, direct `kubectl apply` |
| **Helm Charts** | Traditional Helm-based deployments |
| **Helmfile** | Multi-chart orchestration with Helmfile |
| **Kusion Spec** | Kusion-based infrastructure-as-code |
| **Crossplane** | Kubernetes-native infrastructure provisioning |

### Key Benefits
- **No technology lock-in**: Switch output formats without rewriting configurations
- **Separation of concerns**: Developers define what to deploy; the platform handles how
- **Multi-tenant support**: Same application, different configurations per customer
- **Multi-environment**: Deploy the same version to different sites with site-specific overrides
- **Versioned releases**: Immutable release snapshots tied to specific versions

---

## 2. Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                       FRAMEWORK LAYER                        │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │   models/    │  │ procedures/  │  │     custom/         │ │
│  │ Project      │  │ kcl_to_yaml  │  │ ArgoCD schemas      │ │
│  │ Tenant       │  │ kcl_to_helm  │  │ Helm schemas        │ │
│  │ Site         │  │ kcl_to_kusion│  │ Helmfile schemas    │ │
│  │ Profile      │  │ kcl_to_argocd│  │ Spring schemas      │ │
│  │ Stack        │  │ helper       │  │                     │ │
│  │ Release      │  │              │  │                     │ │
│  │ modules/     │  │              │  │                     │ │
│  │  Component   │  │              │  │                     │ │
│  │  Accessory   │  │              │  │                     │ │
│  │  K8sNamespace│  │              │  │                     │ │
│  │  ThirdParty  │  │              │  │                     │ │
│  └─────────────┘  └──────────────┘  └─────────────────────┘ │
└──────────────────────────┬───────────────────────────────────┘
                           │ imports
┌──────────────────────────▼───────────────────────────────────┐
│                    PROJECT LAYER (video_streaming)            │
│  ┌──────────┐  ┌──────────────┐  ┌────────────┐             │
│  │ kernel/  │  │ core_sources/│  │  modules/   │             │
│  │ project  │  │ config schema│  │ appops/     │             │
│  │ configs  │  │ merge func   │  │ infra/      │             │
│  └────┬─────┘  └──────┬───────┘  └──────┬─────┘             │
│       │               │                 │                    │
│  ┌────▼───────────────▼─────────────────▼────┐               │
│  │              stacks/                       │               │
│  │  development/ (dev, stg profiles)          │               │
│  │  versioned/   (v1_0_0, v2_0_0)            │               │
│  └──────────────────┬────────────────────────┘               │
│                     │                                        │
│  ┌────────┐  ┌──────▼──┐  ┌──────────────────────────┐      │
│  │tenants/│  │ sites/  │  │ pre_releases/ & releases/ │      │
│  │germany │  │ berlin  │  │ factory/ → builders → OUT │      │
│  │spain   │  │ madrid  │  │     ↓                     │      │
│  │italy   │  │ rome    │  │  OUTPUT YAML/HELM/KUSION  │      │
│  └────────┘  └─────────┘  └──────────────────────────┘      │
└──────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│                     PLATFORM CLI (Nushell)                    │
│  koncept render argocd|helmfile|kusion                        │
│  koncepttask (delegates to go-task Taskfiles)                 │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Technology Stack

| Technology | Version | Role | Documentation |
|---|---|---|---|
| **KCL** | v0.10.0 | Configuration language (single source of truth) | https://www.kcl-lang.io/docs/ |
| **Nushell** | latest | CLI scripting language | https://www.nushell.sh/book/ |
| **Kubernetes** | 1.31.2 (schemas) | Target deployment platform | https://kubernetes.io/docs/ |
| **Crossplane** | v1 | Kubernetes-native infrastructure provisioning | https://docs.crossplane.io/ |
| **ArgoCD** | v2.x | GitOps continuous delivery | https://argo-cd.readthedocs.io/ |
| **Helm** | v3+ | Package manager for Kubernetes | https://helm.sh/docs/ |
| **Helmfile** | latest | Declarative Helm chart management | https://helmfile.readthedocs.io/ |
| **Kusion** | v0.2.0 | Infrastructure-as-code platform | https://www.kusionstack.io/docs/ |
| **Strimzi** | 0.45.0 | Apache Kafka on Kubernetes operator | https://strimzi.io/docs/ |
| **Keycloak** | 26.4.0 | Identity and access management | https://www.keycloak.org/documentation |
| **cert-manager** | 1.17.2 | Certificate management for Kubernetes | https://cert-manager.io/docs/ |
| **go-task** | v3 | Task runner (Taskfile YAML) | https://taskfile.dev/ |
| **kind** | latest | Local Kubernetes clusters | https://kind.sigs.k8s.io/ |
| **MongoDB** | latest | Document database (infrastructure accessory) | https://www.mongodb.com/docs/ |

---

## 4. Framework Layer

The framework (`framework/`) provides reusable schemas and procedures that any project can import.

### 4.1 Models (`framework/models/`)

#### Core Domain Models

| Schema | File | Purpose |
|---|---|---|
| `Project` / `ProjectInstance` | `project.k` | Defines a deployable project (name, description, configurations) |
| `Tenant` / `TenantInstance` | `tenant.k` | Represents a customer/organization |
| `Site` / `SiteInstance` | `site.k` | Represents a target deployment environment (linked to a Tenant) |
| `Profile` / `ProfileInstance` | `profile.k` | Defines a deployment mode (dev, staging, production version) |
| `Stack` / `StackInstance` | `stack.k` | Aggregates components, accessories, namespaces, and third-parties for a deployment |
| `Release` | `release.k` | Combines project + tenant + site + profile + stack into a versioned deployment |
| `RenderStack` / `RenderStackInstance` | `manifests/renderstack.k` | Stack variant for GitOps (plain YAML) output |

#### Module Models (`framework/models/modules/`)

| Schema | File | Kind Values | Purpose |
|---|---|---|---|
| `Component` / `ComponentInstance` | `component.k` | `APPLICATION`, `INFRASTRUCTURE` | Main deployable units (Deployments, Services, ConfigMaps) |
| `Accessory` / `AccessoryInstance` | `accessory.k` | `CRD`, `SECRET` | Supporting resources (Kafka clusters, PVs, databases) |
| `K8sNamespace` / `K8sNamespaceInstance` | `k8snamespace.k` | `Namespace` | Kubernetes namespace resources |
| `ThirdParty` / `ThirdPartyInstance` | `thirdparty.k` | N/A | External vendor-managed resources with package managers |

#### The Schema + Instance Pattern

Every model follows a dual pattern:
```kcl
schema ProjectInstance:        # Flat data container (exported)
    name: str
    description: str
    configurations: any

schema Project:                 # Validated constructor
    instance: ProjectInstance = ProjectInstance {
        name = name
        description = description
        configurations = configurations
    }
    name: str
    description: str
    configurations: any
```

The `instance` property creates a flattened `ProjectInstance` from the `Project` fields. This allows passing validated, flat data downstream while keeping the schema validation at the creation point.

### 4.2 Procedures (`framework/procedures/`)

| Procedure | File | Input | Output |
|---|---|---|---|
| `yaml_stream_stack` | `kcl_to_yaml.k` | `RenderStack` | Multi-document YAML stream |
| `generate_helm_components_templates_from_stack` | `kcl_to_helm.k` | `Stack` | Helm template YAML |
| `kusion_spec_stream_stack` | `kcl_to_kusion.k` | `Stack` | `[KusionResource]` array |
| `extract_models_by_name_from_list` | `helper.k` | Model list + name | Filtered models |

### 4.3 Custom Schemas (`framework/custom/`)

| Directory | Purpose |
|---|---|
| `helm/helm.k` | Chart, Maintainer, Dependency, HelmChartValues, Image, Service, Ingress, Resources schemas |
| `helmfile/helmfile.k` | Helmfile, Repository, Release, Environment, HelmfilePath schemas |
| `argocd/models/` | Auto-generated KCL models from ArgoCD CRDs (Application, ApplicationSet, AppProject) |
| `argocd/specifications/` | YAML examples of ArgoCD resources |
| `spring_application_properties.k` | Spring Boot application.properties schema for Java microservices |

---

## 5. Project Layer (video_streaming)

The `projects/video_streaming/` directory is the reference implementation.

### 5.1 kernel/ — Project Definition

```
kernel/
├── configurations.k    # Base project configurations
├── project_def.k       # Project schema instance
├── kcl.mod             # Package declaration
└── main.k
```

`project_def.k` creates a `Project` instance with base configurations:
```kcl
video_streaming_project = project.Project {
    name = "Video Streaming"
    description = "video streaming using apache kafka"
    configurations = configurations._video_streaming_kernel_configurations
}
```

### 5.2 core_sources/ — Configuration Schema & Merge

```
core_sources/
├── video_streaming_configurations.k   # VideoStreamingConfigurations schema
├── merge_configurations.k             # Lambda function to merge config layers
├── kcl.mod
└── main.k
```

`VideoStreamingConfigurations` defines all configurable fields:
```kcl
schema VideoStreamingConfigurations:
    projectName?: str = "video_streaming"
    brandIcon?: str
    siteName?: str
    appsNamespace?: str
    postgresNamespace?: str
    certmanagerNamespace?: str
    apacheKafkaNamespace?: str
    mongodbNamespace?: str
    rootPaths?: {str:str}
```

`merge_configurations` uses KCL's union operator to merge layers:
```kcl
merge_configurations = lambda kernel, profile, tenant, site -> VideoStreamingConfigurations {
    _configs = kernel | profile | tenant | site
}
```

### 5.3 modules/ — Concrete Kubernetes Manifests

```
modules/
├── appops/
│   ├── kafka_video_consumer_mongodb_python/   # Application component
│   ├── kafka_video_server_python/             # Application component (empty)
│   └── video_collector_mongodb_python/        # Application component
└── infrastructure/
    ├── apache_kafka/
    │   ├── instances/kafka_single_instance_module_def.k
    │   └── strimzi_operator/strimzi-crds-0.45.0.yaml
    ├── cert_manager/cert_manager_v1.17.2.yaml
    └── mongodb/
        ├── mongodb_persistence_module_def.k
        └── mongodb_single_instance_module_def.k
```

Modules use **schema inheritance** from framework base types:
```kcl
schema VideoCollectorMongodbPythonModule(component.Component):
    kind = "APPLICATION"
    leaders = [...]
    manifests = [Deployment{...}, ConfigMap{...}, Service{...}, ServiceAccount{...}]
```

### 5.4 stacks/ — What to Deploy

```
stacks/
├── stack_configurations.k              # Base stack configurations
├── development/
│   ├── profile_configurations.k        # Dev profile overrides
│   ├── profile_def.k                   # Profile instance
│   └── stack_def.k                     # Stack schema (VideoStreamingDevelopmentStack)
└── versioned/
    ├── v1_0_0/base/                    # Production version 1.0.0
    └── v2_0_0/base/                    # Kusion-native version 2.0.0
```

A stack aggregates namespaces, components, and accessories:
```kcl
schema VideoStreamingDevelopmentStack(stack.Stack):
    k8snamespaces = [_apps, _postgres, _certmanager, _kafka, _mongodb]
    components = [_video_collector_mongodb_python]
    accessories = [_apache_kafka, _mongodb_instance, _mongodb_persistence]
```

### 5.5 tenants/ — Customer Overrides

```
tenants/
├── germany/   (tenant_def.k, germany_configurations.k)
├── italy/     (tenant_def.k)
├── spain/     (tenant_def.k)
└── vendor/    (tenant_def.k, tenant_configurations.k)
```

### 5.6 sites/ — Environment Overrides

```
sites/
├── sites_configurations.k
├── development/
│   ├── dev_cluster/    (site_def.k, configurations.k)
│   └── stg_cluster/    (stg_cluster_config.k)
└── tenants/
    ├── pre_production/berlin/
    └── production/berlin/  (site_def.k, configurations.k, config.yaml)
```

### 5.7 pre_releases/ & releases/ — Output Generation

```
pre_releases/
├── configurations_dev.k    # Merges all config layers for dev
├── manifests/site_one/generators/    # ArgoCD output
│   └── kafka_.../dev/factory/
│       ├── factory_seed.k
│       ├── kubernetes_manifests_builder.k
│       └── argocd_builder.k
└── kusion/dev/default/     # Kusion output

releases/
├── helmfile/berlin/v1_0_0_berlin/factory/   # Helmfile output
│   ├── factory_seed.k
│   ├── chart_builder.k
│   ├── templates_builder.k
│   ├── helmfile_builder.k
│   └── main.k
└── kusion/berlin/v1_0_0_berlin/default/factory/  # Kusion output
    └── main.k
```

---

## 6. Platform CLI

### 6.1 koncept (Primary CLI)

Location: `platform_cli/koncept` (Nushell script)

```bash
koncept render <format> [--factory <dir>] [--output <dir>]
```

| Format | Action |
|---|---|
| `argocd` | Runs `kcl run factory/kubernetes_manifests_builder.k` → plain YAML |
| `helmfile` | Generates Chart.yaml, values.yaml, templates/manifests.yaml, helmfile.yaml |
| `kusion` | Runs `kcl run factory/main.k` → kusion_spec.yaml |

### 6.2 koncepttask (Task Runner Variant)

Location: `platform_cli/koncepttask` (Nushell script wrapping go-task)

Delegates to Taskfile YAML templates in `platform_cli/taskfiles/`:
- `taskfiles/argocd/taskfile.yaml` — generates manifests YAML
- `taskfiles/helmfile/taskfile.yaml` — generates charts + helmfile.yaml
- `taskfiles/kusion/taskfile.yaml` — (empty, placeholder)

---

## 7. Crossplane Layer

The `crossplane_v2/` directory contains Kubernetes-native infrastructure definitions.

### 7.1 Custom Resource Definitions (XRDs)

| Kind | API Group | File |
|---|---|---|
| `XCertManager` | `koncept.bluesolution.es/v1alpha1` | `cert_manager/xrd_cert_manager.yaml` |
| `XKafkaStrimzi` | `koncept.bluesolution.es/v1alpha1` | `kafka_strimzi/crossplane_xrd.yaml` |
| `XKeycloak` | `koncept.bluesolution.es/v1alpha1` | `keycloak/crossplane/xrd_keycloak.yaml` |
| `PostgresCompositeWorkload` | `gitops.bluesolution.es/v1alpha1` | `postgres/xrd_postgres.yaml` |

### 7.2 Compositions (Pipeline Mode)

All compositions use `mode: Pipeline` with function steps:

1. **cert-manager**: Namespace creation → Helm release install (jetstack chart v1.17.2) → auto-ready
2. **Kafka Strimzi**: Helm release (Strimzi operator 0.46.0) → patches namespace
3. **PostgreSQL**: Namespace → PVC → ConfigMaps → Deployment → Service → patches
4. **Keycloak**: Namespace → auto-ready → Keycloak CRD instance → patches

### 7.3 Functions

| Function | Package | Purpose |
|---|---|---|
| `function-patch-and-transform` | v0.9.0 | Resource patching and transformation |
| `function-auto-ready` | v0.5.0 | Automatic readiness detection |
| `function-go-templating` | v0.10.0 | Go template rendering |
| `function-kcl` | v0.11.4 | KCL function execution |
| `function-sequencer` | v0.2.3 | Step sequencing |

### 7.4 Providers

| Provider | Config |
|---|---|
| `provider-kubernetes` | `InjectedIdentity` credentials |
| `provider-helm` | `InjectedIdentity` credentials |

---

## 8. Output Formats

### 8.1 Plain YAML (ArgoCD/GitOps)

Generated by `kcl_to_yaml.yaml_stream_stack()`. Produces multi-document YAML with all K8s manifests (Namespaces, Deployments, Services, ConfigMaps, CRDs).

### 8.2 Helm Charts

Generated by builders:
- `chart_builder.k` → `Chart.yaml`
- `templates_builder.k` → `templates/manifests.yaml`
- Creates empty `values.yaml`

### 8.3 Helmfile

Generated by `helmfile_builder.k` → `helmfile.yaml` with release references to local charts.

### 8.4 Kusion Spec

Generated by `Release.kusionSpec` property which calls `kcl_to_kusion.kusion_spec_stream_stack()`. Each manifest becomes a `KusionResource` with:
- `id`: `apiVersion:kind:namespace:name`
- `type`: `Kubernetes`
- `attributes`: The full K8s manifest
- `dependsOn`: References to leader resources

---

## 9. Data Flow End-to-End

Example: Generating Kusion spec for Berlin v1.0.0:

```
1. kernel/project_def.k → video_streaming_project (Project instance)
2. stacks/versioned/v1_0_0/base/profile_def.k → v1_0_0 profile (Profile instance)
3. tenants/germany/tenant_def.k → germany tenant (Tenant instance)
4. sites/tenants/production/berlin/site_def.k → berlin site (Site instance)
5. core_sources/merge_configurations.k → merge(project, profile, tenant, site configs)
6. stacks/versioned/v1_0_0/base/stack_def.k → Stack with merged configs
   → Creates K8sNamespaces, Components, Accessories with concrete manifests
7. framework/models/release.k → Release with kusionSpec property
8. framework/procedures/kcl_to_kusion.k → Transform manifests to KusionResource format
9. Output: kusion_spec.yaml with all resources and dependency chains
```

---

## 10. Adding a New Project

1. Create `projects/<project_name>/` with `kcl.mod` and `main.k`
2. Create `kernel/` with project definition and base configurations
3. Create `core_sources/` with project-specific configuration schema and merge function
4. Create `modules/` with concrete K8s manifest modules
5. Create `stacks/` with stack definitions
6. Create `tenants/` and `sites/` for multi-tenancy
7. Create `pre_releases/` and/or `releases/` with factory builders

---

## 11. Adding a New Module

1. Create a new `.k` file in `modules/appops/` or `modules/infrastructure/`
2. Extend `component.Component` or `accessory.Accessory` via schema inheritance
3. Define `kind`, `leaders`, `manifests` with K8s resources
4. Add the module to the stack definition in `stacks/`

Example:
```kcl
import framework.models.modules.component as component

schema MyNewModule(component.Component):
    kind = "APPLICATION"
    leaders = [component.ComponentLeader {
        name = name
        kind = "Deployment"
        apiVersion = "apps/v1"
        namespace = namespace
    }]
    manifests = [
        # K8s Deployment, Service, etc.
    ]
```

---

## 12. Adding a New Output Format

1. Create a new procedure in `framework/procedures/kcl_to_<format>.k`
2. Define the transformation lambda that takes a Stack and outputs the target format
3. Optionally add custom schemas in `framework/custom/<format>/`
4. Add a new builder pattern in the factory (e.g., `<format>_builder.k`)
5. Add a new render type to `platform_cli/koncept`
