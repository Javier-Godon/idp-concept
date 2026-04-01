---
description: Create a new KCL module (Component or Accessory) using framework templates or raw manifests
---

# Create a New KCL Module

You are creating a KCL module for the idp-concept project. Choose the approach based on the module type.

## Context Files
Read these for patterns:
- #file:.github/docs/AI_REFERENCE.md
- #file:.github/instructions/kcl-module-system.instructions.md
- #file:framework/models/modules/component.k
- #file:framework/models/modules/accessory.k

### Template approach (RECOMMENDED for new modules):
- #file:framework/templates/webapp.k
- #file:framework/templates/database.k
- #file:framework/templates/kafka.k
- #file:projects/erp_back/modules/appops/erp_api/erp_api_module_def.k
- #file:projects/erp_back/modules/infrastructure/postgres/postgres_module_def.k

### Raw approach (full control):
- #file:projects/video_streaming/modules/appops/video_collector_mongodb_python/video_collector_mongodb_python_module_def.k

## Choose Approach

### Template Approach (recommended)
For standard patterns, use framework templates:

| Pattern | Template | Example |
|---|---|---|
| Web app (Deploy+Svc+ConfigMap+SA) | `webapp.WebAppModule` | erp_api |
| Database (Deploy+Svc+PV/PVC) | `database.SingleDatabaseModule` | postgres |
| Kafka cluster (CRDs) | `kafka.KafkaClusterModule` | kafka |

```kcl
import framework.templates.webapp as webapp
import framework.builders.deployment as deploy

schema MyModule(webapp.WebAppModule):
    port = 8080
    serviceType = "ClusterIP"
    resources = deploy.ResourceSpec { cpuLimit = "2", memoryLimit = "4Gi" }
    livenessProbe = deploy.ProbeSpec { probeType = "http", path = "/health", port = 8080 }
```

### Raw Approach (full control)
For custom resource types not covered by templates:

```kcl
import framework.models.modules.component
import framework.builders.leader as leader
import framework.builders.deployment as deploy
import framework.builders.service as svc

schema MyModule(component.Component):
    kind = "APPLICATION"
    leaders = [leader.build_component_leader(name, namespace)]
    manifests = [
        deploy.build_deployment(deploy.DeploymentSpec { name = name, namespace = namespace, ... })
        svc.build_service(svc.ServiceSpec { name = name, namespace = namespace, ... })
    ]
```

## Rules
1. Module files MUST be named `<module_name>_module_def.k`
2. Use `${asset.image}:${asset.version}` for container images
3. Use `$type` instead of `type` for Kubernetes type fields
4. Use `name` and `namespace` from the schema fields, not hardcoded values
5. Access project config via `configurations.<field>` for environment-specific values
6. For templates: set high-level fields (port, probes, env, resources) and let the template generate manifests
7. For raw: always set `kind`, `leaders`, and `manifests` fields

## Ask the user
- Module name
- Whether it's a Component (APPLICATION/INFRASTRUCTURE) or Accessory (CRD/SECRET)
- What K8s resources it should contain
- Whether to use templates (recommended) or raw manifests
- Which project directory to place it in
