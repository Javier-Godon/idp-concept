# Framework Extension Guide

> Creating custom modules and integrating them with idp-concept

This guide provides practical patterns for extending idp-concept with custom components, accessories, and templates.

---

## 1. Module Architecture Basics

Every module in idp-concept follows a consistent pattern:

```
Module (extends Component or Accessory)
├── Instance (flattened data)
├── Leaders (Deployment/StatefulSet/etc.)
├── Manifests (YAML resources)
├── Configuration (environment-specific data)
└── Dependencies (ordering guarantees)
```

### Schema Definition

```kcl
import models.modules.component as component
import models.modules.k8snamespace as k8sns

schema MyCustomApp(component.Component):
    """My custom application module."""
    port: int
    replicas: int = 1
    image: str
    version: str
    configData: {str: str} = {}
    env: [component.EnvVar] = []
    resources: component.ResourceSpec = {}

    check:
        port >= 1 and port <= 65535
        replicas >= 1
```

### Instance Pattern

The `.instance` property flattens the schema into a deployable structure:

```kcl
_app = MyCustomApp {
    name = "my-app"
    namespace = "apps"
    configurations = {}
    asset = { image = "myregistry/myapp", version = "1.0.0" }
    port = 8080
    replicas = 2
    image = "myregistry/myapp:1.0.0"
    version = "1.0.0"
}.instance
```

---

## 2. Creating Custom Components

### Step 1: Define the Module Schema

Create `projects/my-project/modules/custom_app_module.k`:

```kcl
import models.modules.component as component
import framework.builders.deployment as deploy
import framework.builders.service as svc

schema MyApp(component.Component):
    """Custom application with Deployment and Service."""
    port: int
    replicas: int = 1
    image: str
    version: str
    env: [component.EnvVar] = []
    resources: deploy.ResourceSpec = {}

    check:
        port >= 1 and port <= 65535
        replicas >= 1

    _deployment = deploy.build_deployment(deploy.DeploymentSpec {
        name = name
        namespace = namespace
        image = "${image}:${version}"
        port = port
        replicas = replicas
        env = env
        resources = resources
    })

    _service = svc.build_service(svc.ServiceSpec {
        name = name
        namespace = namespace
        port = port
    })

    kind = "APPLICATION"
    leaders = [component.ComponentLeader {
        name = name
        kind = "Deployment"
        apiVersion = "apps/v1"
        namespace = namespace
    }]
    manifests = [_deployment, _service]
```

### Step 2: Register in Stack Definition

```kcl
import projects.my_project.modules.custom_app_module as custom

schema MyProjectStack(models.stack.Stack):
    """Stack for my project."""
    
    _my_app = custom.MyApp {
        name = "frontend"
        namespace = "apps"
        configurations = instanceConfigurations
        asset = { image = "myregistry/frontend", version = "1.0.0" }
        port = 3000
        replicas = 3
        image = "myregistry/frontend"
        version = "1.0.0"
        env = [
            { name = "API_URL", value = "http://api:8080" }
        ]
    }.instance

    components = [_my_app]
```

---

## 3. Creating Custom Accessories (Infrastructure Resources)

### Example: Custom Database Module

```kcl
import models.modules.accessory as accessory
import framework.builders.storage as storage

schema MyDatabase(accessory.Accessory):
    """Custom PostgreSQL cluster module."""
    port: int = 5432
    version: str = "15"
    storageSize: str = "10Gi"
    storageClassName: str = "standard"
    createLocalPersistentVolume: bool = False
    hostPath: str = "/mnt/data"

    check:
        port >= 1 and port <= 65535

    _pvc = storage.build_pv_and_pvc(storage.PersistentVolumeSpec {
        name = name
        namespace = namespace
        size = storageSize
        storageClassName = storageClassName
        createPersistentVolume = createLocalPersistentVolume
        hostPath = hostPath
    })

    kind = "CRD"
    leaders = [accessory.AccessoryLeader {
        name = name
        kind = "StatefulSet"
        apiVersion = "apps/v1"
        namespace = namespace
    }]
    manifests = [_pvc]
```

---

## 4. Creating Custom Templates

Templates are high-level modules that generate multiple manifests from a simple schema.

### Template Structure

