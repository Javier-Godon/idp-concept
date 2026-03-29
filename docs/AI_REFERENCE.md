# AI Agent Reference — idp-concept Framework

> **Audience:** AI coding assistants (GitHub Copilot, Claude, GPT) that need to understand the codebase.
> **Purpose:** Serve as a concise, structured reference for code generation and modification tasks.

---

## Quick Architecture Map

```
framework/
├── builders/       ← Phase 1: K8s manifest builder functions
│   ├── deployment.k    (DeploymentSpec → apps.Deployment)
│   ├── service.k       (ServiceSpec → core.Service)
│   ├── configmap.k     (ConfigMapSpec → core.ConfigMap)
│   ├── storage.k       (PersistentVolumeSpec → [PV, PVC])
│   ├── service_account.k (ServiceAccountSpec → ServiceAccount)
│   └── leader.k        (build_component_leader, build_accessory_leader)
├── templates/      ← Phase 2: High-level module templates
│   ├── webapp.k        (WebAppModule → Deploy+Svc+ConfigMap+SA)
│   ├── database.k      (SingleDatabaseModule → Deploy+Svc+PV/PVC)
│   └── kafka.k         (KafkaClusterModule → Kafka+Topics)
├── assembly/       ← Phase 3: Stack assembly helpers
│   └── helpers.k       (create_namespace, create_namespace_from_config)
├── factory/        ← Phase 5: Factory scaffolding
│   └── seed.k          (FactorySeed → merges configs + creates Release)
├── models/         ← Domain schemas (unchanged)
│   ├── project.k, tenant.k, site.k, profile.k, stack.k, release.k
│   ├── configurations.k  ← Phase 4: BaseConfigurations + merge
│   ├── modules/    (component.k, accessory.k, k8snamespace.k, thirdparty.k)
│   └── gitops/     (gitopsstack.k)
├── procedures/     ← Output generators (unchanged)
│   ├── kcl_to_yaml.k, kcl_to_helm.k, kcl_to_kusion.k
│   └── kcl_to_argocd.k (stub), kcl_to_helmfile.k (stub)
└── custom/         ← Format-specific schemas
    ├── argocd/, helm/, helmfile/
    └── spring_application_properties.k
```

---

## Pattern Reference for Code Generation

### Creating a New Web Application Module (recommended approach)

```kcl
import framework.templates.webapp as webapp
import framework.builders.deployment as deploy

schema MyAppModule(webapp.WebAppModule):
    port = 8080
    serviceType = "ClusterIP"
    resources = deploy.ResourceSpec {
        cpuLimit = "2"
        memoryLimit = "4Gi"
    }
    livenessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/health"
        port = 8080
    }
    readinessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/ready"
        port = 8080
    }
    # Optional: env, configData, imagePullSecretName, startupProbe
```

### Creating a New Database Module (recommended approach)

```kcl
import framework.templates.database as database
import framework.builders.deployment as deploy

schema MyDbModule(database.SingleDatabaseModule):
    port = 5432
    dataPath = "/var/lib/postgresql/data"
    storageSize = "50Gi"
    resources = deploy.ResourceSpec {
        cpuLimit = "1"
        memoryLimit = "2Gi"
    }
    env = [{ name = "POSTGRES_DB", value = "mydb" }]
```

### Creating a New Kafka Module (recommended approach)

```kcl
import framework.templates.kafka as kafka

schema MyKafkaModule(kafka.KafkaClusterModule):
    clusterName = "my-cluster"
    topics = [
        kafka.KafkaTopicSpec { name = "events", partitions = 6 }
        kafka.KafkaTopicSpec { name = "logs", partitions = 3 }
    ]
```

### Creating a Raw Module (Level 0, full control)

```kcl
import framework.models.modules.component as component
import framework.builders.leader as leader
import framework.builders.deployment as deploy
import framework.builders.service as svc

schema MyCustomModule(component.Component):
    kind = "APPLICATION"
    leaders = [leader.build_component_leader(name, namespace)]
    manifests = [
        deploy.build_deployment(deploy.DeploymentSpec {
            name = name, namespace = namespace
            image = asset.image, version = asset.version
            port = 8080
        })
        svc.build_service(svc.ServiceSpec {
            name = name, namespace = namespace, port = 8080
        })
    ]
```

### Configuration Schema Pattern

```kcl
import framework.models.configurations as base

schema MyProjectConfigurations(base.BaseConfigurations):
    # Add project-specific fields
    customField?: str
    customNamespace?: str

# Merge function (in merge_configurations.k)
import framework.models.configurations as base
merge_configurations = lambda k, p, t, s -> any {
    base.merge_configurations(k, p, t, s)
}
```

### Stack Definition Pattern

```kcl
import framework.models.stack
import framework.assembly.helpers as asm

schema MyStack(stack.Stack):
    _ns = asm.create_namespace(instanceConfigurations.appsNamespace, instanceConfigurations)
    k8snamespaces = [_ns]
    components = [
        MyModule {
            name = "my-app"
            namespace = _ns.name
            asset = { image = "...", version = "..." }
            configurations = instanceConfigurations
            dependsOn = [_ns]
        }.instance
    ]
```

### Factory Pattern

