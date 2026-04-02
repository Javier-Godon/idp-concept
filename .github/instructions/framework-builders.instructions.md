---
description: "Use when creating K8s manifests with framework builders (build_deployment, build_service, build_configmap, build_pv_and_pvc, build_service_account) or working with framework templates (WebAppModule, SingleDatabaseModule, KafkaClusterModule). Covers builder schemas, template fields, and assembly helpers."
applyTo: ["**/builders/**/*.k", "**/templates/**/*.k", "**/assembly/**/*.k"]
---

# Framework Builders, Templates & Assembly

## Builders (`framework/builders/`)

Low-level lambdas that generate individual K8s manifests from typed specs.

### build_deployment (deployment.k)
```kcl
import framework.builders.deployment as deploy

deploy.build_deployment(deploy.DeploymentSpec {
    name = "my-app"
    namespace = "apps"
    image = "registry/my-app"
    version = "1.0.0"
    port = 8080
    replicas = 2
    env = [{ name = "KEY", value = "val" }]
    resources = deploy.ResourceSpec {
        cpuRequest = "250m"     # default
        cpuLimit = "1"          # default
        memoryRequest = "512Mi" # default
        memoryLimit = "2Gi"     # default
    }
    livenessProbe = deploy.ProbeSpec {
        probeType = "http"      # "exec" | "http" | "tcp"
        path = "/health"
        port = 8080
        initialDelaySeconds = 30
        periodSeconds = 5
    }
    # Optional: readinessProbe, startupProbe, configMapRef, serviceAccountName,
    #           command, args, volumes, volumeMounts, strategy, minReadySeconds
})
```

ConfigMap auto-wiring: set `configMapRef = "my-configmap"` and the builder auto-adds the volume + volumeMount.

### build_service (service.k)
```kcl
import framework.builders.service as svc

svc.build_service(svc.ServiceSpec {
    name = "my-app"
    namespace = "apps"
    port = 8080
    serviceType = "ClusterIP"   # default; also "NodePort", "LoadBalancer"
    # Optional: targetPort, nodePort, portName, labels
})
```

### build_configmap (configmap.k)
```kcl
import framework.builders.configmap as cm

cm.build_configmap(cm.ConfigMapSpec {
    name = "my-config"
    namespace = "apps"
    data = { "application.yaml" = "server.port: 8080" }
})
```

### build_pv_and_pvc (storage.k)
Returns a **list of 2** items: [PV, PVC].
```kcl
import framework.builders.storage as store

store.build_pv_and_pvc(store.PersistentVolumeSpec {
    name = "my-db"
    namespace = "infra"
    size = "50Gi"
    hostPath = "/mnt/data/my-db"
    # Optional: storageClassName, accessMode ("ReadWriteOnce"), reclaimPolicy ("Retain")
})
```

### build_service_account (service_account.k)
```kcl
import framework.builders.service_account as sa

sa.build_service_account(sa.ServiceAccountSpec {
    name = "my-app"
    namespace = "apps"
    # Optional: imagePullSecretName
})
```

### build_component_leader / build_accessory_leader (leader.k)
```kcl
import framework.builders.leader as leader

leader.build_component_leader(name, namespace)
# Returns ComponentLeader { name, kind="Deployment", apiVersion="apps/v1", namespace }

leader.build_accessory_leader(name, namespace, "Kafka", "kafka.strimzi.io/v1beta2")
# Returns AccessoryLeader { name, kind, apiVersion, namespace }
```

## Templates (`framework/templates/`)

High-level modules that auto-generate all manifests from a few fields.

### WebAppModule (webapp.k) — extends Component
Set: `port`, `serviceType`, `replicas`, `configData`, `env`, `resources`, `livenessProbe`, `readinessProbe`, `startupProbe`, `imagePullSecretName`

### SingleDatabaseModule (database.k) — extends Accessory
Set: `port`, `dataPath`, `storageSize`, `storageHostPath`, `env`, `resources`, `serviceType`, `portName`