```
framework/templates/myservice/v1_0_0/
├── myservice.k          # Main module schema
├── models.k             # Supporting schemas
├── builders.k           # Helper functions (optional)
└── README.md            # Template documentation
```

### Example Template: Custom Cache Service

```kcl
# framework/templates/mycache/v1_0_0/mycache.k

import models.modules.accessory as accessory
import models.modules.k8snamespace as k8sns
import framework.assembly.helpers as asm

schema MyCacheModule(accessory.Accessory):
    """High-level cache template."""
    replicas: int = 1
    storageSize: str = "5Gi"
    image: str = "mycache:latest"
    version: str = "1.0.0"
    port: int = 6379

    check:
        replicas >= 1
        port >= 1 and port <= 65535

    _cache_config = {
        name = name
        namespace = namespace
        replicas = replicas
        storageSize = storageSize
        image = image
        version = version
        port = port
    }

    kind = "INFRASTRUCTURE"
    leaders = [accessory.AccessoryLeader {
        name = name
        kind = "StatefulSet"
        apiVersion = "apps/v1"
        namespace = namespace
    }]
    # Build manifests via helper function or direct Kubernetes YAML
    manifests = _build_cache_manifests(_cache_config)
```

---

## 5. Configuration Merging Patterns

Modules inherit configuration through the 4-layer merge:

```
kernel (project base)
    ↓ merge
profile (version-specific)
    ↓ merge
tenant (customer-specific)
    ↓ merge
site (environment-specific)
    ↓ merge
→ Final Configuration
```

### Using Configurations in Modules

```kcl
schema MyApp(component.Component):
    # configurations field comes from Component base
    # Access environment-specific settings:
    
    _db_host = configurations.dbHost if configurations.dbHost else "localhost"
    _log_level = configurations.logLevel if configurations.logLevel else "info"
    
    env = [
        {name = "DB_HOST", value = _db_host}
        {name = "LOG_LEVEL", value = _log_level}
    ]
```

### Extending BaseConfigurations

```kcl
import framework.models.configurations as base_cfg

schema MyProjectConfigurations(base_cfg.BaseConfigurations):
    """Extended configuration for my project."""
    dbHost: str = "postgres.infra"
    cacheHost: str = "redis.infra"
    logLevel: str = "info"
    apiPort: int = 8080
    metricsEnabled: bool = True
```

---

## 6. Multi-Format Output Support

All custom modules automatically work with all 9 output formats:

```bash
# YAML
koncept render yaml

# Helm charts
koncept render helm

# Helmfile
koncept render helmfile

# Crossplane compositions
koncept render crossplane

# Kusion specs
koncept render kusion

# Kustomize overlays
koncept render kustomize

# Timoni modules
koncept render timoni

# ArgoCD applications
koncept render argocd

# Backstage scaffolding
koncept render backstage
```

Custom modules integrate automatically — no format-specific code needed.

---

## 7. Testing Custom Modules

### Unit Tests

```kcl
# framework/tests/mymodule_test.k

import projects.my_project.modules.custom_app_module as custom

test_custom_app_deployment = lambda -> None {
    _app = custom.MyApp {
        name = "test-app"
        namespace = "test"
        configurations = {}
        asset = { image = "test", version = "1.0.0" }
        port = 8080
        replicas = 1
        image = "test:1.0.0"
        version = "1.0.0"
    }.instance

    assert len(_app.manifests) > 0
    assert _app.kind == "APPLICATION"
}
```

### Acceptance Tests

```kcl
# framework/tests/acceptance/cases/my-custom-app_workload.k

import ._helpers as h
import projects.my_project.modules.custom_app_module as custom

_app = custom.MyApp {
    name = "acceptance-myapp"
    namespace = "idp-acceptance-myapp"
    configurations = {}
    asset = { image = "registry.k8s.io/pause", version = "3.10" }
    port = 8080
    replicas = 1
    image = "registry.k8s.io/pause:3.10"
    version = "1.0.0"
}.instance

h.render_component("idp-acceptance-myapp", _app)
```

Run with: `./scripts/acceptance_kind.sh --case my-custom-app`

---

## 8. Dependency Management

### Declaring Dependencies

Modules can depend on other modules:

```kcl
_app = MyApp {
    name = "frontend"
    ...
    dependsOn = [_database]  # Wait for database before app
}.instance
```

