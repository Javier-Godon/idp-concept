# idp-concept — Developer & Concepts Guide

> **Audience:** Developers, platform engineers, and DevOps practitioners who need to work with or extend idp-concept.
>
> **Goal:** Understand every concept, component, and their relationships so you can confidently create projects, define deployments, and extend the platform.

---

## Table of Contents

1. [The Big Picture](#1-the-big-picture)
2. [Glossary of Concepts](#2-glossary-of-concepts)
3. [The Configuration Pipeline — Step by Step](#3-the-configuration-pipeline--step-by-step)
4. [Framework Layer — The Reusable Engine](#4-framework-layer--the-reusable-engine)
   - [4.1 Models (Domain Schemas)](#41-models-domain-schemas)
   - [4.2 Module Types (What Gets Deployed)](#42-module-types-what-gets-deployed)
   - [4.3 Procedures (Output Generators)](#43-procedures-output-generators)
   - [4.4 Custom Schemas (Format-Specific Models)](#44-custom-schemas-format-specific-models)
   - [4.5 Builders (Manifest Generators)](#45-builders-manifest-generators)
   - [4.6 Templates (High-Level Module Templates)](#46-templates-high-level-module-templates)
   - [4.7 Assembly Helpers (Stack Utilities)](#47-assembly-helpers-stack-utilities)
   - [4.8 Base Configurations & Generic Merge](#48-base-configurations--generic-merge)
   - [4.9 Factory Seed (Scaffolding)](#49-factory-seed-scaffolding)
5. [Project Layer — Your Concrete System](#5-project-layer--your-concrete-system)
   - [5.1 Kernel](#51-kernel)
   - [5.2 Core Sources](#52-core-sources)
   - [5.3 Modules](#53-modules)
   - [5.4 Stacks](#54-stacks)
   - [5.5 Tenants](#55-tenants)
   - [5.6 Sites](#56-sites)
   - [5.7 Pre-Releases & Releases](#57-pre-releases--releases)
   - [5.8 Factory (The Build System)](#58-factory-the-build-system)
6. [How Concepts Combine — The Overlap Matrix](#6-how-concepts-combine--the-overlap-matrix)
7. [Worked Example: Deploying to Berlin Production](#7-worked-example-deploying-to-berlin-production)
8. [Worked Example: Adding a New Microservice](#8-worked-example-adding-a-new-microservice)
9. [Worked Example: Adding a New Customer (Tenant)](#9-worked-example-adding-a-new-customer-tenant)
10. [Worked Example: Adding a New Environment (Site)](#10-worked-example-adding-a-new-environment-site)
11. [Worked Example: erp_back — A Complete Project Using Framework Templates](#11-worked-example-erp_back--a-complete-project-using-framework-templates)
12. [Migration Guide: Raw Manifests → Templates](#12-migration-guide-raw-manifests--templates)
13. [Common Patterns & Conventions](#13-common-patterns--conventions)
14. [Troubleshooting & FAQ](#14-troubleshooting--faq)

---

## 1. The Big Picture

idp-concept solves one fundamental problem: **how do you define a system once and deploy it everywhere, in any format, for any customer?**

Traditional approaches tie you to one tool (Helm, Kustomize, etc.). If you change tools, you rewrite everything. idp-concept uses **KCL** as a single source of truth, and from that single definition, generates output in any format: plain YAML, Helm charts, Helmfile, Kusion specs, or Crossplane compositions.

Think of it like a compiler:

```
Your System Definition (KCL)
        │
        ▼
   ┌─────────┐
   │ Merge   │  ← kernel + profile + tenant + site configs
   │ Configs │
   └────┬────┘
        │
        ▼
   ┌─────────┐
   │  Stack  │  ← assembled components, infrastructure, namespaces
   └────┬────┘
        │
        ▼
   ┌─────────┐
   │ Factory │  ← choose output format
   └────┬────┘
        │
   ┌────┼────────┬────────────┐
   ▼    ▼        ▼            ▼
  YAML  Helm   Helmfile    Kusion
```

---

## 2. Glossary of Concepts

Before diving deeper, here is a quick reference for every concept. Each is explained in detail later.

| Concept | What It Is | Analogy |
|---|---|---|
| **Framework** | Reusable schemas, procedures, and types shared across all projects | A library/SDK |
| **Project** | A deployable system (e.g., "Video Streaming Platform") | A software product |
| **Kernel** | The project's base identity and default configuration | The "factory defaults" |
| **Core Sources** | The project's configuration schema + merge function | The "configuration contract" |
| **Module** | A deployable unit: an app, a database, a CRD resource | A microservice or infra piece |
| **Component** | A module type for applications/infrastructure workloads | A Deployment+Service combo |
| **Accessory** | A module type for CRDs and secrets (supporting resources) | A Kafka cluster, a PV |
| **K8sNamespace** | A module type that creates a Kubernetes namespace | A `kubectl create namespace` |
| **ThirdParty** | A module type for vendor-managed resources (Helm charts, etc.) | An operator-installed chart |
| **Stack** | An assembly of modules: which components, accessories, namespaces to deploy together | A "deployment bundle" |
| **Profile** | How a component should behave (dev mode, prod mode, version X) | A build configuration |
| **Tenant** | A customer or organization that uses the system | A paying customer |
| **Site** | A target deployment environment for a specific tenant | A Kubernetes cluster |
| **Release** | A versioned, immutable snapshot combining project + tenant + site + profile + stack | A "deployment receipt" |
| **Pre-Release** | A development/staging release (mutable, experimental) | A dev/staging deployment |
| **Factory** | The build directory that merges configs and generates output | The "build system" |
| **Procedure** | A framework function that converts a stack into a specific output format | A compiler backend |

---

## 3. The Configuration Pipeline — Step by Step

The central design principle is **layered configuration merging**. Every deployment is the result of overlapping four configuration layers:

```
Layer 1: KERNEL        → "What is this project?"
                            Base defaults for the entire system
                            Example: projectName = "video streaming"

Layer 2: PROFILE       → "What version/mode is this deployment?"
                            Adds namespace defaults, version-specific settings
                            Example: appsNamespace = "apps", postgresNamespace = "postgres"

Layer 3: TENANT        → "Who is this deployment for?"
                            Customer-specific branding, features, limits
                            Example: brandIcon = "🇩🇪", feature flags

Layer 4: SITE          → "Where does this deployment run?"
                            Environment-specific URLs, credentials, resource sizes
                            Example: siteName = "Berlin", rootPaths = { opensearch: "http://..." }
```

These four layers merge using KCL's **union operator** (`|`), which means **later layers override earlier ones**:

```kcl
finalConfig = kernel | profile | tenant | site
```

This is powerful because:
- **Kernel** sets sensible defaults for the whole project
- **Profile** tailors those defaults for a lifecycle stage or version
- **Tenant** adds customer-specific customizations
- **Site** pins the deployment to a specific environment

If a field is set in Kernel and also in Site, the **Site value wins**. If a field is only set in Kernel, it flows through unchanged.

### Visual: Configuration Overlap

```
┌──────────────────────────────────────────────────────┐
│ KERNEL                                                │
│   projectName = "video streaming"                     │
│   appsNamespace = ?                                   │
│   brandIcon = ?                                       │
│   siteName = ?                                        │
│   rootPaths = ?                                       │
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
│ + PROFILE                                             │
│   appsNamespace = "apps"             ← NEW            │
│   postgresNamespace = "postgres"     ← NEW            │
│   certmanagerNamespace = "cert-manager" ← NEW         │
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
│ + TENANT (Germany)                                    │
│   brandIcon = "&&&###/..@(())"       ← NEW            │
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
│ + SITE (Berlin)                                       │
│   siteName = "Berlin"                ← NEW            │
│   rootPaths = { opensearch: "..." }  ← NEW            │
└──────────────────────────────────────────────────────┘

RESULT:
  projectName = "video streaming"       (from Kernel)
  appsNamespace = "apps"                (from Profile)
  postgresNamespace = "postgres"        (from Profile)
  certmanagerNamespace = "cert-manager" (from Profile)
  brandIcon = "&&&###/..@(())"          (from Tenant)
  siteName = "Berlin"                   (from Site)
  rootPaths = { opensearch: "..." }     (from Site)
```

---

## 4. Framework Layer — The Reusable Engine

The `framework/` directory is the **shared library** every project imports. It defines:
1. **Models** — The vocabulary: what is a Project, Tenant, Stack, etc.?
2. **Module types** — The building blocks: Component, Accessory, K8sNamespace, ThirdParty
3. **Procedures** — The converters: how to turn a Stack into YAML, Helm, Kusion, etc.
4. **Custom schemas** — Output-format-specific models: Helm Chart.yaml, helmfile.yaml, etc.
5. **Builders** — Low-level manifest generators: Deployment, Service, ConfigMap, PV/PVC, ServiceAccount
6. **Templates** — High-level module patterns: WebAppModule, SingleDatabaseModule, KafkaClusterModule
7. **Assembly helpers** — Stack utilities: namespace creation shortcuts
8. **Base configurations** — Generic config schema + merge function for all projects
9. **Factory seed** — Scaffolding for factory setup (merge + release + stack)

### 4.1 Models (Domain Schemas)

Every framework model follows the **Schema + Instance pattern**:

```kcl
# The Instance is a flat, validated data container
schema ProjectInstance:
    name: str
    description: str
    configurations: any

# The Schema validates input and creates an Instance from its fields
schema Project:
    instance: ProjectInstance = ProjectInstance {
        name = name
        description = description
        configurations = configurations
    }
    name: str
    description: str
    configurations: any
```

**Why two schemas?** When you create a `Project`, it validates the input and automatically creates a `.instance` containing flat, ready-to-use data. Downstream code (stacks, releases, procedures) works with `ProjectInstance` — a clean, immutable data container.

```kcl
# Create (validates)
myProject = project.Project {
    name = "My App"
    description = "..."
    configurations = myConfigs
}

# Use downstream (flat data)
release = release.Release {
    project = myProject.instance   # ← Pass the flat data
    ...
}
```

#### The Full Model Hierarchy

```
Project ─── Has configurations (kernel defaults)
   │
Profile ─── Has configurations (version/mode settings)
   │
Tenant ──── Has configurations (customer overrides)
   │
   └── Site ─── Has configurations (environment overrides)
               Has reference to owning Tenant
   │
Stack ──── Aggregates:
   │       ├── [K8sNamespace]   (0 or more namespaces)
   │       ├── [Component]      (1 or more applications/infra workloads)
   │       ├── [Accessory]      (0 or more CRDs/secrets)
   │       └── [ThirdParty]     (0 or more vendor resources)
   │
Release ─── Combines:
            ├── ProjectInstance
            ├── ProfileInstance
            ├── TenantInstance
            ├── SiteInstance
            └── Stack (with all its modules)
```

**Project** — The root entity. Represents the entire system ("Video Streaming Platform"). Contains base configurations defined in the kernel.

**Profile** — Describes HOW a deployment should behave. Orthogonal to WHERE it runs. Think of it as a "build configuration" — dev mode vs prod mode, v1.0.0 vs v2.0.0. A profile adds namespace assignments, version-specific settings, and behavioral flags.

**Tenant** — WHO the deployment is for. Represents a customer, organization, or internal team. Tenants override branding, feature flags, limits, or any customer-specific configuration.

**Site** — WHERE the deployment runs. A site is always owned by a Tenant. It represents a specific Kubernetes cluster or environment (dev cluster, staging, production Berlin). Sites override environment endpoints (URLs, credentials references, resource sizes).

**Stack** — WHAT gets deployed. It's the bill of materials: which namespaces to create, which applications to run, which infrastructure to provision. The stack uses the merged configuration from all four layers to parameterize its modules.

**Release** — A versioned snapshot that ties everything together: this project, for this tenant, at this site, with this profile, deploying this stack. Releases are immutable — once created, they represent a specific point-in-time deployment.

### 4.2 Module Types (What Gets Deployed)

Modules are the actual Kubernetes resources. Each module type extends a framework base schema:

| Module Type | Base Schema | Kind Values | Use For |
|---|---|---|---|
| **Component** | `component.Component` | `"APPLICATION"`, `"INFRASTRUCTURE"` | Deployments, StatefulSets, Services, ConfigMaps — workloads that run |
| **Accessory** | `accessory.Accessory` | `"CRD"`, `"SECRET"` | Kafka clusters, PVs, database CRDs — supporting infrastructure |
| **K8sNamespace** | `k8snamespace.K8sNamespace` | `"Namespace"` (fixed) | Kubernetes namespaces — auto-generates the manifest |
| **ThirdParty** | `thirdparty.ThirdParty` | N/A | Helm charts, Kustomize overlays — vendor-managed resources |

#### Module Anatomy

Every Component and Accessory has these key fields:

```kcl
schema MyModule(component.Component):       # or accessory.Accessory
    kind = "APPLICATION"                     # What type of module
    
    leaders = [component.ComponentLeader {   # The "main" K8s resource(s)
        name = name                          # for dependency tracking
        kind = "Deployment"
        apiVersion = "apps/v1"
        namespace = namespace
    }]
    
    manifests = [                            # The actual K8s objects to create
        apps.Deployment { ... }
        core.Service { ... }
        core.ConfigMap { ... }
    ]
```

**`leaders`** — Identifies the primary Kubernetes resource(s) this module manages. This is used for dependency ordering: if another module depends on this one, it needs to know which K8s resource to wait for.

**`manifests`** — A list of fully-rendered Kubernetes objects. These are what get serialized to YAML/Helm/Kusion.

**`dependsOn`** — References to other modules (usually namespaces) that must be deployed before this one.

#### How K8sNamespace Works (Auto-Generation)

K8sNamespace is special — it auto-generates its manifest from just a name:

```kcl
_apps_namespace = k8snamespace.K8sNamespace {
    name = "apps"
    configurations = instanceConfigurations
}.instance
```

This creates a `v1/Namespace` manifest with `metadata.name = "apps"`, auto-populates `leaders`, and handles labels/annotations if provided. You never write the Namespace YAML yourself.

#### How ThirdParty Works

ThirdParty modules represent vendor-managed resources. They don't generate K8s manifests directly — instead, they carry configuration for an external package manager:

```kcl
myHelmChart = thirdparty.ThirdParty {
    packageManager = "HELM"
    platformConfigurations = { ... }       # Our abstraction layer
    vendorConfigurations = { ... }         # Raw Helm values
}
```

### 4.3 Procedures (Output Generators)

Procedures are lambda functions that take a Stack and transform it into a specific output format:

| Procedure | Input | Output | File |
|---|---|---|---|
| `yaml_stream_stack()` | `GitOpsStack` | Multi-document YAML | `kcl_to_yaml.k` |
| `generate_helm_components_templates_from_stack()` | `Stack` | Helm template YAML | `kcl_to_helm.k` |
| `kusion_spec_stream_stack()` | `Stack` | `[KusionResource]` | `kcl_to_kusion.k` |
| `extract_models_by_name_from_list()` | Models + name | Filtered list | `helper.k` |

**How they work internally:**

1. **Extract** — Pull manifests from each module type (components, accessories, namespaces)
2. **Transform** — Convert to the target format (add Kusion IDs, dependency chains, etc.)
3. **Serialize** — Output as YAML stream or structured data

The YAML procedure simply flattens all manifests and calls `manifests.yaml_stream()`. The Kusion procedure wraps each manifest in a `KusionResource` envelope with a composite ID (`apiVersion:kind:namespace:name`) and resolves `dependsOn` references through the leader pattern.

### 4.4 Custom Schemas (Format-Specific Models)

These model the output format structures themselves:

- **`helm/helm.k`** — `Chart` (Chart.yaml), `HelmChartValues` (values.yaml), `Dependency`, `Maintainer`
- **`helmfile/helmfile.k`** — `Helmfile`, `Repository`, `Release`, `Environment`, `Hooks`
- **`argocd/models/`** — Auto-generated from ArgoCD CRDs: `Application`, `ApplicationSet`, `AppProject`
- **`spring_application_properties.k`** — Spring Boot `application.properties` for Java microservices (Postgres, Keycloak, Flyway, OpenSearch, QuestDB, SpringDoc, Actuator)

### 4.5 Builders (Manifest Generators)

**Location:** `framework/builders/`

**Purpose:** Eliminate repetitive Kubernetes manifest boilerplate. Each builder takes a high-level spec schema and produces a fully-rendered K8s object.

**Available builders:**

| Builder File | Function | Input | Output |
|---|---|---|---|
| `deployment.k` | `build_deployment` | `DeploymentSpec` | `apps.Deployment` |
| `service.k` | `build_service` | `ServiceSpec` | `core.Service` |
| `configmap.k` | `build_configmap` | `ConfigMapSpec` | `core.ConfigMap` |
| `storage.k` | `build_pv_and_pvc` | `PersistentVolumeSpec` | `[PV, PVC]` (list of 2) |
| `service_account.k` | `build_service_account` | `ServiceAccountSpec` | `core.ServiceAccount` |
| `leader.k` | `build_component_leader` / `build_accessory_leader` | name, namespace, ... | Leader instances |

**Example — building a Deployment with probes and resources:**
```kcl
import framework.builders.deployment as deploy

_my_deployment = deploy.build_deployment(deploy.DeploymentSpec {
    name = "my-app"
    namespace = "apps"
    image = "myregistry/my-app"
    version = "1.0.0"
    port = 8080
    replicas = 2
    env = [{ name = "DB_HOST", value = "postgres" }]
    resources = deploy.ResourceSpec {
        cpuLimit = "2"
        memoryLimit = "4Gi"
    }
    livenessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health/liveness"
        port = 8080
    }
    readinessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health/readiness"
        port = 8080
    }
})
```

This replaces ~80 lines of manual Deployment YAML with a typed, validated call.

**Probe types:** `"exec"` (default, runs a command), `"http"` (HTTP GET), `"tcp"` (TCP socket check).

**ConfigMap auto-wiring:** If you set `configMapRef` in `DeploymentSpec`, the builder automatically adds a volume and volumeMount for that ConfigMap.

### 4.6 Templates (High-Level Module Templates)

**Location:** `framework/templates/`

**Purpose:** Pre-built module patterns that combine multiple builders into a single schema. A template auto-generates all the K8s manifests you need. You set high-level fields (port, replicas, probes) and the template does the rest.

**Available templates:**

| Template | Base Type | Generates |
|---|---|---|
| `webapp.k` → `WebAppModule` | Component | Deployment + Service + ConfigMap + ServiceAccount |
| `database.k` → `SingleDatabaseModule` | Accessory | Deployment + Service + PV + PVC |
| `kafka.k` → `KafkaClusterModule` | Accessory | Kafka CRD + KafkaTopic CRDs |

**Example — Web application in ~15 lines instead of ~190:**
```kcl
import framework.templates.webapp as webapp
import framework.builders.deployment as deploy

schema MyApiModule(webapp.WebAppModule):
    port = 8080
    serviceType = "ClusterIP"
    replicas = 2
    configData = {
        "application.yaml" = "server.port: 8080\nspring.profiles.active: dev"
    }
    resources = deploy.ResourceSpec {
        cpuLimit = "2"
        memoryLimit = "4Gi"
    }
    livenessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health/liveness"
        port = 8080
    }
    readinessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health/readiness"
        port = 8080
    }
```

The template generates Deployment, Service, ConfigMap, and ServiceAccount automatically. Leaders and manifests are auto-computed.

**Example — Database module in ~10 lines:**
```kcl
import framework.templates.database as database

schema MyPostgresModule(database.SingleDatabaseModule):
    port = 5432
    dataPath = "/var/lib/postgresql/data"
    storageSize = "50Gi"
    env = [
        { name = "POSTGRES_DB", value = "mydb" }
        { name = "POSTGRES_USER", valueFrom.secretKeyRef = { name = "pg-secret", key = "user" } }
    ]
```

**Example — Kafka cluster in ~8 lines:**
```kcl
import framework.templates.kafka as kafka

schema MyKafkaModule(kafka.KafkaClusterModule):
    clusterName = "events-cluster"
    kafkaReplicas = 3
    topics = [
        kafka.KafkaTopicSpec { name = "events", partitions = 6, replicas = 3 }
        kafka.KafkaTopicSpec { name = "dead-letters", partitions = 3 }
    ]
```

**When to use templates vs raw builders:**
- Use **templates** when your module fits a known pattern (web app, database, Kafka). This is the recommended approach for new projects.
- Use **raw builders** when you need full control over the manifest structure (custom sidecar containers, init containers, complex volume setups).
- Use **neither** (raw manifests) when dealing with unusual resource types not covered by builders (video_streaming's existing modules use this approach).

### 4.7 Assembly Helpers (Stack Utilities)

**Location:** `framework/assembly/helpers.k`

**Purpose:** Reduce boilerplate in stack definitions. The most common pattern — creating a K8sNamespace instance — is wrapped in a one-liner.

**Available helpers:**

| Helper | Purpose |
|---|---|
| `create_namespace(name, configurations)` | Create a K8sNamespace from a literal name |
| `create_namespace_from_config(configurations, fieldName)` | Create a K8sNamespace using a config field value as the name |

**Example — Before (verbose):**
```kcl
_apps_namespace = k8snamespace.K8sNamespace {
    name = instanceConfigurations.appsNamespace
    configurations = instanceConfigurations
}.instance
```

**Example — After (with helper):**
```kcl
import framework.assembly.helpers as asm

_apps_namespace = asm.create_namespace(instanceConfigurations.appsNamespace, instanceConfigurations)
```

### 4.8 Base Configurations & Generic Merge

**Location:** `framework/models/configurations.k`

**Purpose:** Provides a `BaseConfigurations` schema that all projects can extend, and a generic `merge_configurations` lambda.

**BaseConfigurations fields (shared across all projects):**
```kcl
schema BaseConfigurations:
    projectName?: str
    appsNamespace?: str
    siteName?: str
    brandIcon?: str
```

**Usage — Extend for your project:**
```kcl
import framework.models.configurations as base

schema MyProjectConfigurations(base.BaseConfigurations):
    # Add project-specific fields
    postgresNamespace?: str
    postgresHost?: str
    springProfile?: str
```

**Generic merge function:**
```kcl
import framework.models.configurations as base

# In your core_sources/merge_configurations.k:
merge_configurations = lambda kernel, profile, tenant, site -> any {
    base.merge_configurations(kernel, profile, tenant, site)
}
```

This replaces the manual `_configs = kernel | profile | tenant | site` pattern with a reusable function.

### 4.9 Factory Seed (Scaffolding)

**Location:** `framework/factory/seed.k`

**Purpose:** Provides a `FactorySeed` schema that automates the factory setup: merging configs, creating a Release, and preparing GitOpsStack. Used in factory directories.

**Key fields:**
- `project`, `profile`, `tenant`, `site` — The four inputs
- `mergeFunction` — Your project's merge lambda
- `stackBuilder` — A lambda that takes merged config and returns a Stack

**Auto-computed fields:**
- `mergedConfigurations` — Result of merging all 4 layers
- `stack` — The built stack
- `release` — A Release combining all instances

This schema exists for convenience. The `erp_back` project uses a manual approach (importing directly in `factory_seed.k`) because it needs finer control over GitOpsStack creation. Both patterns are valid.

---

## 5. Project Layer — Your Concrete System

A project takes the framework's abstract models and fills them with your specific Kubernetes resources, configuration values, and deployment targets. Let's walk through each component of the `video_streaming` reference project.

### 5.1 Kernel

**Location:** `projects/<name>/kernel/`

**Purpose:** Defines the project's identity and base configuration defaults. The kernel is the starting point — every deployment begins with these values.

**What it contains:**
- `project_def.k` — Creates the `Project` instance (name, description)
- `configurations.k` — Seeds the first layer of `VideoStreamingConfigurations`

```
kernel/
├── kcl.mod                 # Package: depends on framework + parent project
├── main.k                  # Placeholder
├── project_def.k           # Project { name, description, configurations }
└── configurations.k        # VideoStreamingConfigurations { projectName = "..." }
```

**Think of it as:** The factory defaults. If you deployed with no profile, no tenant, and no site overrides, you'd get the kernel configuration.

**Key file — `project_def.k`:**
```kcl
import framework.models.project
import video_streaming.kernel.configurations

video_streaming_project = project.Project {
    name = "Video Streaming"
    description = "video streaming using apache kafka"
    configurations = configurations._video_streaming_kernel_configurations
}
```

**Key file — `configurations.k`:**
```kcl
import video_streaming.core_sources.video_streaming_configurations

_video_streaming_kernel_configurations = video_streaming_configurations.VideoStreamingConfigurations {
    projectName = "video streaming"
}
```

### 5.2 Core Sources

**Location:** `projects/<name>/core_sources/`

**Purpose:** This is the **configuration contract** for your project. It defines:
1. The **schema** of all configurable fields (what CAN be configured)
2. The **merge function** that combines the four configuration layers

**What it contains:**
- `video_streaming_configurations.k` — The configuration schema
- `merge_configurations.k` — The merge lambda

```
core_sources/
├── kcl.mod
├── main.k
├── video_streaming_configurations.k   # schema VideoStreamingConfigurations
└── merge_configurations.k             # merge_configurations = lambda(k, p, t, s)
```

**Think of it as:** A contract that every configuration layer must follow. The kernel, profile, tenant, and site all produce instances of this same schema. The merge function combines them.

**Key file — `video_streaming_configurations.k`:**
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

All fields are optional (`?`) because each layer only sets some of them. Defaults are provided where sensible.

**Key file — `merge_configurations.k`:**
```kcl
merge_configurations = lambda kernel, profile, tenant, site -> VideoStreamingConfigurations {
    _configs = kernel
    _configs = _configs | profile    # Profile overrides kernel
    _configs = _configs | tenant     # Tenant overrides profile
    _configs = _configs | site       # Site overrides tenant
}
```

### 5.3 Modules

**Location:** `projects/<name>/modules/`

**Purpose:** The concrete Kubernetes resources — Deployments, Services, ConfigMaps, CRDs. Each module is a reusable, parameterized template that inherits from a framework base type.

**Structure convention:**
```
modules/
├── appops/                              # Application workloads
│   ├── video_collector_mongodb_python/  # A microservice
│   │   └── video_collector_mongodb_python_module_def.k
│   └── kafka_video_server_python/       # Another microservice
└── infrastructure/                      # Infrastructure resources
    ├── apache_kafka/
    │   └── instances/kafka_single_instance_module_def.k
    └── mongodb/
        ├── mongodb_single_instance_module_def.k
        └── mongodb_persistence_module_def.k
```

**Think of it as:** Library of Kubernetes blueprints. Each module is parameterized (takes `name`, `namespace`, `asset`, `configurations`, `dependsOn`) and produces ready-to-deploy K8s manifests.

**Example — Application Component:**
```kcl
import framework.models.modules.component

schema VideoCollectorMongodbPythonModule(component.Component):
    kind = "APPLICATION"
    leaders = [component.ComponentLeader {
        name = name
        kind = "Deployment"
        apiVersion = "apps/v1"
        namespace = namespace
    }]
    manifests = [
        apps.Deployment {
            metadata.name = name
            metadata.namespace = namespace
            spec.template.spec.containers = [{
                name = name
                image = "${asset.image}:${asset.version}"
                # ... ports, probes, resources, volume mounts
            }]
        }
        core.Service { ... }
        core.ConfigMap { ... }
        core.ServiceAccount { ... }
    ]
```

**Example — Infrastructure Accessory:**
```kcl
import framework.models.modules.accessory

schema KafkaSingleInstanceModule(accessory.Accessory):
    kind = "CRD"
    leaders = [accessory.AccessoryLeader {
        name = "blue-kafka-cluster"
        kind = "Kafka"
        apiVersion = "kafka.strimzi.io/v1beta2"
        namespace = namespace
    }]
    manifests = [
        { apiVersion = "kafka.strimzi.io/v1beta2", kind = "Kafka", ... }
        { apiVersion = "kafka.strimzi.io/v1beta2", kind = "KafkaTopic", ... }
    ]
```

### 5.4 Stacks

**Location:** `projects/<name>/stacks/`

**Purpose:** A stack assembles modules into a **deployment bundle**. It decides:
- Which namespaces to create
- Which applications (components) to deploy
- Which infrastructure (accessories) to provision
- How they depend on each other

**Structure:**
```
stacks/
├── stack_configurations.k          # Shared profile configurations
├── development/                     # Development lifecycle
│   ├── profile_configurations.k    # Profile-level config overrides
│   ├── profile_def.k               # Profile instance
│   └── stack_def.k                 # Stack schema (THE assembly)
└── versioned/
    ├── v1_0_0/base/                # Production v1.0.0
    │   ├── profile_def.k
    │   └── stack_def.k
    └── v2_0_0/base/                # Future v2.0.0
```

**Think of it as:** A deployment recipe. "For the development environment, deploy these 5 namespaces, this 1 application, and these 3 infrastructure pieces."

**Each stack directory contains:**
1. **`profile_def.k`** — Creates a `Profile` instance with configuration overrides for this lifecycle stage
2. **`profile_configurations.k`** — The configuration values specific to this profile
3. **`stack_def.k`** — The actual assembly: instantiates modules and wires them together

**Key file — `stack_def.k` (Development):**
```kcl
schema VideoStreamingDevelopmentStack(stack.Stack):
    # NAMESPACES — created first, other modules depend on them
    k8snamespaces = [
        _apps_namespace, _postgres_namespace, _certmanager_namespace,
        _apache_kafka_namespace, _mongodb_namespace
    ]
    
    # Individual namespace definitions read names from merged config
    _apps_namespace = k8snamespace.K8sNamespace {
        name = instanceConfigurations.appsNamespace
        configurations = instanceConfigurations
    }.instance
    
    # COMPONENTS — application workloads
    components = [_video_collector_mongodb_python]
    
    _video_collector_mongodb_python = video_collector.VideoCollectorMongodbPythonModule {
        name = "kafka_video_consumer_mongodb_python"
        namespace = _apps_namespace.name       # ← reads from namespace
        asset = { image = "...", version = "..." }
        configurations = instanceConfigurations # ← merged config flows through
        dependsOn = [_apps_namespace]           # ← deploys AFTER namespace exists
    }.instance
    
    # ACCESSORIES — infrastructure
    accessories = [_apache_kafka_instance, _mongodb_instance, _mongodb_persistence]
    
    _apache_kafka_instance = kafka.KafkaSingleInstanceModule {
        name = "kafka"
        namespace = "kafka"
        asset = { image = "strimzi", version = "0.45.0" }
        configurations = instanceConfigurations
        dependsOn = [_apache_kafka_namespace]   # ← deploys AFTER namespace
    }.instance
```

**Important patterns in stacks:**

1. **`instanceConfigurations`** — The merged configuration flows through this field. Modules read namespace names, endpoints, etc. from it.
2. **`.instance`** — Every module is created and immediately accessed via `.instance` to get the flat data container.
3. **`dependsOn`** — Declares ordering: "deploy this after that". Typically, everything depends on its namespace.
4. **Namespace names from config** — `instanceConfigurations.appsNamespace` means the namespace name comes from the merged configuration, not hardcoded.

### 5.5 Tenants

**Location:** `projects/<name>/tenants/`

**Purpose:** Define customers or organizations that use the system. Each tenant can override configuration values.

**Structure:**
```
tenants/
├── germany/
│   ├── tenant_def.k              # Tenant instance
│   └── germany_configurations.k  # Customer-specific overrides
├── italy/
│   └── tenant_def.k              # Tenant instance (no overrides)
├── spain/
│   └── tenant_def.k
└── vendor/                        # Internal (our company)
    ├── tenant_def.k
    └── tenant_configurations.k
```

**Think of it as:** Customer profiles. Germany needs a custom brand icon, Italy uses all defaults.

**Key file — `tenant_def.k` (Germany):**
```kcl
import framework.models.tenant

tenant_germany = tenant.Tenant {
    name = "Germany"
    description = "Government of Germany"
    configurations = _germany_tenant_configurations
}
```

**Key file — `germany_configurations.k`:**
```kcl
_germany_tenant_configurations = VideoStreamingConfigurations {
    brandIcon = "&&&###/..@(())"    # Germany's custom branding
}
```

### 5.6 Sites

**Location:** `projects/<name>/sites/`

**Purpose:** Define target deployment environments. Each site belongs to a tenant and provides environment-specific configuration (URLs, endpoints, resource sizes).

**Structure:**
```
sites/
├── sites_configurations.k                  # Shared site defaults
├── development/
│   ├── dev_cluster/
│   │   ├── site_def.k                     # Site instance
│   │   └── configurations.k              # Dev-specific config
│   └── stg_cluster/                       # Staging cluster
└── tenants/
    ├── pre_production/berlin/             # Berlin pre-prod
    └── production/berlin/                 # Berlin production
        ├── site_def.k                     # Site instance (binds to Germany tenant)
        ├── configurations.k               # Reads from config.yaml
        └── config.yaml                    # External YAML config source
```

**Think of it as:** "Where does this run?" Each site pins a tenant to a specific cluster with its own endpoints.

**Key relationship: Site → Tenant**
```kcl
dev_cluster_site = site.Site {
    name = "dev_cluster"
    tenant = vendor.tenant_vendor          # ← This site belongs to the Vendor tenant
    configurations = VideoStreamingConfigurations {
        siteName = "dev cluster"
        rootPaths = { "local opensearch": "http://opensearch.opensearch" }
    }
}
```

**Note:** Sites can read configuration from adjacent YAML files (useful for values managed outside KCL):
```kcl
import yaml
data_from_yaml = yaml.decode(file.read("config.yaml"))

_configs = VideoStreamingConfigurations {
    siteName = data_from_yaml.site.name
    rootPaths = { "local opensearch": data_from_yaml.rootPaths.localOpensearch }
}
```

### 5.7 Pre-Releases & Releases

**Location:** `projects/<name>/pre_releases/` and `projects/<name>/releases/`

**Purpose:** These are where everything comes together. A release:
1. **Selects** a project, profile, tenant, and site
2. **Merges** their configurations
3. **Instantiates** a stack with the merged config
4. **Generates output** in one or more formats

**The distinction:**
- **Pre-Release** — Development/staging deployments. Mutable, can be updated. Used for testing before customer delivery.
- **Release** — Production deployments. Versioned and immutable. Each release is a snapshot: v1.0.0 for Berlin, v1.0.0 for Madrid, etc.

**Structure:**
```
pre_releases/
├── configurations_dev.k                    # Merge all 4 layers for dev
└── gitops/site_one/generators/
    └── kafka_.../dev/factory/              # Factory for this output
        ├── factory_seed.k                  # Setup: merge, stack, release
        ├── kubernetes_manifests_builder.k  # → YAML
        └── argocd_builder.k               # → ArgoCD Application

releases/
├── helmfile/berlin/v1_0_0_berlin/factory/  # Helmfile output
│   ├── factory_seed.k
│   ├── chart_builder.k                    # → Chart.yaml
│   ├── templates_builder.k               # → templates/manifests.yaml
│   ├── helmfile_builder.k                 # → helmfile.yaml
│   └── values_builder.k                  # → values.yaml
└── kusion/berlin/v1_0_0_berlin/default/factory/
    └── main.k                             # → Kusion spec
```

### 5.8 Factory (The Build System)

**Location:** Inside every pre-release or release directory

**Purpose:** The factory is the "build system" for a specific deployment. It follows a consistent pattern:

1. **`factory_seed.k`** — The setup file. It:
   - Imports the project, profile, tenant, and site
   - Calls `merge_configurations()` to produce final config
   - Creates the stack with merged config
   - Creates a `Release` object
   
2. **`*_builder.k`** — One per output format. It:
   - Imports `factory_seed`
   - Calls the appropriate procedure
   - Outputs the result

**`factory_seed.k` pattern:**
```kcl
import video_streaming.kernel.project_def
import video_streaming.stacks.development.stack_def
import video_streaming.stacks.development.profile_def
import video_streaming.tenants.vendor
import video_streaming.sites.development.dev_cluster.site_def
import video_streaming.core_sources.merge_configurations as merge
import framework.models.release

# Select the 4 layers
_project = project_def.video_streaming_project
_profile = profile_def.video_streaming_development_profile
_tenant = vendor.tenant_vendor
_site = site_def.dev_cluster_site

# Merge configurations
_merged = merge.merge_configurations(
    _project.configurations,
    _profile.configurations,
    _tenant.configurations,
    _site.configurations
)

# Create the stack with merged config
_stack = stack_def.VideoStreamingDevelopmentStack {
    instanceConfigurations = _merged
}

# Create the release
_release = release.Release {
    name = "pre_release_development_dev_cluster"
    version = "1.0.0"
    project = _project.instance
    tenant = _tenant.instance
    site = _site.instance
    profile = _profile.instance
    stack = _stack
}
```

**`kubernetes_manifests_builder.k` pattern:**
```kcl
import framework.procedures.kcl_to_yaml
import .factory_seed

kcl_to_yaml.yaml_stream_stack(factory_seed._my_gitops_stack)
```

---

## 6. How Concepts Combine — The Overlap Matrix

This table shows which concepts interact with which, and how:

| Concept A | Concept B | Relationship |
|---|---|---|
| **Project** | **Kernel** | 1:1 — The kernel IS the project's base identity |
| **Project** | **Core Sources** | 1:1 — Core sources define the project's config contract |
| **Project** | **Module** | 1:N — A project defines N modules (apps, infra) |
| **Project** | **Stack** | 1:N — A project can have multiple stacks (dev, v1, v2) |
| **Project** | **Tenant** | 1:N — A project serves N customers |
| **Stack** | **Profile** | 1:1 — Each stack has one profile defining its mode |
| **Stack** | **Module** | 1:N — A stack assembles N modules for deployment |
| **Stack** | **Config** | 1:1 — A stack receives one merged configuration |
| **Tenant** | **Site** | 1:N — Each tenant has N sites (clusters/environments) |
| **Tenant** | **Config** | 1:1 — Each tenant provides one config override layer |
| **Site** | **Config** | 1:1 — Each site provides one config override layer |
| **Release** | **Project + Profile + Tenant + Site + Stack** | Combines all 5 — The deployment snapshot |
| **Factory** | **Release** | 1:1 — Each factory produces one release's output |
| **Factory** | **Procedure** | 1:N — A factory can call N procedures for N output formats |

### When Does Each Concept Change?

| Concept | Changes When... | Changed By |
|---|---|---|
| **Kernel** | Project fundamentals change (name, base defaults) | Project owner |
| **Core Sources** | New configurable fields are needed | Project architect |
| **Module** | K8s manifest templates change (new probes, resources, env vars) | Module developer |
| **Stack** | Which modules to deploy changes, or dependency ordering changes | Stack assembler |
| **Profile** | A new version or lifecycle stage is needed (v2.0.0, canary) | Release manager |
| **Tenant** | A new customer is onboarded or their settings change | Operations team |
| **Site** | A new environment is provisioned or endpoints change | Infrastructure team |
| **Release** | A new production deployment snapshot is created | Release manager |

---

## 7. Worked Example: Deploying to Berlin Production

Let's trace the complete flow for generating Kusion output for Berlin v1.0.0:

**Step 1 — Kernel provides base config:**
```
projectName = "video streaming"
```

**Step 2 — Profile (v1.0.0) adds:**
```
appsNamespace = "apps"
postgresNamespace = "postgres"
certmanagerNamespace = "cert-manager"
```

**Step 3 — Tenant (Germany) adds:**
```
brandIcon = "&&&###/..@(())"
```

**Step 4 — Site (Berlin production) adds:**
```
siteName = "Berlin"
rootPaths = {
    "local opensearch": "http://opensearch.opensearch"
    "central opensearch": "https://central-services/opensearch"
    "keycloak": "keycloak.keycloak/realm/auth"
}
```

**Step 5 — Merge:** `kernel | profile | tenant | site` → final config

**Step 6 — Stack instantiated** with merged config. Creates:
- 5 K8sNamespace manifests (apps, postgres, cert-manager, kafka, mongodb)
- 1 video collector Deployment + Service + ConfigMap + ServiceAccount
- 1 Kafka cluster (Strimzi) + 2 KafkaTopic CRDs
- 1 MongoDB Deployment + Service
- 1 MongoDB PersistentVolume + PersistentVolumeClaim

**Step 7 — Release wraps** project + tenant + site + profile + stack

**Step 8 — Kusion procedure** transforms each manifest into `KusionResource`:
```yaml
- id: "v1:Namespace:apps"
  type: Kubernetes
  attributes: { apiVersion: v1, kind: Namespace, metadata: { name: apps } }

- id: "apps/v1:Deployment:apps:kafka_video_consumer_mongodb_python"
  type: Kubernetes
  attributes: { ... full Deployment manifest ... }
  dependsOn:
    - "v1:Namespace:apps"
```

**Step 9 — Output:** `resources = _release.kusionSpec` → written to `kusion_spec.yaml`

---

## 8. Worked Example: Adding a New Microservice

I want to add a `video-transcoder` service:

**Step 1 — Create the module:**
```
modules/appops/video_transcoder/video_transcoder_module_def.k
```

```kcl
import framework.models.modules.component
import k8s.api.apps.v1 as apps
import k8s.api.core.v1 as core

schema VideoTranscoderModule(component.Component):
    kind = "APPLICATION"
    leaders = [component.ComponentLeader {
        name = name
        kind = "Deployment"
        apiVersion = "apps/v1"
        namespace = namespace
    }]
    manifests = [
        apps.Deployment {
            metadata = { name = name, namespace = namespace }
            spec = {
                replicas = 1
                selector.matchLabels = { app = name }
                template = {
                    metadata.labels = { app = name }
                    spec.containers = [{
                        name = name
                        image = "${asset.image}:${asset.version}"
                        ports = [{ containerPort = 8080 }]
                    }]
                }
            }
        }
        core.Service {
            metadata = { name = name, namespace = namespace }
            spec = {
                selector = { app = name }
                ports = [{ port = 8080, targetPort = 8080 }]
            }
        }
    ]
```

**Step 2 — Add to stack:**
In `stacks/development/stack_def.k`, add:
```kcl
import video_streaming.modules.appops.video_transcoder as transcoder

# In the stack schema:
components = [_video_collector_mongodb_python, _video_transcoder]

_video_transcoder = transcoder.VideoTranscoderModule {
    name = "video-transcoder"
    namespace = _apps_namespace.name
    asset = { image = "myregistry/video-transcoder", version = "1.0.0" }
    configurations = instanceConfigurations
    dependsOn = [_apps_namespace]
}.instance
```

**Step 3 — The rest is automatic.** The factory merges configs, the stack now includes the new module, and all output procedures pick it up.

---

## 9. Worked Example: Adding a New Customer (Tenant)

I want to onboard "France" as a customer:

**Step 1 — Create tenant directory:**
```
tenants/france/
├── tenant_def.k
└── france_configurations.k
```

**Step 2 — Define tenant:**
```kcl
# tenant_def.k
import framework.models.tenant
import video_streaming.tenants.france.france_configurations

tenant_france = tenant.Tenant {
    name = "France"
    description = "Government of France"
    configurations = france_configurations._france_tenant_configurations
}
```

```kcl
# france_configurations.k
import video_streaming.core_sources.video_streaming_configurations

_france_tenant_configurations = video_streaming_configurations.VideoStreamingConfigurations {
    brandIcon = "🇫🇷"
}
```

**Step 3 — Create a site for France:**
```
sites/tenants/production/paris/
├── site_def.k
└── configurations.k
```

```kcl
# site_def.k
import framework.models.site
import video_streaming.tenants.france

paris_site = site.Site {
    name = "Paris"
    tenant = france.tenant_france
    configurations = _paris_site_configurations
}
```

**Step 4 — Create a release:** Copy an existing release factory and update imports to reference France tenant and Paris site.

---

## 10. Worked Example: Adding a New Environment (Site)

I want to add a "staging Berlin" environment for Germany:

```
sites/tenants/staging/berlin/
├── site_def.k
└── configurations.k
```

```kcl
# site_def.k
import framework.models.site
import video_streaming.tenants.germany

staging_berlin_site = site.Site {
    name = "staging-berlin"
    tenant = germany.tenant_germany
    configurations = _staging_berlin_configurations
}
```

```kcl
# configurations.k
_staging_berlin_configurations = VideoStreamingConfigurations {
    siteName = "Berlin Staging"
    rootPaths = {
        "local opensearch": "http://staging-opensearch.opensearch"
    }
}
```

---

## 11. Worked Example: erp_back — A Complete Project Using Framework Templates

The `erp_back` project demonstrates the **recommended approach** for new projects: using framework templates, builders, and assembly helpers to minimize boilerplate.

### Project Overview

| Aspect | Details |
|---|---|
| **Name** | ERP Back |
| **Components** | `erp-api` (Spring Boot REST API) |
| **Accessories** | `erp-postgres` (PostgreSQL database) |
| **Namespaces** | `erp-apps`, `erp-postgres` |
| **Templates used** | `WebAppModule`, `SingleDatabaseModule` |
| **Output formats** | Plain YAML, ArgoCD Application |

### Line Count Comparison

| Approach | Module Code | Stack Code | Total (module + stack) |
|---|---|---|---|
| Raw manifests (video_streaming style) | ~190 lines per module | ~60 lines | ~250+ lines |
| Templates (erp_back style) | ~50 lines per module | ~25 lines | ~75 lines |
| **Reduction** | **~74%** | **~58%** | **~70%** |

### Module Definition — `erp_api_module_def.k`

The ERP API module uses `WebAppModule` with Spring Boot probes and environment variables:

```kcl
import framework.templates.webapp as webapp
import framework.builders.deployment as deploy

schema ErpApiModule(webapp.WebAppModule):
    port = 8080
    serviceType = "ClusterIP"
    configData = {
        "application.yaml" = "server.port: 8080\nspring.profiles.active: ${configurations.springProfile}"
    }
    resources = deploy.ResourceSpec { cpuLimit = "2", memoryLimit = "4Gi" }
    livenessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health/liveness"
        port = 8080
    }
    readinessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health/readiness"
        port = 8080
    }
    env = [
        { name = "SPRING_DATASOURCE_URL"
          value = "jdbc:postgresql://${configurations.postgresHost}:${configurations.postgresPort}/${configurations.postgresDatabase}" }
        { name = "SPRING_DATASOURCE_USERNAME"
          valueFrom.secretKeyRef = { name = "postgres-credentials", key = "username" } }
        # ... more env vars
    ]
```

Compared to the video_streaming approach (which writes raw `apps.Deployment`, `core.Service`, etc. manually), this is ~50 lines instead of ~190.

### Module Definition — `postgres_module_def.k`

```kcl
import framework.templates.database as database
import framework.builders.deployment as deploy

schema PostgresModule(database.SingleDatabaseModule):
    port = 5432
    dataPath = "/var/lib/postgresql/data"
    storageSize = "20Gi"
    resources = deploy.ResourceSpec { cpuLimit = "1", memoryLimit = "2Gi" }
    env = [
        { name = "POSTGRES_DB", value = configurations.postgresDatabase }
        { name = "POSTGRES_USER"
          valueFrom.secretKeyRef = { name = "postgres-credentials", key = "username" } }
        { name = "POSTGRES_PASSWORD"
          valueFrom.secretKeyRef = { name = "postgres-credentials", key = "password" } }
    ]
```

### Stack Definition — Using Assembly Helpers

```kcl
import framework.models.stack
import framework.assembly.helpers as asm

schema ErpBackDevelopmentStack(stack.Stack):
    _erp_apps_namespace = asm.create_namespace(
        instanceConfigurations.appsNamespace, instanceConfigurations
    )
    _erp_postgres_namespace = asm.create_namespace(
        instanceConfigurations.postgresNamespace, instanceConfigurations
    )
    k8snamespaces = [_erp_apps_namespace, _erp_postgres_namespace]

    components = [
        ErpApiModule {
            name = "erp-api"
            namespace = _erp_apps_namespace.name
            asset = { image = "myregistry/erp-api", version = "1.0.0" }
            configurations = instanceConfigurations
            dependsOn = [_erp_apps_namespace]
        }.instance
    ]

    accessories = [
        PostgresModule {
            name = "erp-postgres"
            namespace = _erp_postgres_namespace.name
            asset = { image = "postgres", version = "16-alpine" }
            configurations = instanceConfigurations
            dependsOn = [_erp_postgres_namespace]
        }.instance
    ]
```

### Configuration Schema — Extending BaseConfigurations

```kcl
import framework.models.configurations as base

schema ErpBackConfigurations(base.BaseConfigurations):
    postgresNamespace?: str
    postgresHost?: str = "erp-postgres.erp-postgres.svc.cluster.local"
    postgresPort?: str = "5432"
    postgresDatabase?: str = "erpdb"
    springProfile?: str = "dev"
    javaOpts?: str = "-Xms512m -Xmx2g"
```

### KCL Module Resolution Pattern

The `pre_releases/kcl.mod` depends on `erp_back` only — NOT directly on `framework`:

```toml
[package]
name = "pre_releases"

[dependencies]
erp_back = { path = "../" }
```

The `framework` dependency resolves **transitively** through `erp_back`'s own `kcl.mod`. This is the correct pattern. Declaring `framework` directly in `pre_releases/kcl.mod` causes path resolution errors.

---

## 12. Migration Guide: Raw Manifests → Templates

If you have existing modules written with raw K8s manifests (like `video_streaming`) and want to adopt the new template approach, follow these steps.

### When to Migrate

Migrate when:
- You're creating a **new** module — use templates from the start
- An existing module is a **standard pattern** (web app, database, Kafka) with no exotic customization
- You want to **reduce maintenance** — template updates propagate to all modules

Don't migrate when:
- Your module uses **custom sidecars**, **init containers**, or **complex volume setups** not covered by templates
- You need **fine-grained control** over the manifest structure

### Migration Steps

**Step 1 — Identify your module type:**
| If your module has... | Use this template |
|---|---|
| Deployment + Service + ConfigMap + ServiceAccount | `WebAppModule` |
| Deployment + Service + PV + PVC (database pattern) | `SingleDatabaseModule` |
| Kafka CRD + KafkaTopic CRDs | `KafkaClusterModule` |

**Step 2 — Map fields:**
| Raw manifest field | Template field |
|---|---|
| `spec.template.spec.containers[0].ports[0].containerPort` | `port` |
| `spec.replicas` | `replicas` |
| `spec.template.spec.containers[0].resources` | `resources = deploy.ResourceSpec { ... }` |
| `spec.template.spec.containers[0].livenessProbe` | `livenessProbe = deploy.ProbeSpec { ... }` |
| `spec.template.spec.containers[0].env` | `env = [...]` |
| ConfigMap data | `configData = { ... }` |
| `spec.type` (Service) | `serviceType` |

**Step 3 — Replace the schema body:**

Before (raw):
```kcl
schema MyModule(component.Component):
    kind = "APPLICATION"
    leaders = [component.ComponentLeader { ... }]
    manifests = [
        apps.Deployment { ... }     # 60+ lines
        core.Service { ... }         # 15+ lines
        core.ConfigMap { ... }       # 10+ lines
        core.ServiceAccount { ... }  # 10+ lines
    ]
```

After (template):
```kcl
schema MyModule(webapp.WebAppModule):
    port = 8080
    serviceType = "ClusterIP"
    resources = deploy.ResourceSpec { cpuLimit = "2", memoryLimit = "4Gi" }
    env = [...]
```

**Step 4 — Update stack references.** The module's `.instance` interface is unchanged — no stack modifications needed.

**Step 5 — Test.** Run `kcl run` on your factory and compare the output YAML. The manifests should be equivalent.

---

## 13. Common Patterns & Conventions

### Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Module file | `<name>_module_def.k` | `video_collector_mongodb_python_module_def.k` |
| Stack file | `stack_def.k` | `stacks/development/stack_def.k` |
| Profile file | `profile_def.k` | `stacks/development/profile_def.k` |
| Tenant file | `tenant_def.k` | `tenants/germany/tenant_def.k` |
| Site file | `site_def.k` | `sites/development/dev_cluster/site_def.k` |
| Config file | `configurations.k` or `*_configurations.k` | `germany_configurations.k` |
| Factory seed | `factory_seed.k` | `factory/factory_seed.k` |
| Builder file | `*_builder.k` | `kubernetes_manifests_builder.k` |
| Private variables | `_prefix` | `_apps_namespace`, `_stack` |

### The `.instance` Pattern

Always access `.instance` when passing data downstream, never the schema directly:

```kcl
# ✅ Correct
_my_namespace = k8snamespace.K8sNamespace { name = "apps", ... }.instance
components = [module.MyModule { ..., dependsOn = [_my_namespace] }.instance]

# ❌ Wrong
_my_namespace = k8snamespace.K8sNamespace { name = "apps", ... }
```

### Dependency Ordering via `dependsOn`

Modules declare which other modules must exist before them:

```kcl
# Namespace has no dependencies
_apps_ns = K8sNamespace { name = "apps" }.instance

# Application depends on its namespace
_my_app = MyModule { dependsOn = [_apps_ns] }.instance

# MongoDB depends on namespace AND its persistence volume
_mongodb = MongoDBModule { dependsOn = [_mongodb_ns, _mongodb_pv] }.instance
```

The `dependsOn` chain is resolved by Kusion (generates `dependsOn` in spec) and used for deployment ordering in other formats.

### Configuration Flow Through Stacks

The merged configuration flows through `instanceConfigurations`:

```kcl
# In factory_seed.k:
_stack = MyStack { instanceConfigurations = mergedConfig }

# In stack_def.k — modules read from it:
_apps_namespace = K8sNamespace {
    name = instanceConfigurations.appsNamespace    # ← from merged config
    configurations = instanceConfigurations
}.instance
```

---

## 14. Troubleshooting & FAQ

### Q: My module doesn't appear in the output

Check that the module's `.instance` is added to the stack's `components` or `accessories` list. The stack schema must include it in the appropriate array.

### Q: Configuration values from tenant/site aren't taking effect

Verify the merge order: kernel → profile → tenant → site. Later layers override earlier ones. Check that your configuration file creates a `VideoStreamingConfigurations` instance with the correct field names.

### Q: What's the difference between Component and Accessory?

- **Component**: Application workloads that your team develops (Deployments, Services). Kind = `"APPLICATION"` or `"INFRASTRUCTURE"`.
- **Accessory**: Supporting infrastructure resources, often CRDs from operators. Kind = `"CRD"` or `"SECRET"`.

The distinction matters for output procedures — some formats handle them differently.

### Q: Why do I need both a Stack and a Profile?

- **Profile** = HOW to deploy (configuration values for a lifecycle stage or version)
- **Stack** = WHAT to deploy (which modules and their wiring)

A Profile provides configuration values. A Stack uses those values to instantiate modules. They work together: the Profile flows into the Stack via `instanceConfigurations`.

### Q: How do I add a completely new output format?

1. Create `framework/procedures/kcl_to_<format>.k` with a conversion lambda
2. (Optional) Create `framework/custom/<format>/` with format-specific schemas
3. Add a `<format>_builder.k` to the factory
4. Add a render target to `platform_cli/koncept`

### Q: Why is there a GitOpsStack AND a Stack?

- **Stack** is the standard assembly (all fields required, used by Helm and Kusion outputs)
- **GitOpsStack** is a variant where all module lists are optional (used by the YAML/ArgoCD output where you might only deploy a subset)

The GitOps pattern often needs to deploy individual components separately (one ArgoCD Application per component), so GitOpsStack allows filtering to just the modules you want.

### Q: Can I read configuration from external YAML files?

Yes. Use KCL's `yaml.decode(file.read("config.yaml"))` to read adjacent YAML files. This is used in Berlin production's site configuration for values managed outside KCL.

### Q: My pre_releases can't find the framework package

If you get import errors like `cannot find the framework module` when running KCL from a pre_releases directory, check your `pre_releases/kcl.mod`:

- **Correct:** Depend only on the parent project (e.g., `erp_back = { path = "../" }`). The framework resolves transitively.
- **Wrong:** Adding `framework = { path = "../../../framework" }` directly. This often causes path resolution errors.

### Q: When should I use templates vs raw manifests?

- **New projects:** Always use templates (`WebAppModule`, `SingleDatabaseModule`, `KafkaClusterModule`)
- **Existing projects:** Keep raw manifests if they work; migrate when you need to modify them
- **Custom patterns:** Use raw builders (`build_deployment`, `build_service`, etc.) for control without full templates
- **Exotic resources:** Write raw K8s manifests directly when no builder/template matches

---

## Next Steps

- Read [PROJECT_ARCHITECTURE.md](PROJECT_ARCHITECTURE.md) for the full technical reference with schema field details
- Read [FRAMEWORK_SCHEMAS.md](FRAMEWORK_SCHEMAS.md) for complete schema field documentation
- Read [DEVELOPMENT_WORKFLOWS.md](DEVELOPMENT_WORKFLOWS.md) for step-by-step CLI guides
- Read [KCL_REFERENCE.md](KCL_REFERENCE.md) for KCL language patterns used in this project
- Read [AI_REFERENCE.md](AI_REFERENCE.md) for a concise, structured reference optimized for AI coding assistants
