# Framework Schema Reference

> Complete reference of all KCL schemas defined in `framework/`.
> These schemas form the core domain model that all projects import.

---

## 1. Core Domain Models (`framework/models/`)

### Project

**File**: `framework/models/project.k`  
**Purpose**: Defines a deployable project (the top-level entity).

```kcl
schema ProjectInstance:
    name: str                  # Project name (e.g., "Video Streaming")
    description: str           # Human-readable description
    configurations: any        # Project-specific configuration (typed per project)

schema Project:
    instance: ProjectInstance  # Auto-generated flat instance
    name: str
    description: str
    configurations: any
```

### Tenant

**File**: `framework/models/tenant.k`  
**Purpose**: Represents a customer or organization that uses the platform.

```kcl
schema TenantInstance:
    name: str                  # Tenant name (e.g., "Germany")
    description: str           # Description
    configurations: any        # Tenant-specific config overrides

schema Tenant:
    instance: TenantInstance
    name: str
    description: str
    configurations: any
```

### Site

**File**: `framework/models/site.k`  
**Purpose**: Represents a target deployment environment/cluster.

```kcl
schema SiteInstance:
    name: str                  # Site name (e.g., "berlin", "dev_cluster")
    tenant: Tenant             # Which tenant owns this site
    configurations: any        # Site-specific config overrides

schema Site:
    instance: SiteInstance
    name: str
    tenant: Tenant
    configurations: any
```

### Profile

**File**: `framework/models/profile.k`  
**Purpose**: Defines a deployment mode (dev, staging, production version).

```kcl
schema ProfileInstance:
    name: str                  # Profile name (e.g., "development", "v1_0_0")
    configurations: any        # Profile-specific configurations

schema Profile:
    instance: ProfileInstance
    name: str
    configurations: any
```

### Stack

**File**: `framework/models/stack.k`  
**Purpose**: Aggregates all modules (components, accessories, namespaces) for a deployment.

```kcl
schema StackInstance:
    instanceConfigurations: any                    # Merged configurations
    components: [ComponentInstance]                 # Application/infrastructure components
    accessories?: [AccessoryInstance]               # Supporting resources
    k8snamespaces?: [K8sNamespaceInstance]          # Namespaces to create
    thirdParties?: [ThirdParty]                     # External vendor resources

schema Stack:
    instance: StackInstance
    instanceConfigurations: any
    components: [ComponentInstance]
    accessories?: [AccessoryInstance]
    k8snamespaces?: [K8sNamespaceInstance]
    thirdParties?: [ThirdParty]
```

### GitOpsStack

**File**: `framework/models/gitops/gitopsstack.k`  
**Purpose**: Stack variant for GitOps (plain YAML) output — allows optional components.

```kcl
schema GitOpsStackInstance:
    instanceConfigurations: any
    components?: [ComponentInstance]                # Optional (for subset generation)
    accessories?: [AccessoryInstance]
    k8snamespaces?: [K8sNamespaceInstance]
    thirdParties?: [ThirdPartyInstance]

schema GitOpsStack:
    instance: GitOpsStackInstance
    instanceConfigurations: any
    components?: [ComponentInstance]
    accessories?: [AccessoryInstance]
    k8snamespaces?: [K8sNamespaceInstance]
    thirdParties?: [ThirdPartyInstance]
```

### Release

**File**: `framework/models/release.k`  
**Purpose**: Combines all layers into a versioned, deployable artifact.

```kcl
schema Release:
    name: str                              # Release name
    version: str                           # Version string (e.g., "1.0.0/berlin")
    project: ProjectInstance               # Project (flat instance)
    tenant: TenantInstance                 # Tenant (flat instance)
    profile: ProfileInstance               # Profile (flat instance)
    site: SiteInstance                     # Site (flat instance)
    stack: Stack                           # The assembled stack
    kusionSpec: [KusionResource]           # Auto-generated Kusion spec (computed)
```

**Note**: The `kusionSpec` property is computed automatically from the stack using `kcl_to_kusion.kusion_spec_stream_stack(stack)`.