### Multi-Module Stacks

```kcl
_stack = RenderStack {
    components = [_app]
    accessories = [_database, _cache]
}
```

Output formats automatically handle dependency ordering:
- **Helmfile**: Generates `needs:` entries
- **Crossplane**: Adds sequencer rules
- **Dry-run**: Shows dependency graph

---

## 9. Publishing Custom Modules to OCI Registry

### Build and Publish

```bash
# From your project root
cd projects/my_project
kcl mod push --registry docker://myregistry.azurecr.io

# Reference in another project's kcl.mod:
[dependencies]
my_project = "oras://myregistry.azurecr.io/my_project:v1.0.0"
```

### Version Management

```toml
[package]
name = "my_project"
edition = "v0.10.0"
version = "1.0.0"  # Semantic versioning

[dependencies]
framework = { path = "../../../framework" }
```

---

## 10. Best Practices

### ✅ DO

- **Use schema inheritance** for natural composition
- **Keep modules focused** — one responsibility per module
- **Provide sensible defaults** for optional fields
- **Document with docstrings** — they appear in schema validation errors
- **Use the `.instance` property** when passing to stacks
- **Validate early** with `check:` blocks
- **Test templates** with acceptance fixtures
- **Version carefully** — patch for fixes, minor for features, major for breaks

### ❌ DON'T

- **Don't hardcode secrets** — use Secret references instead
- **Don't create privileged resources** — enforce least privilege
- **Don't skip validation** — let `check:` blocks catch errors early
- **Don't bypass the template pattern** — templates provide multi-format support
- **Don't use `latest` tags** — pin versions explicitly
- **Don't create fat modules** — split into smaller focused pieces
- **Don't forget acceptance tests** — they catch real rollout issues

---

## 11. Common Patterns

### Observability Sidecar Pattern

```kcl
_app = MyApp {
    name = "app-with-observability"
    ...
    configData = {
        "exporter.yaml" = "endpoint: http://dataprepper:4900\n"
    }
    dependsOn = [_dataprepper]  # Ensure collector is ready first
}
```

### Multi-Tier Stack Pattern

```kcl
_namespace = build_namespace("apps")
_frontend = MyFrontend {...}
_backend = MyBackend { dependsOn = [_database] }
_database = MyDatabase {}

_stack = RenderStack {
    k8snamespaces = [_namespace]
    components = [_frontend, _backend]
    accessories = [_database]
}
```

### Storage Footprint Pattern

```kcl
schema MyStorageApp(...):
    storageSize: str = "50Gi"
    storageClassName: str = "standard"  # Local dev friendly
    
_pvc = storage.build_pv_and_pvc(storage.PersistentVolumeSpec {
    name = name
    size = storageSize
    storageClassName = storageClassName
    createPersistentVolume = True  # Local dev mode
    hostPath = "/mnt/data/${name}"
})
```

---

## 12. Troubleshooting

### "cannot find the module" error

Check your `kcl.mod` file:
- Is the package `name` correct?
- Are relative paths correct relative to `kcl.mod` location?
- Are transitive dependencies declared?

```toml
[dependencies]
framework = { path = "../../framework" }
```

### Module fields not appearing

Ensure you're using the `.instance` property:

```kcl
_wrong = MyModule { ... }  # ← Schema, won't work
_right = MyModule { ... }.instance  # ← Instance, correct
```

### Manifest rendering differences between formats

Check the procedure implementation for the target format:
- `framework/procedures/kcl_to_*.k` files have format-specific logic
- Custom fields may have different handling per format
- Validation errors show which format rejected the schema

---

## 13. Next Steps

1. **Create your first module** — Start with a simple component
2. **Add tests** — Unit tests in `framework/tests/`, acceptance in `framework/tests/acceptance/cases/`
3. **Publish to OCI** — Share modules across teams
4. **Join the community** — Share patterns and learnings
5. **Monitor metrics** — Use `koncept metrics` to track adoption

---

## References

- [Framework Schemas Documentation](FRAMEWORK_SCHEMAS.md)
- [Acceptance Testing Guide](../testing/ACCEPTANCE_TESTING.md)
- [KCL Language](https://www.kcl-lang.io/docs/)
- [Kusion Documentation](https://www.kusionstack.io/)