```kcl
# factory_seed.k
import framework.models.release
import framework.models.gitops.gitopsstack

_stack = MyStack { instanceConfigurations = _merged_config }
_gitops_stack = gitopsstack.GitOpsStack {
    instanceConfigurations = _stack.instanceConfigurations
    k8snamespaces = _stack.k8snamespaces
    components = _stack.components
    accessories = _stack.accessories
}

# yaml_builder.k
import framework.procedures.kcl_to_yaml
kcl_to_yaml.yaml_stream_stack(factory_seed._gitops_stack)
```

---

## KCL Module Resolution Rules

- The `kcl.mod` at the project root defines the package name and dependencies
- For nested packages (e.g., `pre_releases/`), create a separate `kcl.mod` that depends on the parent project
- Framework is resolved transitively: `pre_releases` → `project` → `framework`
- Framework dependency in `pre_releases/kcl.mod` should NOT have a direct path — let it resolve transitively
- Run `kcl` commands from the directory containing the `kcl.mod`

---

## Key Schema Hierarchies

```
Component ← WebAppModule ← ConcreteAppModule
Accessory ← SingleDatabaseModule ← ConcreteDbModule
Accessory ← KafkaClusterModule ← ConcreteKafkaModule
Stack ← ConcreteStack (adds namespaces, components, accessories)
BaseConfigurations ← ProjectConfigurations (adds project-specific fields)
```

---

## Builder Function Signatures

| Builder | Input Schema | Output Type |
|---|---|---|
| `build_deployment` | `DeploymentSpec` | `apps.Deployment` |
| `build_service` | `ServiceSpec` | `core.Service` |
| `build_configmap` | `ConfigMapSpec` | `core.ConfigMap` |
| `build_pv_and_pvc` | `PersistentVolumeSpec` | `[PV, PVC]` |
| `build_service_account` | `ServiceAccountSpec` | `core.ServiceAccount` |
| `build_component_leader` | `name, namespace, kind?, apiVersion?` | `ComponentLeader` |
| `build_accessory_leader` | `name, namespace, kind, apiVersion` | `AccessoryLeader` |

---

## Template Module Fields

### WebAppModule (extends Component)
| Field | Type | Default | Required |
|---|---|---|---|
| `port` | int | - | Yes |
| `serviceType` | str | "ClusterIP" | No |
| `nodePort` | int | - | No |
| `replicas` | int | 1 | No |
| `configData` | {str:str} | - | No |
| `imagePullSecretName` | str | - | No |
| `env` | [any] | - | No |
| `resources` | ResourceSpec | - | No |
| `livenessProbe` | ProbeSpec | - | No |
| `readinessProbe` | ProbeSpec | - | No |
| `startupProbe` | ProbeSpec | - | No |

### SingleDatabaseModule (extends Accessory)
| Field | Type | Default | Required |
|---|---|---|---|
| `port` | int | - | Yes |
| `dataPath` | str | "/data" | No |
| `storageSize` | str | "20Gi" | No |
| `storageHostPath` | str | "/mnt/data" | No |
| `serviceType` | str | "ClusterIP" | No |
| `env` | [any] | - | No |
| `resources` | ResourceSpec | - | No |

### KafkaClusterModule (extends Accessory)
| Field | Type | Default | Required |
|---|---|---|---|
| `clusterName` | str | - | Yes |
| `kafkaVersion` | str | "3.8.0" | No |
| `kafkaReplicas` | int | 1 | No |
| `zookeeperReplicas` | int | 1 | No |
| `storageSize` | str | "100Gi" | No |
| `topics` | [KafkaTopicSpec] | [] | No |

---

## Project Dir Structure (erp_back example — uses new framework)

```
projects/erp_back/
├── kcl.mod                   (name="erp_back", deps: framework, k8s)
├── main.k
├── core_sources/
│   ├── erp_back_configurations.k  (extends BaseConfigurations)
│   └── merge_configurations.k     (delegates to base.merge_configurations)
├── kernel/
│   ├── configurations.k           (kernel defaults)
│   └── project_def.k              (Project instance)
├── modules/
│   ├── appops/erp_api/erp_api_module_def.k      (extends WebAppModule)
│   └── infrastructure/postgres/postgres_module_def.k (extends SingleDatabaseModule)
├── stacks/development/
│   ├── stack_def.k                (uses asm.create_namespace)
│   ├── profile_def.k
│   └── profile_configurations.k
├── tenants/
│   ├── vendor/tenant_def.k
│   └── acme_corp/tenant_def.k
├── sites/development/dev_cluster/
│   ├── site_def.k
│   └── configurations.k
└── pre_releases/
    ├── kcl.mod                    (deps: erp_back — framework resolves transitively)
    ├── configurations_dev.k       (merges all 4 layers)
    └── gitops/dev/factory/
        ├── factory_seed.k
        ├── yaml_builder.k
        └── argocd_builder.k
```

---

## Common Gotchas

1. **`$type` not `type`** — Use `$type` for K8s `type` fields (KCL reserved word)
2. **`.instance` pattern** — Always call `.instance` when adding modules to a stack
3. **`Undefined` for optional fields** — KCL strips Undefined from output, use it instead of None
4. **Private vars start with `_`** — Not exported to output YAML
5. **Pre-releases need their own `kcl.mod`** — Must declare dependency on parent project
6. **`option("key")` for CLI args** — Used with `kcl run -D key=value`
7. **Framework path resolution** — Don't add direct framework dep in pre_releases kcl.mod; let it resolve transitively through the project
