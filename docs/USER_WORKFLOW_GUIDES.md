# User Workflow Guides

> Developer-oriented documentation for each of the three user profiles. Each section describes **what the user does**, **how they do it**, and **what they should never need to know**.

---

## 1. Developer Workflow

**Goal**: Deploy and configure applications with zero Kubernetes knowledge.

### 1.1 Day-to-Day Commands

```bash
# 1. Navigate to your release
cd projects/my-project/pre_releases/manifests/dev/factory

# 2. Validate configuration (catch errors before rendering)
koncept validate

# 3. Render manifests for GitOps
koncept render argocd          # Plain K8s YAML → commit to Git → ArgoCD syncs

# 4. Render Helm charts for environment customization
koncept render helmfile        # Helm charts + values.yaml + helmfile.yaml

# 5. Render Kustomize overlays
koncept render kustomize       # kustomization.yaml + manifest files

# 6. Render Timoni CUE module (experimental)
koncept render timoni          # Timoni module structure

# 7. Generate Kusion spec
koncept render kusion          # Kusion spec YAML
```

### 1.2 What Developers Configure

Developers customize their applications through **site configuration files** (YAML-friendly KCL). They never write raw K8s manifests.

| What to Change | Where | Example |
|---|---|---|
| Replicas | `sites/<site>/site_def.k` | `replicas = 3` |
| Environment variables | `sites/<site>/site_def.k` | `springProfile = "production"` |
| Resource limits | `sites/<site>/site_def.k` | `memoryLimit = "4Gi"` |
| Feature flags | `tenants/<tenant>/tenant_def.k` | `featureNewUI = True` |
| Image version | `sites/<site>/site_def.k` | `version = "2.1.0"` |

### 1.3 What Developers Never Touch

- `framework/` — Platform internals
- `modules/*_module_def.k` — Module schemas (contact Platform Eng)
- `factory/` — Auto-generated builder files
- `stacks/` — Stack composition (contact Platform Eng)
- `kcl.mod` — Package dependencies

### 1.4 Troubleshooting

| Problem | Solution |
|---|---|
| `koncept validate` fails | Check error message — usually a config value out of range or missing |
| `koncept render` fails with KCL error | Run `koncept validate` first; if still fails, contact Platform Engineer |
| "Cannot find module" error | You're in the wrong directory — `cd` to the `factory/` folder |
| Application not deploying | Check ArgoCD UI → sync status; check events for K8s errors |
| Need a new environment variable | Add to site config file, run `koncept render`, commit to Git |

---

## 2. Platform Engineer (High-Level) Workflow

**Goal**: Compose deployment topologies — stacks, tenants, sites, modules — using pre-built templates.

### 2.1 Creating a New Project

```bash
# 1. Start with the template project (erp_back is the reference)
cp -r projects/erp_back projects/my_new_project

# 2. Define the project kernel
# Edit: projects/my_new_project/kernel/project_def.k
#   Set: name, domain, team, base configurations

# 3. Define configuration schema
# Edit: projects/my_new_project/core_sources/config.k
#   Extend BaseConfigurations with project-specific fields

# 4. Create application modules
# Edit: projects/my_new_project/modules/
#   Use framework templates: WebAppModule, SingleDatabaseModule, etc.

# 5. Compose a stack
# Edit: projects/my_new_project/stacks/
#   Declare which modules + namespaces go into the stack

# 6. Create tenant and site configs
# Edit: projects/my_new_project/tenants/ and sites/

# 7. Create pre-release
# Edit: projects/my_new_project/pre_releases/
#   Wire factory_seed.k → render.k
```

### 2.2 Creating a Module (Using Templates)

```kcl
# For a web application:
import framework.templates.webapp as webapp
import framework.builders.deployment as deploy

schema MyApiService(webapp.WebAppModule):
    port = 8080
    serviceType = "ClusterIP"
    replicas = 2
    configData = {
        "application.yaml" = "server.port: 8080\nspring.profiles.active: ${SPRING_PROFILE}"
    }
    env = [
        { name = "SPRING_PROFILE", value = "dev" }
        { name = "DB_PASSWORD", valueFrom = { secretKeyRef = { name = "db-creds", key = "password" } } }
    ]
    resources = deploy.ResourceSpec {
        cpuRequest = "500m"
        memoryRequest = "1Gi"
        cpuLimit = "2"
        memoryLimit = "4Gi"
    }
    livenessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health"
        port = 8080
        initialDelaySeconds = 60
    }

my_api_service = MyApiService {
    name = "my-api"
    namespace = "apps"
    image = "ghcr.io/org/my-api"
    version = "1.0.0"
}
```

### 2.3 Adding a Database (Operator-Managed)

```kcl
# Use CloudNativePG operator template
import framework.templates.postgresql as pg

schema MyDatabase(pg.PostgreSQLClusterModule):
    instances = 3
    storageSize = "100Gi"
    pgVersion = "16"
    monitoring = True

my_db = MyDatabase {
    name = "my-db"
    namespace = "data"
}
```

### 2.4 Composing a Stack