---

## 2. Module Models (`framework/models/modules/`)

### Component

**File**: `framework/models/modules/component.k`  
**Purpose**: Main deployable units — applications and infrastructure services.

```kcl
schema ComponentAsset:
    image?: str                # Container image (e.g., "ghcr.io/org/app")
    helmChart?: str            # Helm chart reference (alternative to image)
    version: str               # Version/tag

schema ComponentLeader:
    name: str                  # Resource name
    kind: str                  # K8s kind (e.g., "Deployment")
    apiVersion: str            # K8s apiVersion (e.g., "apps/v1")
    namespace?: str            # Optional namespace

schema ComponentInstance:
    name: str                  # Component name
    kind: str                  # "APPLICATION" or "INFRASTRUCTURE"
    namespace: str             # Target namespace
    configurations: any        # Merged configurations
    asset: ComponentAsset      # Image/chart reference
    leaders: [ComponentLeader] # Primary resources (for dependency tracking)
    manifests: [any]           # K8s manifest objects
    dependsOn: [any]           # Dependencies (namespace instances, etc.)

schema Component:
    instance: ComponentInstance
    kind: "APPLICATION" | "INFRASTRUCTURE"
    name: str
    namespace: str
    configurations: any
    asset: ComponentAsset
    leaders: [ComponentLeader]
    manifests: [any]
    dependsOn?: [any]
```

### Accessory

**File**: `framework/models/modules/accessory.k`  
**Purpose**: Supporting resources like databases, message brokers, persistent volumes.

```kcl
schema AccessoryAsset:
    image?: str
    version: str

schema AccessoryLeader:
    name: str
    kind: str
    apiVersion: str
    namespace?: str

schema AccessoryInstance:
    name: str
    kind: str                  # "CRD" or "SECRET"
    namespace: str
    configurations: any
    asset: AccessoryAsset
    leaders: [AccessoryLeader]
    manifests: [any]
    dependsOn: [any]

schema Accessory:
    instance: AccessoryInstance
    kind: "CRD" | "SECRET"
    name: str
    namespace: str
    configurations: any
    asset: AccessoryAsset
    leaders: [AccessoryLeader]
    manifests: [any]
    dependsOn?: [any]
```

### K8sNamespace

**File**: `framework/models/modules/k8snamespace.k`  
**Purpose**: Kubernetes namespace resources with auto-generated manifests.

```kcl
schema K8sNamespaceLeader:
    name: str
    kind: str                      # Always "Namespace"
    apiVersion: str                # Always "v1"
    namespace?: str

schema K8sNamespaceInstance:
    name: str
    kind: str
    apiVersion: str
    configurations: any
    leaders: [K8sNamespaceLeader]
    manifests: [any]               # Auto-generated Namespace manifest
    dependsOn: [any]               # Default: []

schema K8sNamespace:
    instance: K8sNamespaceInstance
    kind: str = "Namespace"
    name: str
    apiVersion: str = "v1"
    configurations: any
    annotations?: {str:str}
    labels?: {str:str}
    leaders: [K8sNamespaceLeader]   # Auto-populated
    manifests: [k8core.Namespace]   # Auto-generated from name/annotations/labels
```

**Note**: K8sNamespace auto-generates its own `manifests` and `leaders` from the `name` field. You only need to provide `name` and `configurations`.

### ThirdParty

**File**: `framework/models/modules/thirdparty.k`  
**Purpose**: External vendor-managed resources (e.g., Helm charts from vendors).

```kcl
schema ThirdPartyInstance:
    packageManager: str                # "HELM", "JSONNET", etc.
    platformConfigurations: any        # Platform-specific configs
    vendorConfigurations: {str:str}    # Vendor-provided values

schema ThirdParty:
    instance: ThirdPartyInstance
    packageManager: "HELM" | "JSONNET" | "KUSTOMIZE" | "TIMONI" | "KUSION"
    platformConfigurations: any
    vendorConfigurations: {str:str}
```

---

## 3. Procedure Schemas (`framework/procedures/`)

