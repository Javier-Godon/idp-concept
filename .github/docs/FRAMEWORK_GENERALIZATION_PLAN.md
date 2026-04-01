# Framework Generalization Plan — Reducing Project Complexity

> **Status:** ✅ **IMPLEMENTED** — All 5 phases have been completed and validated. See the implementation in `framework/builders/`, `framework/templates/`, `framework/assembly/`, `framework/factory/`, and `framework/models/configurations.k`. The `erp_back` project demonstrates the new approach. The `video_streaming` project remains backward-compatible with no changes needed.

> **Problem:** Creating a concrete project like `video_streaming` requires deep KCL expertise — you must manually write full Deployment specs, probe configurations, volume mounts, leader patterns, and repetitive boilerplate. Most of this follows predictable patterns that can be extracted into the framework.
>
> **Goal:** Move repeated patterns, builders, and abstractions into the framework so project authors write **high-level declarations** instead of raw Kubernetes manifests.

---

## Table of Contents

1. [Current Pain Points — What's Hard Today](#1-current-pain-points)
2. [Proposed Architecture — Three Levels of Abstraction](#2-proposed-architecture)
3. [Phase 1 — Manifest Builders (High Impact, Low Risk)](#3-phase-1--manifest-builders)
4. [Phase 2 — Module Templates (Medium Complexity)](#4-phase-2--module-templates)
5. [Phase 3 — Declarative Stack Assembly (High Abstraction)](#5-phase-3--declarative-stack-assembly)
6. [Phase 4 — Configuration Contract Generalization](#6-phase-4--configuration-contract-generalization)
7. [Phase 5 — Factory Scaffolding](#7-phase-5--factory-scaffolding)
8. [Migration Strategy](#8-migration-strategy)
9. [What a Project Would Look Like After](#9-what-a-project-would-look-like-after)

---

## 1. Current Pain Points

Let's look at what a project author has to do today and identify the problematic patterns:

### Pain 1: Raw Kubernetes Manifests in Modules (190+ lines of boilerplate)

To define a simple web application (`VideoCollectorMongodbPythonModule`), you write ~190 lines of raw K8s objects:
- Full `apps.Deployment` with `spec.template.spec.containers`, probes, resources, volumeMounts
- Full `core.ConfigMap` with inline data
- Full `core.Service` with ports, selector, type
- Full `core.ServiceAccount` with imagePullSecrets

**The problem:** 80% of this is boilerplate that's identical across modules. Every Deployment needs metadata, selector/labels matching, a container with image and name, resource limits. Every Service needs the same selector pattern. Every ServiceAccount follows the same shape.

### Pain 2: Repeated Leader Pattern

Every module manually constructs the leader:
```kcl
leaders = [component.ComponentLeader {
    name = name
    kind = "Deployment"
    apiVersion = "apps/v1"
    namespace = namespace
}]
```

This is the same pattern in every module — only `kind` and `apiVersion` change.

### Pain 3: No Default Probes, Resources, or Scaling

Each module defines its own liveness/readiness/startup probes with hardcoded values. There's no shared "sensible defaults" — every new module must copy-paste probe configurations.

### Pain 4: Stack Definitions Are Repetitive

The development and v1_0_0 stacks are nearly identical — same structure, same namespace/component/accessory wiring. Only versions and names change.

### Pain 5: Factory Seed Is Always the Same Pattern

Every `factory_seed.k` follows the exact same pattern:
1. Import project, profile, tenant, site
2. Call `merge_configurations()`
3. Instantiate stack with merged config
4. Create Release

This pattern is repeated word-for-word in every release.

### Pain 6: Configuration Schema Per Project

Each project defines its own `VideoStreamingConfigurations` schema and `merge_configurations` lambda. The structure is always the same: optional fields with a merge function using `|`.

---

## 2. Proposed Architecture — Three Levels of Abstraction

```
Level 3 (Project Author):   "Deploy a Python app on port 8002 with Kafka and MongoDB"
                                          │
Level 2 (Module Templates):  WebApp { port = 8002 }, KafkaCluster { topics = [...] }
                                          │
Level 1 (Manifest Builders): deployment(), service(), configmap(), probe_defaults()
                                          │
Level 0 (Current):           Raw k8s.api.apps.v1.Deployment { ... 80 lines ... }
```

Each level builds on the one below. Project authors choose their level of abstraction:
- **Level 0** (current): Full control, write raw manifests
- **Level 1**: Use builder functions for common K8s objects
- **Level 2**: Use pre-built module templates for common patterns
- **Level 3**: Declarative configuration — just describe intent

**Implementation is backwards-compatible** — existing modules keep working, new code can opt into higher abstractions.

---

## 3. Phase 1 — Manifest Builders (High Impact, Low Risk)

**Location:** `framework/builders/` (new directory)

Extract common K8s manifest patterns into reusable builder functions.

### 3.1 Deployment Builder

```kcl
# framework/builders/deployment.k
import k8s.api.apps.v1 as apps
import k8s.api.core.v1 as core

schema DeploymentSpec:
    """High-level deployment specification"""
    name: str
    namespace: str
    image: str
    version: str
    replicas?: int = 1
    port?: int
    command?: [str]
    env?: [{str:any}]
    configMapRef?: str                     # Mount a ConfigMap as application.yaml
    configMountPath?: str = "/config"
    resources?: ResourceSpec
    probes?: ProbeSpec
    serviceAccountName?: str
    imagePullPolicy?: str = "IfNotPresent"
    volumes?: [any]
    volumeMounts?: [any]

schema ResourceSpec:
    """CPU/memory resource specification"""
    cpuRequest?: str = "250m"
    cpuLimit?: str = "1"
    memoryRequest?: str = "512Mi"
    memoryLimit?: str = "2Gi"
    ephemeralStorage?: str

schema ProbeSpec:
    """Health probe specification"""
    type?: str = "exec"                    # "exec", "http", "tcp"
    path?: str                             # For HTTP probes
    port?: int                             # For HTTP/TCP probes
    command?: [str]                        # For exec probes
    initialDelaySeconds?: int = 30
    periodSeconds?: int = 5
    failureThreshold?: int = 3
    timeoutSeconds?: int = 10

# Builder function
build_deployment = lambda spec: DeploymentSpec -> apps.Deployment {
    apps.Deployment {
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            replicas = spec.replicas
            selector.matchLabels = { app = spec.name }
            template = {
                metadata.labels = { app = spec.name }
                spec = {
                    containers = [{
                        name = spec.name
                        image = "${spec.image}:${spec.version}"
                        imagePullPolicy = spec.imagePullPolicy
                        ports = [{ containerPort = spec.port }] if spec.port else []
                        env = spec.env if spec.env else Undefined
                        resources = _build_resources(spec.resources) if spec.resources else Undefined
                        livenessProbe = _build_probe(spec.probes) if spec.probes else Undefined
                        readinessProbe = _build_probe(spec.probes) if spec.probes else Undefined
                        startupProbe = _build_probe(spec.probes) if spec.probes else Undefined
                        volumeMounts = spec.volumeMounts if spec.volumeMounts else Undefined
                    }]
                    serviceAccountName = spec.serviceAccountName if spec.serviceAccountName else Undefined
                    volumes = spec.volumes if spec.volumes else Undefined
                }
            }
        }
    }
}
```

### 3.2 Service Builder

```kcl
# framework/builders/service.k

schema ServiceSpec:
    name: str
    namespace: str
    port: int
    targetPort?: int
    nodePort?: int
    type?: str = "ClusterIP"             # ClusterIP, NodePort, LoadBalancer

build_service = lambda spec: ServiceSpec -> core.Service {
    core.Service {
        metadata = { name = spec.name, namespace = spec.namespace }
        spec = {
            selector = { app = spec.name }
            ports = [{
                port = spec.port
                targetPort = spec.targetPort or spec.port
                nodePort = spec.nodePort if spec.nodePort else Undefined
            }]
            $type = spec.type
        }
    }
}
```

### 3.3 ConfigMap Builder

```kcl
# framework/builders/configmap.k

schema ConfigMapSpec:
    name: str
    namespace: str
    data: {str:str}

build_configmap = lambda spec: ConfigMapSpec -> core.ConfigMap {
    core.ConfigMap {
        metadata = { name = spec.name, namespace = spec.namespace }
        data = spec.data
    }
}
```

### 3.4 PV/PVC Builder

```kcl
# framework/builders/storage.k

schema PersistentVolumeSpec:
    name: str
    namespace: str
    size?: str = "20Gi"
    storageClass?: str
    accessMode?: str = "ReadWriteOnce"
    reclaimPolicy?: str = "Retain"
    hostPath?: str

build_pv_and_pvc = lambda spec: PersistentVolumeSpec -> [any] {
    [
        { apiVersion = "v1", kind = "PersistentVolume", ... }
        { apiVersion = "v1", kind = "PersistentVolumeClaim", ... }
    ]
}
```

### 3.5 Leader Builder

```kcl
# framework/builders/leader.k

build_component_leader = lambda name: str, kind: str = "Deployment", apiVersion: str = "apps/v1", namespace: str = "" -> component.ComponentLeader {
    component.ComponentLeader { name, kind, apiVersion, namespace }
}

build_accessory_leader = lambda name: str, kind: str, apiVersion: str, namespace: str = "" -> accessory.AccessoryLeader {
    accessory.AccessoryLeader { name, kind, apiVersion, namespace }
}
```

### What This Gives Us

The VideoCollector module drops from ~190 lines to ~40 lines:

```kcl
# BEFORE (190 lines)
schema VideoCollectorMongodbPythonModule(component.Component):
    kind = "APPLICATION"
    leaders = [component.ComponentLeader { name, kind = "Deployment", ... }]
    manifests = [
        apps.Deployment { ... 80 lines ... }
        core.ConfigMap { ... 20 lines ... }
        core.Service { ... 15 lines ... }
        core.ServiceAccount { ... 10 lines ... }
    ]

# AFTER (~40 lines)
schema VideoCollectorMongodbPythonModule(component.Component):
    kind = "APPLICATION"
    leaders = [builders.build_component_leader(name, namespace=namespace)]
    manifests = [
        builders.build_deployment(builders.DeploymentSpec {
            name, namespace
            image = asset.image, version = asset.version
            port = 8002
            configMapRef = "${name}-configmap"
            resources = builders.ResourceSpec { cpuLimit = "1", memoryLimit = "2Gi" }
            probes = builders.ProbeSpec { type = "exec", command = ["/bin/sh", "-c", "echo ok"] }
        })
        builders.build_configmap(builders.ConfigMapSpec {
            name = "${name}-configmap", namespace
            data = { "application.yaml" = _app_config }
        })
        builders.build_service(builders.ServiceSpec { name, namespace, port = 8002, nodePort = 31021, type = "NodePort" })
    ]
```

---

## 4. Phase 2 — Module Templates (Medium Complexity)

**Location:** `framework/templates/` (new directory)

Pre-built module schemas for common patterns that projects can inherit and customize.

### 4.1 WebAppModule Template

The most common pattern: Deployment + Service + ConfigMap + optional ServiceAccount.

```kcl
# framework/templates/webapp.k

schema WebAppModule(component.Component):
    """Pre-built web application module.
    
    Generates: Deployment + Service + ConfigMap (optional) + ServiceAccount (optional)
    """
    kind = "APPLICATION"
    
    # User-configurable fields
    port: int
    serviceType?: str = "ClusterIP"
    nodePort?: int
    replicas?: int = 1
    configData?: {str:str}                  # If provided, creates a ConfigMap
    configMountPath?: str = "/config"
    imagePullSecretName?: str               # If provided, creates a ServiceAccount
    env?: [{str:any}]
    resources?: builders.ResourceSpec
    probes?: builders.ProbeSpec
    
    # Auto-computed
    leaders = [builders.build_component_leader(name, namespace=namespace)]
    manifests = _build_manifests()
    
    _build_manifests = lambda -> [any] {
        _result = [
            builders.build_deployment(builders.DeploymentSpec {
                name, namespace
                image = asset.image, version = asset.version
                replicas, port, env, resources, probes
                configMapRef = "${name}-configmap" if configData else Undefined
                configMountPath = configMountPath
                serviceAccountName = "${name}-sa" if imagePullSecretName else Undefined
            })
            builders.build_service(builders.ServiceSpec {
                name, namespace, port
                type = serviceType
                nodePort = nodePort if nodePort else Undefined
            })
        ]
        if configData:
            _result += [builders.build_configmap({name = "${name}-configmap", namespace, data = configData})]
        if imagePullSecretName:
            _result += [_build_service_account()]
        _result
    }
```

### 4.2 SingleDatabaseModule Template

Pattern for standalone database deployments (MongoDB, PostgreSQL, Redis):

```kcl
# framework/templates/database.k

schema SingleDatabaseModule(accessory.Accessory):
    """Pre-built single-instance database module.
    
    Generates: Deployment + Service + PV/PVC
    """
    kind = "CRD"
    
    # User-configurable
    port: int
    dataPath?: str = "/data"
    storageSize?: str = "20Gi"
    serviceType?: str = "ClusterIP"
    nodePort?: int
    env?: [{str:any}]
    resources?: builders.ResourceSpec
    
    # Auto-computed
    leaders = [builders.build_accessory_leader(name, "Deployment", "apps/v1", namespace)]
    manifests = [
        builders.build_deployment(...)
        builders.build_service(...)
        builders.build_pv_and_pvc(...)
    ]
```

### 4.3 KafkaClusterModule Template

```kcl
# framework/templates/kafka.k

schema KafkaClusterModule(accessory.Accessory):
    """Pre-built Strimzi Kafka cluster module."""
    kind = "CRD"
    
    clusterName: str
    kafkaVersion?: str = "3.8.0"
    replicas?: int = 1
    topics?: [KafkaTopicSpec]
    storage?: str = "100Gi"
    
    leaders = [builders.build_accessory_leader(clusterName, "Kafka", "kafka.strimzi.io/v1beta2", namespace)]
    manifests = _build_kafka_manifests()
```

### What This Gives Us

The VideoCollector definition becomes trivial:

```kcl
# BEFORE: 190 lines defining raw Deployment, Service, ConfigMap, ServiceAccount
# AFTER: 20 lines of high-level intent

import framework.templates.webapp

schema VideoCollectorMongodbPythonModule(webapp.WebAppModule):
    port = 8002
    serviceType = "NodePort"
    nodePort = 31021
    imagePullSecretName = "pull-image-from-github-registry-secret"
    resources = builders.ResourceSpec { cpuLimit = "1", memoryLimit = "2Gi" }
    probes = builders.ProbeSpec { type = "exec", command = ["/bin/sh", "-c", "echo ok"] }
    configData = {
        "application.yaml" = _app_config_yaml
    }
```

---

## 5. Phase 3 — Declarative Stack Assembly (High Abstraction)

**Location:** `framework/assembly/` (new directory)

Extract the repetitive stack wiring pattern into a higher-level assembly schema.

### The Problem

Every stack definition repeats the same pattern:
```kcl
_apps_namespace = k8snamespace.K8sNamespace { name = instanceConfigurations.appsNamespace, configurations = instanceConfigurations }.instance
_my_module = MyModule { name = "...", namespace = _apps_namespace.name, asset = {...}, configurations = instanceConfigurations, dependsOn = [_apps_namespace] }.instance
```

This boilerplate of `.instance`, `configurations = instanceConfigurations`, and `dependsOn = [_namespace]` is repeated for every single module.

### Proposed: StackAssembler

```kcl
# framework/assembly/assembler.k

schema NamespaceBinding:
    """Bind a namespace name to a config field"""
    configField: str                       # e.g., "appsNamespace"
    fallback?: str                         # Fixed name if not in config

schema ModuleBinding:
    """Bind a module to a namespace"""
    module: any                            # The module schema type
    namespaceName: str                     # Which namespace this belongs to
    name: str
    asset: any
    extraConfig?: any                      # Module-specific additional config

assemble_stack = lambda bindings: {
    namespaces: [NamespaceBinding]
    components: [ModuleBinding]
    accessories: [ModuleBinding]
    configurations: any
} -> stack.StackInstance {
    # Auto-creates namespaces from config
    # Auto-instantiates modules with .instance
    # Auto-wires dependsOn to namespace instances
    # Auto-passes configurations = instanceConfigurations
    ...
}
```

### What a Stack Would Look Like

```kcl
# BEFORE: 90 lines of manual wiring
schema VideoStreamingDevelopmentStack(stack.Stack):
    _apps_namespace = k8snamespace.K8sNamespace { name = instanceConfigurations.appsNamespace, configurations = instanceConfigurations }.instance
    _postgres_namespace = k8snamespace.K8sNamespace { name = instanceConfigurations.postgresNamespace, configurations = instanceConfigurations }.instance
    # ... 5 more namespace definitions
    # ... 5 more module definitions with dependsOn, .instance, configurations

# AFTER: 25 lines of declarative intent
schema VideoStreamingDevelopmentStack(stack.Stack):
    _assembly = assembler.assemble_stack({
        configurations = instanceConfigurations
        namespaces = [
            { configField = "appsNamespace" }
            { configField = "postgresNamespace" }
            { configField = "certmanagerNamespace" }
            { fallback = "kafka" }
            { fallback = "mongodb" }
        ]
        components = [
            { module = video_collector.VideoCollectorMongodbPythonModule
              name = "kafka_video_consumer_mongodb_python"
              namespaceName = "appsNamespace"
              asset = { image = "ghcr.io/...", version = "3b7436a-..." } }
        ]
        accessories = [
            { module = kafka.KafkaSingleInstanceModule
              name = "kafka", namespaceName = "kafka"
              asset = { image = "strimzi", version = "0.45.0" } }
            { module = mongodb.MongoDBSingleInstanceModule
              name = "blue-mongo-db", namespaceName = "mongodb"
              asset = { image = "mongo@sha256", version = "cc62..." } }
        ]
    })
    k8snamespaces = _assembly.k8snamespaces
    components = _assembly.components
    accessories = _assembly.accessories
```

---

## 6. Phase 4 — Configuration Contract Generalization

**Location:** `framework/models/configurations.k` (new file)

### The Problem

Every project defines its own `XyzConfigurations` schema and `merge_configurations` lambda. The merge function is always identical — only the schema type changes.

### Proposed: BaseConfigurations + Generic Merge

```kcl
# framework/models/configurations.k

schema BaseConfigurations:
    """Common configuration fields shared across all projects"""
    projectName?: str
    siteName?: str
    brandIcon?: str
    
    # Common namespace patterns
    appsNamespace?: str
    
    # Common integration endpoints
    rootPaths?: {str:str}

# The merge function works with any schema that extends BaseConfigurations
merge = lambda T: any, kernel: T, profile: T, tenant: T, site: T -> T {
    _configs: T = kernel
    _configs: T = _configs | profile
    _configs: T = _configs | tenant
    _configs: T = _configs | site
}
```

Projects extend `BaseConfigurations` with project-specific fields:
```kcl
# BEFORE: Define full schema + merge function from scratch (25 lines)
# AFTER: Extend base (8 lines)

import framework.models.configurations as base

schema VideoStreamingConfigurations(base.BaseConfigurations):
    """Project-specific fields only"""
    postgresNamespace?: str
    certmanagerNamespace?: str
    apacheKafkaNamespace?: str
    mongodbNamespace?: str
```

And the merge function doesn't need to be redefined at all — use the framework's `base.merge()`.

---

## 7. Phase 5 — Factory Scaffolding

**Location:** `framework/factory/` (new directory)

### The Problem

Every `factory_seed.k` follows the identical pattern — import 4 layers, merge, instantiate stack, create release. Every builder file follows the same one-liner pattern.

### Proposed: FactorySeed Schema

```kcl
# framework/factory/seed.k

schema FactorySeed:
    """Standard factory setup — merges 4 config layers and creates a release."""
    releaseName: str
    version: str
    project: project.Project
    profile: profile.Profile
    tenant: tenant.Tenant
    site: site.Site
    stackType: any                          # The stack schema to instantiate
    mergeFunc: any                          # The merge_configurations lambda
    
    # Auto-computed
    _mergedConfig = mergeFunc(
        project.configurations,
        profile.configurations,
        tenant.configurations,
        site.configurations
    )
    
    stack = stackType { instanceConfigurations = _mergedConfig }
    
    release = release.Release {
        name = releaseName
        version = version
        project = project.instance
        tenant = tenant.instance
        site = site.instance
        profile = profile.instance
        stack = stack
    }
```

A concrete factory_seed.k becomes:
```kcl
# BEFORE: 25 lines of imports and manual wiring
# AFTER: 15 lines

import framework.factory.seed

_factory = seed.FactorySeed {
    releaseName = "release_v1_0_0_berlin"
    version = "1.0.0/berlin"
    project = project_def.video_streaming_project
    profile = profile_def.video_streaming_v1_0_0_base_profile
    tenant = germany.tenant_germany
    site = berlin.berlin_site
    stackType = stack_def.VideoStreamingv1_0_0_BaseStack
    mergeFunc = merge.merge_configurations
}
```

---

## 8. Migration Strategy

### Approach: Bottom-Up, Non-Breaking

1. **Phase 1 (Builders)** — Add `framework/builders/`. New modules can use them; existing modules keep working. **No breaking changes.**

2. **Phase 2 (Templates)** — Add `framework/templates/`. New module types can inherit from templates. Existing modules unchanged. **No breaking changes.**

3. **Phase 3 (Assembly)** — Add `framework/assembly/`. New stacks can use the assembler; existing stacks unchanged. **No breaking changes.**

4. **Phase 4 (Config Generalization)** — Add `framework/models/configurations.k`. Projects can opt-in to extend `BaseConfigurations`. **No breaking changes.**

5. **Phase 5 (Factory Scaffolding)** — Add `framework/factory/`. New releases can use `FactorySeed`; existing factories unchanged. **No breaking changes.**

### Priority Order

| Phase | Impact | Complexity | Do First? |
|---|---|---|---|
| Phase 1 (Builders) | **High** — eliminates 70% of manifest boilerplate | **Low** — pure helper functions | **Yes** |
| Phase 2 (Templates) | **High** — pre-built module patterns | **Medium** — needs careful schema design | **Yes** |
| Phase 4 (Config) | **Medium** — less repeated code | **Low** — simple base schema | **Yes** |
| Phase 5 (Factory) | **Medium** — less factory boilerplate | **Low** — wrapper schema | **After Phase 4** |
| Phase 3 (Assembly) | **Medium** — simpler stack definitions | **High** — complex lambda + dynamic typing | **Last** |

---

## 9. What a Project Would Look Like After

### Today (Deep KCL Knowledge Required)

To define a new project deploying a web app with a database:
- Write `core_sources/configurations.k` — define all fields (~15 lines)
- Write `core_sources/merge_configurations.k` — merge lambda (~8 lines)
- Write `kernel/configurations.k` — seed defaults (~5 lines)
- Write `kernel/project_def.k` — project identity (~8 lines)
- Write `modules/appops/myapp/myapp_module_def.k` — **190 lines of raw K8s manifests**
- Write `modules/infrastructure/mydb/mydb_module_def.k` — **120 lines of raw K8s manifests**
- Write `stacks/development/stack_def.k` — **90 lines of namespace/module wiring**
- Write `stacks/development/profile_def.k` — profile (~10 lines)
- Write `tenants/customer/tenant_def.k` — tenant (~8 lines)
- Write `sites/production/cluster/site_def.k` — site (~12 lines)
- Write `releases/v1/factory/factory_seed.k` — **25 lines of merge+release wiring**
- Write `releases/v1/factory/kubernetes_manifests_builder.k` — builder (~4 lines)

**Total: ~500 lines, requires understanding Deployment specs, probe configs, volume mounts, leader patterns, instance patterns, merge semantics.**

### After Phases 1-5 (Declarative, Approachable)

- Write `core_sources/configurations.k` — extend BaseConfigurations (~8 lines, inherit merge)
- Write `kernel/` — unchanged (~13 lines)
- Write `modules/appops/myapp/myapp_module_def.k` — **20 lines using WebAppModule template**
- Write `modules/infrastructure/mydb/mydb_module_def.k` — **15 lines using SingleDatabaseModule template**
- Write `stacks/development/stack_def.k` — **25 lines using StackAssembler**
- Write profiles/tenants/sites — unchanged (~30 lines total)
- Write `releases/v1/factory/factory_seed.k` — **15 lines using FactorySeed**
- Write builder — unchanged (~4 lines)

**Total: ~130 lines, requires understanding only high-level concepts (ports, images, namespaces). No raw K8s manifest knowledge needed.**

### Complexity Reduction

| Area | Before | After | Reduction |
|---|---|---|---|
| Module definition (web app) | 190 lines | 20 lines | **~90%** |
| Module definition (database) | 120 lines | 15 lines | **~87%** |
| Stack definition | 90 lines | 25 lines | **~72%** |
| Configuration + merge | 23 lines | 8 lines | **~65%** |
| Factory seed | 25 lines | 15 lines | **~40%** |
| **Total project setup** | **~500 lines** | **~130 lines** | **~74%** |

---

## Technical Notes

### KCL Constraints to Consider

1. **No generics** — KCL doesn't support generics. The merge function and assembler need to work with `any` types and rely on schema validation at instantiation time.

2. **Lambda limitations** — KCL lambdas can't define schemas inside them. Builders must be top-level schemas + lambda functions.

3. **Schema inheritance is single** — A module can only inherit from one base (Component or Accessory). Templates must extend these, not create a parallel hierarchy.

4. **Union operator (`|`) works on schema instances** — The configuration merge relies on this. Ensure all configuration schemas are proper KCL schemas (not dicts).

5. **Conditional manifests** — Builders should use `Undefined` (not `None`) to omit optional fields, which KCL strips from output.

### Testing Strategy

Each phase should include:
1. **Unit tests** — KCL test files comparing builder outputs to expected YAML
2. **Integration test** — Build the video_streaming project using the new framework features and diff against the current output
3. **Regression** — Existing factories must produce identical output before and after migration