### KafkaClusterModule (kafka.k) — extends Accessory
Set: `clusterName`, `kafkaVersion`, `kafkaReplicas`, `zookeeperReplicas`, `storageSize`, `topics` (list of `KafkaTopicSpec`)

### PostgreSQLClusterModule (postgresql.k) — extends Accessory
Wraps CloudNativePG operator (`postgresql.cnpg.io/v1`).
Build lambdas: `build_cnpg_cluster`, `build_pooler`, `build_scheduled_backup`
Set: `instances`, `storageSize`, `pgVersion`, `monitoring`, `backup` (BackupSpec), `pooler` (PoolerSpec), `walStorage`, `pgParams`, `imageName`

### MongoDBCommunityModule (mongodb.k) — extends Accessory
Wraps MongoDB Community Operator (`mongodbcommunity.mongodb.com/v1`).
Build lambda: `build_mongodb_community`
Set: `members`, `mongodbVersion`, `storageSize`, `storageClassName`, `users` (list of MongoDBUserSpec), `resources`

### RabbitMQClusterModule (rabbitmq.k) — extends Accessory
Wraps RabbitMQ Cluster Operator (`rabbitmq.com/v1beta1`).
Build lambda: `build_rabbitmq_cluster`
Set: `replicas`, `storageSize`, `storageClassName`, `image`, `plugins`, `additionalConfig`, `resources`

### RedisModule (redis.k) — extends Accessory
Wraps OT Redis Operator (`redis.redis.opstreelabs.in/v1beta2`).
Build lambda: `build_redis`
Set: `mode` ("standalone"|"cluster"), `clusterSize`, `storageSize`, `storageClassName`, `image`, `resources`

### KeycloakModule (keycloak.k) — extends Accessory
Wraps Keycloak Operator (`k8s.keycloak.org/v2alpha1`).
Build lambda: `build_keycloak`
Set: `instances`, `hostname`, `database` (DatabaseSpec), `httpEnabled`, `tlsSecret`, `realmImports`

### OpenSearchClusterModule (opensearch.k) — extends Accessory
Wraps OpenSearch K8s Operator (`opensearch.org/v1`).
Build lambda: `build_opensearch_cluster`
Set: `version`, `nodePools` (list of NodePoolSpec), `dashboards` (DashboardsSpec), `securityConfig`, `monitoring`

### VaultStaticSecretModule (vault.k) — Vault Secrets Operator
Wraps HashiCorp VSO (`secrets.hashicorp.com/v1beta1`). ⚠️ BUSL-1.1 license.
Build lambdas: `build_vault_connection`, `build_vault_auth`, `build_vault_static_secret`
Set: VaultConnectionSpec (address, TLS), VaultAuthSpec (method, mount, role), VaultStaticSecretSpec (mount, path, type, destination)

### QuestDBSpec (questdb.k) — ThirdPartyHelm wrapper
No operator; wraps official Helm chart via ThirdPartyHelmSpec.
Build lambda: `build_questdb_release`
Set: `storageSize`, `chartVersion`, `storageClassName`, `cpuRequest/Limit`, `memoryRequest/Limit`, `httpPort`, `ilpPort`, `pgPort`, `serviceType`

### OpenTelemetry Operator (opentelemetry.k) — Helm + CRDs
Operator deployed via Helm (`open-telemetry/opentelemetry-operator`), collector + instrumentation via CRDs.
Build lambdas: `build_otel_operator`, `build_otel_collector`, `build_instrumentation`
- `OtelOperatorSpec`: `certManagerEnabled`, `autoGenerateCert`, `createRbacPermissions`, `collectorImage`
- `OtelCollectorSpec`: `mode` (deployment/daemonset/statefulset/sidecar), `replicas`, `receivers`, `processors`, `exporters`, `pipelines`, `targetAllocatorEnabled`, `targetAllocatorPrometheusCR`
- `InstrumentationSpec`: `exporterEndpoint`, `propagators`, `samplerType`, `samplerArgument`, `javaImage`, `pythonImage`, `nodejsImage`, `dotnetImage`, `goImage`