### KusionResource

**File**: `framework/procedures/kcl_to_kusion.k`

```kcl
schema KusionResource:
    id: str                    # "apiVersion:kind:namespace:name" or "apiVersion:kind:name"
    type: str = "Kubernetes"   # Always "Kubernetes"
    attributes: any            # The full K8s manifest
    dependsOn?: [str] = []     # List of dependency IDs
    extensions?: {str:str}     # Optional extensions

schema KusionSpec:
    resources: [KusionResource]
```

### Dependency

**File**: `framework/procedures/kcl_to_kusion.k`

```kcl
schema Dependency:
    manifest: any              # The K8s manifest
    dependsOn: [any] = []      # Dependencies from component/accessory
```

---

## 4. Custom Schemas (`framework/custom/`)

### Helm Chart

**File**: `framework/custom/helm/helm.k`

```kcl
schema Chart:
    apiVersion: str            # "v1" or "v2"
    name: str
    description?: str
    type?: str = "application"
    version: str
    appVersion?: str
    kubeVersion?: str
    keywords?: [str]
    home?: str
    sources?: [str]
    maintainers?: [Maintainer]
    icon?: str
    dependencies?: [Dependency]
    annotations?: {str: str}

schema Maintainer:
    name: str
    email?: str
    url?: str

schema Dependency:
    name: str
    version: str
    repository: str
    alias?: str
    condition?: str
    tags?: [str]
    enabled?: bool
```

### Helmfile

**File**: `framework/custom/helmfile/helmfile.k`

```kcl
schema Helmfile:
    repositories?: [Repository]
    releases?: [Release]
    environments?: {str: Environment}
    helmfiles?: [HelmfilePath]
    defaults?: ReleaseDefaults
    namespace?: str

schema Repository:
    name: str
    url: str

schema Release:
    name: str
    namespace?: str
    chart: str
    version?: str
    values?: [any]
    needs?: [str]
    wait?: bool
    atomic?: bool
```

### Spring Application Properties

**File**: `framework/custom/spring_application_properties.k`

```kcl
schema ApplicationProperties:
    applicationName: str
    serverPort: int
    contextPath: str
    moduleSpring?: ModuleSpring
    keycloak?: ModuleKeycloak
    management?: ModuleManagement
    springDoc?: ModuleSpringDoc
    opensearchClient?: ModuleOpensearchClient
```

---

## 5. Schema Inheritance Hierarchy

```
Component (framework)
├── VideoCollectorMongodbPythonModule (project module)
├── KafkaVideoServerPythonModule (project module)
└── ... (other application modules)

Accessory (framework)
├── KafkaSingleInstanceModule (infrastructure module)
├── MongoDBSingleInstanceModule (infrastructure module)
├── MongoDBPersistenceModule (infrastructure module)
└── ... (other infrastructure modules)

Stack (framework)
├── VideoStreamingDevelopmentStack (project stack)
├── VideoStreamingv1_0_0_BaseStack (versioned stack)
└── ... (other version stacks)
```

---

## 6. Usage Summary

### Creating a Module
```kcl
import framework.models.modules.component as component

schema MyModule(component.Component):
    kind = "APPLICATION"
    leaders = [component.ComponentLeader { name = name, kind = "Deployment", apiVersion = "apps/v1", namespace = namespace }]
    manifests = [/* K8s manifests */]
```

### Creating a Stack
```kcl
import framework.models.stack

schema MyStack(stack.Stack):
    k8snamespaces = [_ns]
    components = [_my_module]
    accessories = [_my_db]

    _ns = K8sNamespace { name = instanceConfigurations.namespace, configurations = instanceConfigurations }.instance
    _my_module = MyModule { name = "app", namespace = _ns.name, ... }.instance
```

### Creating a Release
```kcl
import framework.models.release

_release = release.Release {
    name = "my_release"
    version = "1.0.0"
    project = my_project.instance
    tenant = my_tenant.instance
    site = my_site.instance
    profile = my_profile.instance
    stack = my_stack
}
```
