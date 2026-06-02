# Workflows

> The single guide to working in idp-concept, organized two ways:
>
> - **[Part A — Workflows by role](#part-a--workflows-by-role)**: what each user profile does,
>   how, and what they should never touch.
> - **[Part B — Step-by-step task guides](#part-b--step-by-step-task-guides)**: concrete,
>   copy-paste recipes for rendering, adding modules/tenants/sites/releases, Crossplane, and
>   debugging.
>
> Prerequisites and installation live in [TOOLING_SETUP.md](./TOOLING_SETUP.md). The only
> interface is the Go `koncept` CLI; see the
> [distribution & sharing model](./decisions/DISTRIBUTION_AND_SHARING_MODEL.md).

---

# Part A — Workflows by role

Developer-oriented documentation for each of the three user profiles. Each section describes
**what the user does**, **how they do it**, and **what they should never need to know**.

## 1. Developer Workflow

**Goal**: Deploy and configure applications with zero Kubernetes knowledge.

### 1.1 Day-to-Day Commands

```bash
# 1. Navigate to your release
cd projects/my-project/pre_releases/manifests/dev/factory

# 2. Validate configuration (catch errors before rendering)
koncept validate

# 3. Preview merged config + dependency orchestration safely
koncept dry-run                # output/dry_run_plan.yaml (Helmfile + Crossplane-aware)

# 4. Render manifests for GitOps
koncept render argocd          # Plain K8s YAML → commit to Git → ArgoCD syncs

# 5. Render Helm charts for environment customization
koncept render helmfile        # Helm charts + values.yaml + helmfile.yaml

# 6. Render Kustomize overlays
koncept render kustomize       # kustomization.yaml + manifest files

# 7. Render Timoni CUE module (experimental)
koncept render timoni          # Timoni module structure

# 8. Generate Kusion spec
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

The Go CLI is the guided path. It scaffolds a complete, validating
project and lets you grow it environment-by-environment and release-by-release —
no manual file copying.

```bash
# 1. Scaffold a complete, validating webapp project (kernel → profile → tenant →
#    site → dev pre-release factory). Renders Tier-1 output out of the box.
koncept init project my-new-project
cd projects/my_new_project

# 2. Add infrastructure or extra apps with templates (prints paste-ready wiring).
koncept init module postgres my-db
koncept init module redis my-cache

# 3. Add more environments (profile + site + pre-release factory).
#    Presets: dev|development, stg|staging, prod|production. Any other name works too.
koncept init env staging
koncept init env prod

# 4. Cut an immutable, version-pinned release (versioned stack + production site +
#    releases/<version>_production/factory). Repeatable for v1_0_0, v2_0_0, ...
koncept init release 1.0.0

# 5. Validate, render, and policy-check any factory the commands print for you.
koncept validate  --factory pre_releases/manifests/stg/factory
koncept render argocd --factory pre_releases/manifests/stg/factory
koncept policy check --factory pre_releases/manifests/stg/factory
```

Notes:

- Generators never overwrite existing files; shared release files (production
  site, `releases/kcl.mod`) are reused across versions.
- New environments default to `local-path` storage so they render/apply on a
  laptop or kind cluster immediately; harden storage class and HA for real
  staging/production.

**Manual fallback (reference):** the `erp_back` project is the canonical hand-authored
layout if you need full control.

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
import framework.templates.webapp.v1_0_0.webapp as webapp
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
import framework.templates.postgresql.v1_0_0.postgresql as pg

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

---

# Part B — Step-by-step task guides

Concrete recipes for common tasks. All commands assume the `koncept` CLI is installed (see
[TOOLING_SETUP.md](./TOOLING_SETUP.md)).

## Planning with Dry-Run (Helmfile + Crossplane)

### When to Use
Preview merged configuration and dependency orchestration before producing deployable output.

### Steps

1. Navigate to a release or pre-release factory directory.

2. Run dry-run:
```bash
koncept dry-run
```

3. Inspect `output/dry_run_plan.yaml`:
   - `spec.mergedConfigurations`: final merged kernel/profile/tenant/site values.
   - `spec.dependencies`: explicit dependency edges between modules.
   - `spec.outputs.helmfile.releases[*].needs`: Helmfile orchestration view.
   - `spec.outputs.crossplane.sequencerRules`: Crossplane V2 ordering contract.

### Why this matters
This is the recommended first gate for Helmfile/Crossplane changes: verify dependency identity and ordering here before `koncept render helmfile` or `koncept render crossplane`.

## 4. Rendering Plain YAML (ArgoCD/GitOps)

### When to Use
Generate plain Kubernetes YAML manifests for GitOps workflows (ArgoCD, Flux) or direct `kubectl apply`.

### Steps

1. Navigate to a pre_release generator directory:
```bash
cd projects/video_streaming/pre_releases/manifests/site_one/generators/kafka_video_consumer_mongodb_python/dev
```

2. Render:
```bash
koncept render argocd
```

3. Output is written to `../../../generated/dev/kafka_video_consumer_mongodb_python/kubernetes_manifests.yaml`

### What Happens Internally
```
factory/factory_seed.k
  → Imports configurations_dev.k (merges kernel + profile + tenant + site)
  → Creates RenderStack with specific components/namespaces

factory/kubernetes_manifests_builder.k
  → Calls kcl_to_yaml.yaml_stream_stack(stack)
  → Outputs multi-document YAML
```

### Alternative: Manual KCL Execution
```bash
kcl run factory/kubernetes_manifests_builder.k -o output/manifests.yaml
```

---

## 5. Rendering Helmfile Output

### When to Use
Generate Helm charts and helmfile.yaml for Helmfile-based deployments.

### Steps

1. Navigate to a release directory:
```bash
cd projects/video_streaming/releases/helmfile/berlin/v1_0_0_berlin
```

2. Render:
```bash
koncept render helmfile
```

3. Output structure:
```
output/
├── charts/
│   ├── Chart.yaml          # Generated from chart_builder.k
│   ├── values.yaml         # Empty (placeholder)
│   └── templates/
│       └── manifests.yaml  # Generated from templates_builder.k
└── helmfile.yaml            # Generated from helmfile_builder.k
```

### What Happens Internally
```
factory/factory_seed.k → Release context setup
factory/chart_builder.k → Chart metadata (imports helm.Chart schema)
factory/templates_builder.k → K8s manifests (calls kcl_to_helm)
factory/render.k → kcl_to_helmfile.generate_helmfile_from_stack(stack, "./charts")
```

### Configuring the generated Helmfile

Helmfile output is configurable from the KCL stack via `custom.helmfile.helmfile.HelmfileRenderOptions`. This keeps KCL as the source of truth while exposing Helmfile-native settings.

```kcl
import framework.custom.helmfile.helmfile as hf

_stack = renderstack.RenderStack {
    instanceConfigurations = instanceConfigurations
    components = [_api]
    accessories = [_postgres]
    helmfile = hf.HelmfileRenderOptions {
        chartBasePath = "./charts"
        repositories = [hf.Repository {name = "bitnami", url = "https://charts.bitnami.com/bitnami"}]
        environments = {dev = hf.Environment {values = ["environments/dev.yaml"]}}
        helmDefaults = hf.HelmDefaults {wait = True, timeout = 600, atomic = True}
        releaseDefaults = hf.ReleasePatch {createNamespace = True, wait = True}
        releaseOverrides = {
            api = hf.ReleasePatch {
                namespace = "apps"
                values = ["values/api.yaml", {replicaCount = 2}]
                needs = ["data/postgres"]
            }
        }
        extraReleases = [hf.Release {name = "metrics-server", namespace = "kube-system", chart = "bitnami/metrics-server", version = "7.2.0"}]
    }
}
```

Use `releaseOverrides` to customize generated module releases and `extraReleases` for releases that are part of the Helmfile but not generated from a KCL module. Use `includeGeneratedReleases = False` for a Helmfile that is entirely hand-authored in KCL.

Generated Helmfile releases also translate framework `dependsOn` relationships between components and accessories into Helmfile `needs` entries using `namespace/name` format. The renderer resolves those `needs` entries against the dependency release identity after applying `releaseDefaults` and dependency-specific `releaseOverrides` (for example renamed releases or overridden namespaces). Namespace-only dependencies are omitted because they are handled by `createNamespace`; use `releaseOverrides.<name>.needs` when an operator needs to replace the generated dependency list.

---

## 6. Rendering Kusion Spec

### When to Use
Generate Kusion specification YAML for Kusion-based deployments.

### Steps

1. Navigate to a release directory:
```bash
cd projects/video_streaming/releases/kusion/berlin/v1_0_0_berlin/default
```

2. Render:
```bash
koncept render kusion
```

3. Output: `output/kusion_spec.yaml`

4. Preview and apply:
```bash
kusion preview --spec-file output/kusion_spec.yaml
kusion apply --spec-file output/kusion_spec.yaml
```

### What Happens Internally
```
factory/main.k
  → Merges configurations (kernel + profile + tenant + site)
  → Creates Stack with merged configs
  → Creates Release (which auto-computes kusionSpec)
  → Outputs kusion_spec.yaml with KusionResource entries
```

> For the recommended per-environment rendering strategy (Kustomize for dev, Crossplane v2 for
> the variable stack), see
> [RENDERING_STRATEGY_DECISION.md](./decisions/RENDERING_STRATEGY_DECISION.md).

---

## 7. Adding a New Application Module

### Scenario
Add a new REST API service called `order-api`.

### Steps (Recommended — Using Templates)

1. **Create module directory**:
```
projects/<project>/modules/appops/order_api/
```

2. **Create module definition** (`order_api_module_def.k`):
```kcl
import framework.templates.webapp.v1_0_0.webapp as webapp
import framework.builders.deployment as deploy

schema OrderApiModule(webapp.WebAppModule):
    port = 8080
    serviceType = "ClusterIP"
    replicas = 2
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
    env = [
        { name = "SPRING_PROFILES_ACTIVE", value = "dev" }
        { name = "DB_PASSWORD", valueFrom = { secretKeyRef = { name = "db-creds", key = "password" } } }
    ]

order_api = OrderApiModule {
    name = "order-api"
    namespace = "apps"
    image = "ghcr.io/org/order-api"
    version = "1.0.0"
}
```

3. **Add to stack definition** (`stacks/development/stack_def.k`):
```kcl
import <project>.modules.appops.order_api as order_api

# Inside the stack schema:
_order_api = order_api.OrderApiModule {
    name = "order-api"
    namespace = _apps_namespace.name
    image = "ghcr.io/org/order-api"
    version = instanceConfigurations.orderApiVersion
    configurations = instanceConfigurations
    dependsOn = [_apps_namespace]
}.instance

components = [
    _order_api  # ← Add here
]
```

4. **Validate**: `cd pre_releases && kcl run manifests/dev/factory/render.k -D output=yaml | kubeconform -summary`

---

## 8. Adding an Infrastructure Module (Operator-Managed)

### Scenario

Add a PostgreSQL database using CloudNativePG operator.

### Steps

1. **Create module directory**:
```
projects/<project>/modules/infrastructure/postgres/
```

2. **Create module definition** (`postgres_module_def.k`):
```kcl
import framework.templates.postgresql.v1_0_0.postgresql as pg

schema ProjectPostgresModule(pg.PostgreSQLClusterModule):
    instances = 3
    storageSize = "50Gi"
    pgVersion = "16"
    monitoring = True

project_postgres = ProjectPostgresModule {
    name = "project-db"
    namespace = "data"
}
```

3. **Add to stack** as an accessory:
```kcl
accessories = [
    _postgres.instance
]
```

### Available Infrastructure Templates

| Need | Template | Example |
|---|---|---|
| PostgreSQL | `postgresql.PostgreSQLClusterModule` | `instances = 3`, `storageSize = "50Gi"` |
| MongoDB | `mongodb.MongoDBCommunityModule` | `members = 3`, `version = "7.0.14"` |
| RabbitMQ | `rabbitmq.RabbitMQClusterModule` | `replicas = 3`, `storageSize = "10Gi"` |
| Redis | `redis.RedisModule` | `mode = "cluster"`, `clusterSize = 3` |
| Kafka | `kafka.KafkaClusterModule` | `clusterName = "my-kafka"`, topics config |
| Keycloak | `keycloak.KeycloakModule` | `instances = 2`, `hostname = "auth.example.com"` |
| OpenSearch | `opensearch.OpenSearchClusterModule` | `nodePools` with roles/sizes |
| Vault secrets | `vault.VaultStaticSecretModule` | `mount = "secret"`, `path = "my-app/config"` |
| QuestDB | `questdb.QuestDBModule` | `storageSize = "100Gi"` |

---

## 9. Adding a New Tenant

### Scenario
Add a new tenant called "France".

### Steps

1. **Create tenant directory and files**:
```
projects/video_streaming/tenants/france/
├── tenant_configurations.k
└── tenant_def.k
```

2. **tenant_configurations.k**:
```kcl
import video_streaming.core_sources.video_streaming_configurations as configurations

_france_tenant_configurations = configurations.VideoStreamingConfigurations {
    brandIcon = "🇫🇷"
}
```

3. **tenant_def.k**:
```kcl
import framework.models.tenant

tenant_france = tenant.Tenant {
    name = "France"
    description = "Government of France"
    configurations = _france_tenant_configurations
}
```

---

## 10. Adding a New Site

### Scenario
Add a Paris production site for the France tenant.

### Steps

1. **Create site directory**:
```
projects/video_streaming/sites/tenants/production/paris/
├── configurations.k
├── config.yaml
└── site_def.k
```

2. **config.yaml**:
```yaml
site:
  name: Paris
rootPaths:
  localOpensearch: "http://opensearch.opensearch"
  centralOpensearch: "https://central-services/opensearch"
  keycloak: "keycloak.keycloak/realm/auth"
```

3. **configurations.k**:
```kcl
import video_streaming.core_sources.video_streaming_configurations

_paris_site_configurations = video_streaming_configurations.VideoStreamingConfigurations {
    siteName = "Paris"
    rootPaths = {
        "local opensearch": "http://opensearch.opensearch"
    }
}
```

4. **site_def.k**:
```kcl
import framework.models.site
import video_streaming.tenants.france
import video_streaming.core_sources.video_streaming_configurations
import video_streaming.sites.tenants.production.paris.configurations

paris_site = site.Site {
    name = "Paris"
    tenant = france.tenant_france
    configurations = video_streaming_configurations.VideoStreamingConfigurations {
        **configurations._paris_site_configurations
    }
}
```

---

## 11. Creating a New Versioned Release

### Scenario
Create release v1.0.0 for Paris.

### Steps

1. **Create release directory for helmfile**:
```
projects/video_streaming/releases/helmfile/paris/v1_0_0_paris/factory/
```

2. **Copy factory files from berlin** and update:
   - `factory_seed.k` — Change imports to use Paris site and France tenant
   - `chart_builder.k` — Same (reuse)
   - `templates_builder.k` — Same (reuse)
   - `helmfile_builder.k` — Same (reuse)
   - `main.k` — Update release name and references

3. **Create release directory for kusion** (similar pattern):
```
projects/video_streaming/releases/kusion/paris/v1_0_0_paris/default/factory/
```

---

## 12. Deploying Crossplane Resources

> For the strategic role of Crossplane v2 in the platform, see
> [RENDERING_STRATEGY_DECISION.md](./decisions/RENDERING_STRATEGY_DECISION.md) and
> [CROSSPLANE_PATTERNS.md](./CROSSPLANE_PATTERNS.md).

### Install Crossplane Functions
```bash
kubectl apply -f crossplane_v2/functions/
```

### Install Providers
```bash
kubectl apply -f crossplane_v2/providers/kubernetes_provider/
kubectl apply -f crossplane_v2/providers/helm_provider/
```

### Deploy PostgreSQL
```bash
kubectl apply -f crossplane_v2/managed_resources/postgres/xrd_postgres.yaml
kubectl apply -f crossplane_v2/managed_resources/postgres/x_postgres.yaml
kubectl apply -f crossplane_v2/managed_resources/postgres/xr_instance_postgres.yaml
```

### Deploy cert-manager
```bash
kubectl apply -f crossplane_v2/managed_resources/cert_manager/xrd_cert_manager.yaml
kubectl apply -f crossplane_v2/managed_resources/cert_manager/x_cert_manager.yaml
kubectl apply -f crossplane_v2/managed_resources/cert_manager/xr_instance_cert_manager.yaml
```

### Deploy Kafka (Strimzi)
```bash
kubectl apply -f crossplane_v2/managed_resources/kafka_strimzi/crossplane_xrd.yaml
kubectl apply -f crossplane_v2/managed_resources/kafka_strimzi/crossplane_x.yaml
kubectl apply -f crossplane_v2/managed_resources/kafka_strimzi/crossplane_claim.yaml
```

### Deploy Keycloak
```bash
# Pre-requisite: PostgreSQL must be running
kubectl apply -f crossplane_v2/managed_resources/keycloak/crossplane/xrd_keycloak.yaml
kubectl apply -f crossplane_v2/managed_resources/keycloak/crossplane/x_keycloak.yaml
kubectl apply -f crossplane_v2/managed_resources/keycloak/crossplane/xr_instance_keycloak.yaml
```

---

## 13. Debugging KCL Compilation Errors

### Common Error: "type redefinition"
```
KCL Compile Error: type redefinition
```
**Fix**: You used `type` as a field name. Use `$type` instead.

### Common Error: "attribute not found"
```
EvaluationError: attribute 'xyz' not found in schema
```
**Fix**: Check the schema definition — the field may be named differently or be optional.

### Common Error: "invalid import"
```
CannotFindModule: Cannot find module 'xxx'
```
**Fix**: Check `kcl.mod` — ensure the dependency path is correct relative to the `kcl.mod` file.

### Debug Command
```bash
# Run with verbose output
kcl run main.k -v

# Check module resolution
kcl mod metadata
```