## Assembly Helpers (`framework/assembly/helpers.k`)

```kcl
import framework.assembly.helpers as asm

# From a literal name:
_ns = asm.create_namespace("my-namespace", instanceConfigurations)

# From a config field:
_ns = asm.create_namespace_from_config(instanceConfigurations, "appsNamespace")
```

Both return a `K8sNamespaceInstance` ready for use in stack arrays and `dependsOn`.

## Check Blocks (Validation)

Builders include compile-time validation via `check` blocks:

| Builder | Validations |
|---|---|
| `DeploymentSpec` | `port` 1-65535, `replicas` >= 1 |
| `ServiceSpec` | `port` 1-65535, `serviceType` in ClusterIP/NodePort/LoadBalancer |
| `PersistentVolumeSpec` | `accessMode` in ReadWriteOnce/ReadOnlyMany/ReadWriteMany, `reclaimPolicy` in Retain/Delete/Recycle |

### EnvVar Schema (`framework/models/modules/common.k`)
```kcl
import framework.models.modules.common as common

common.EnvVar { name = "KEY", value = "val" }
common.EnvVar { name = "SECRET", valueFrom = common.EnvVarSource {
    secretKeyRef = common.KeySelector { name = "secret-name", key = "key" }
}}
```
- Must have either `value` OR `valueFrom`, not both, not neither
- `EnvVarSource` must have either `secretKeyRef` OR `configMapKeyRef`, not both

## Output Procedures (`framework/procedures/`)

Lambdas that transform stack data into target output formats. Used by `render.k`.

| Procedure | Output Format | Key Functions |
|---|---|---|
| `kcl_to_yaml` | Plain K8s YAML | `yaml_stream_stack` |
| `kcl_to_argocd` | ArgoCD Application CRDs | `generate_applications_from_stack`, `generate_app_project` |
| `kcl_to_helm` | Chart.yaml + values.yaml | `generate_charts_from_stack` |
| `kcl_to_helmfile` | helmfile.yaml | `generate_helmfile` |
| `kcl_to_kustomize` | kustomization.yaml | `generate_kustomization_from_stack`, `generate_overlay_patch` |
| `kcl_to_kusion` | Kusion spec YAML | `generate_kusion_resources` |
| `kcl_to_timoni` | Timoni CUE module | `generate_timoni_module_from_stack`, `generate_timoni_metadata`, `generate_timoni_values`, `generate_timoni_resources` |
| `kcl_to_crossplane` | Crossplane XRD + Composition + XR | `generate_crossplane_from_stack`, `generate_xrd`, `generate_composition`, `generate_xr`, `generate_prerequisites` |

### Timoni Procedure (`kcl_to_timoni.k`)
Generates a Timoni module structure (Option A: raw YAML wrapped in CUE structure).
Output dict contains: `metadata` (timoni.sh/v1alpha1 Module), `values` (component/accessory/namespace config), `resources` (flat K8s manifest list), `resourceCount`.
The CLI (`koncept render timoni`) writes these into a directory: `timoni.cue`, `values.cue`, `templates/config.cue`, `README.md`.

### Crossplane Procedure (`kcl_to_crossplane.k`)
Generates static Crossplane resources from stack data: XRD (CompositeResourceDefinition), Composition (Pipeline mode with patch-and-transform → function-sequencer → auto-ready), XR (claim instance), and prerequisites (provider + function installs).
K8s manifests are wrapped in `kubernetes.crossplane.io/v1alpha2 Object` resources. `dependsOn` ordering maps to function-sequencer rules with regex patterns.
The CLI (`koncept render crossplane`) writes: `xrd.yaml`, `composition.yaml`, `xr.yaml`, `prerequisites/infrastructure.yaml`.

## Testing

- **268 unit tests** in `framework/tests/` directory (mirroring source structure)
- Run: `cd framework && kcl test ./...`
- Template tests validate builder outputs individually (see `kcl test` limitation in KCL skill)
- Integration: `kcl run` + `kubeconform` for full template validation