```kcl
import framework.assembly.helpers as asm
import framework.models.stack as stack_model

# Create namespaces
_apps_ns = asm.create_namespace("apps", instanceConfigurations)
_data_ns = asm.create_namespace("data", instanceConfigurations)

# Import modules
import modules.my_api as api
import modules.my_database as db

# Compose stack
my_stack = stack_model.Stack {
    components = [api.my_api_service.instance]
    accessories = [db.my_db.instance]
    namespaces = [_apps_ns, _data_ns]
}
```

### 2.5 What High-Level PEs Never Touch

- `framework/builders/` — Builder lambdas (Low-Level PE territory)
- `framework/procedures/` — Output format procedures
- `framework/models/` — Core domain schemas
- `kcl.mod` at framework level

### 2.6 Decision Matrix

| Scenario | Action |
|---|---|
| New microservice | Create `WebAppModule` in `modules/` |
| New database | Choose operator template or Bitnami wrapper |
| New environment | Create `sites/<env>/site_def.k` |
| New customer | Create `tenants/<customer>/tenant_def.k` |
| New deployment target | Create `pre_releases/` or `releases/` with factory |
| Custom infra component | Ask Low-Level PE to create builder/template |

---

## 3. Platform Engineer (Low-Level) Workflow

**Goal**: Design and maintain framework internals — schemas, builders, templates, procedures, and the output pipeline.

### 3.1 Creating a New Builder

Builders are low-level lambdas that generate a single K8s manifest:

```kcl
# framework/builders/my_resource.k

schema MyResourceSpec:
    name: str
    namespace: str

    check:
        len(name) > 0, "name is required"

build_my_resource = lambda spec: MyResourceSpec -> any {
    {
        apiVersion = "my.api/v1"
        kind = "MyResource"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {
                "app.kubernetes.io/name" = spec.name
                "app.kubernetes.io/managed-by" = "idp-concept"
            }
        }
        spec = {}
    }
}
```

**Testing requirement**: Every builder must have a matching `*_test.k` file:
```kcl
# framework/tests/builders/my_resource_test.k
import builders.my_resource as res

test_build_my_resource = lambda {
    _spec = res.MyResourceSpec { name = "test", namespace = "ns" }
    _result = res.build_my_resource(_spec)
    assert _result.metadata.name == "test"
    assert _result.kind == "MyResource"
}
```

### 3.2 Creating a New Template

Templates compose multiple builders into a high-level module:

```kcl
# framework/templates/my_template.k
import models.modules.component as component
import builders.deployment as deploy
import builders.service as svc
import builders.leader as leader

schema MyModule(component.Component):
    port: int
    serviceType: str = "ClusterIP"

    _deployment = deploy.build_deployment(deploy.DeploymentSpec {
        name = name; namespace = namespace; image = image; version = version
        port = port
    })
    _service = svc.build_service(svc.ServiceSpec {
        name = name; namespace = namespace; port = port
        serviceType = serviceType
    })
    _leader = leader.build_component_leader(name, namespace)

    kind = "APPLICATION"
    leaders = [_leader]
    manifests = [_deployment, _service]
```

### 3.3 Adding a New Output Procedure

```kcl
# framework/procedures/kcl_to_<format>.k
import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace

generate_<format>_from_stack = lambda components, accessories, namespaces, stack_name, version -> any {
    # Transform stack structures into target format
    # Return serializable output
}
```

Currently supported output procedures:
- `kcl_to_yaml` — Plain K8s YAML (for ArgoCD/GitOps)
- `kcl_to_argocd` — ArgoCD Application CRDs
- `kcl_to_helm` — Helm Chart.yaml + values.yaml
- `kcl_to_helmfile` — helmfile.yaml
- `kcl_to_kustomize` — kustomization.yaml
- `kcl_to_kusion` — Kusion spec
- `kcl_to_timoni` — Timoni CUE module structure (experimental)

### 3.4 Importing Operator CRDs

```bash
# 1. Download CRDs from operator
kubectl get crds -o yaml | grep "group: <operator-group>" > /tmp/crds.yaml

# 2. Import to KCL schemas
kcl import --mode crd -f /tmp/crds.yaml -o framework/custom/<operator>/models/

# 3. Create a template wrapping the CRDs with sensible defaults
# 4. Write tests for the new template
# 5. Update kcl.mod if new dependencies are needed
```

### 3.5 Maintaining the Module System

```bash
# Run full test suite
cd framework && kcl test ./...

# Validate all projects compile
cd projects/erp_back/pre_releases/manifests/dev/factory && kcl run render.k | kubeconform -summary

# After adding dependencies, delete lock file and re-resolve
rm kcl.mod.lock && kcl run main.k
```

### 3.6 Low-Level PE Checklist for New Features

- [ ] Create builder with `check` blocks
- [ ] Write `*_test.k` file with tests for valid and invalid inputs
- [ ] Run `kcl test ./...` — all tests must pass
- [ ] Run `kubeconform` on at least one project's output
- [ ] Update `framework-builders.instructions.md` if new builder
- [ ] Update `copilot-instructions.md` directory mapping if new directory
- [ ] Update `IDP_EVOLUTION_PLAN.md` implementation progress if completing a planned item
