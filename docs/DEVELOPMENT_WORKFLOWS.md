# Development Workflows

> Step-by-step guides for common development tasks in idp-concept.

---

## 1. Prerequisites

### Required Tools

| Tool | Install | Verify |
|---|---|---|
| KCL | https://www.kcl-lang.io/docs/user_docs/getting-started/install | `kcl version` |
| Nushell | https://www.nushell.sh/book/installation.html | `nu --version` |
| go-task | https://taskfile.dev/installation/ | `task --version` |
| kubectl | https://kubernetes.io/docs/tasks/tools/ | `kubectl version` |
| Helm | https://helm.sh/docs/intro/install/ | `helm version` |
| Helmfile | https://helmfile.readthedocs.io/en/latest/#installation | `helmfile --version` |
| Kusion | https://www.kusionstack.io/docs/getting-started/install | `kusion version` |

### Setup CLI

```bash
chmod +x platform_cli/koncept
mkdir -p ~/.local/bin
ln -s $(pwd)/platform_cli/koncept ~/.local/bin/koncept
```

---

## 2. Rendering Plain YAML (ArgoCD/GitOps)

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

## 3. Rendering Helmfile Output

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
factory/helmfile_builder.k → Helmfile config (imports helmfile.Helmfile schema)
```

---

## 4. Rendering Kusion Spec

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

---

## 5. Adding a New Application Module

### Scenario
Add a new REST API service called `order-api`.

### Steps (Recommended — Using Templates)

1. **Create module directory**:
```
projects/<project>/modules/appops/order_api/
```

2. **Create module definition** (`order_api_module_def.k`):
```kcl
import framework.templates.webapp as webapp
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

## 6. Adding an Infrastructure Module (Operator-Managed)

### Scenario

Add a PostgreSQL database using CloudNativePG operator.

### Steps

1. **Create module directory**:
```
projects/<project>/modules/infrastructure/postgres/
```

2. **Create module definition** (`postgres_module_def.k`):
```kcl
import framework.templates.postgresql as pg

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

## 7. Adding a New Tenant

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

## 8. Adding a New Site

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

## 9. Creating a New Versioned Release

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

## 10. Deploying Crossplane Resources

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

## 11. Debugging KCL Compilation Errors

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
