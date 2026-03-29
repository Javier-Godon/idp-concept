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

## Assembly Helpers (`framework/assembly/helpers.k`)

```kcl
import framework.assembly.helpers as asm

# From a literal name:
_ns = asm.create_namespace("my-namespace", instanceConfigurations)

# From a config field:
_ns = asm.create_namespace_from_config(instanceConfigurations, "appsNamespace")
```

Both return a `K8sNamespaceInstance` ready for use in stack arrays and `dependsOn`.
