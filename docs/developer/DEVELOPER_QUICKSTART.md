# Developer Quickstart

> Deploy and manage your applications using the **koncept** CLI — zero Kubernetes knowledge required. For every command and flag, use [CLI_REFERENCE.md](./CLI_REFERENCE.md).

## Prerequisites

> **Full installation guide with local vs global options, pros/cons, and mise version locking**: [TOOLING_SETUP.md](../operations/TOOLING_SETUP.md)

| Tool | Purpose | Required | Install |
|---|---|---|---|
| `koncept` Go CLI | Primary developer interface for scaffold/render/validate/policy workflows | **Yes** | See [TOOLING_SETUP.md](../operations/TOOLING_SETUP.md#koncept-go-cli) |
| [KCL](https://www.kcl-lang.io/docs/user_docs/getting-started/install) (`kcl`) | Direct KCL troubleshooting and local test runs | Recommended | See [TOOLING_SETUP.md](../operations/TOOLING_SETUP.md#kcl) |
| [kubeconform](https://github.com/yannh/kubeconform) | Validates K8s manifests | Recommended | See [TOOLING_SETUP.md](../operations/TOOLING_SETUP.md#kubeconform) |
| [Helm](https://helm.sh/docs/intro/install/) | Lints Helm chart output | Optional | See [TOOLING_SETUP.md](../operations/TOOLING_SETUP.md#helm) |

## Quick Commands

```bash
# Navigate to your project root and pass the factory path
cd projects/<project>/

# Validate configuration (catches errors before rendering)
koncept validate --factory pre_releases/manifests/<env>/factory

# Render manifests (pick the format your team uses)
koncept render yaml --factory pre_releases/manifests/<env>/factory        # Tier 1 plain YAML
koncept render argocd --factory pre_releases/manifests/<env>/factory      # Tier 1 ArgoCD/GitOps YAML
koncept render helmfile --factory pre_releases/manifests/<env>/factory    # Tier 1 Helmfile
koncept render backstage --factory pre_releases/manifests/<env>/factory   # Tier 1 catalog metadata
koncept render helm --factory pre_releases/manifests/<env>/factory        # Tier 2 Helm chart
koncept render crossplane --factory pre_releases/manifests/<env>/factory  # Platform-team path
koncept render kustomize --factory pre_releases/manifests/<env>/factory   # Tier 2 Kustomize
koncept render kusion --factory pre_releases/manifests/<env>/factory      # Tier 3 experimental
koncept render timoni --factory pre_releases/manifests/<env>/factory      # Tier 3 experimental

# Navigate to a production release
cd projects/<project>/releases/<version>/

# Same commands work for releases
koncept validate
koncept render argocd
```

## Project Structure

```
projects/<your-project>/
├── kernel/               # Project definition (name, base config)
├── core_sources/         # Config schema + merge function
├── modules/              # Application & infrastructure definitions
├── stacks/
│   ├── development/      # Dev/stg stack (what to deploy)
│   └── versioned/v1_0_0/ # Pinned production versions
├── tenants/              # Customer-specific overrides
├── sites/
│   ├── development/      # Dev/stg cluster configs
│   └── production/       # Production site configs
├── pre_releases/         # Development environments
│   ├── configurations_dev.k
│   ├── configurations_stg.k
│   └── manifests/
│       ├── dev/factory/  # Dev factory (factory_seed.k + render.k)
│       └── stg/factory/  # Stg factory (factory_seed.k + render.k)
└── releases/             # Versioned production releases
    └── v1_0_0_production/factory/
```

## What You Can Configure

As a developer, you interact with **site** and **tenant** configuration files:

| Setting | Where | Example |
|---|---|---|
| Replicas | Site config | `replicas = 3` |
| Resource limits | Site config | `cpuLimit = "4"` |
| Environment variables | Site config | `springProfile = "staging"` |
| Feature flags | Tenant config | `featureX = True` |

## What You Should NOT Edit

- `framework/` — Core platform schemas (contact platform engineers)
- `modules/` — Module definitions (contact platform engineers)
- `render.k` — Generic renderer (auto-managed)
- `koncept.yaml` — Project CLI/framework metadata; update through platform-approved versioning changes

## Available Infrastructure Services

The platform provides pre-built templates for common infrastructure. Ask your platform engineer to add these to your stack:

| Service | Template | What It Deploys |
|---|---|---|
| **PostgreSQL** | `PostgreSQLClusterModule` | CloudNativePG cluster with HA, backups, connection pooling |
| **MongoDB** | `MongoDBCommunityModule` | MongoDB replica set via Community Operator |
| **Kafka** | `KafkaClusterModule` | Strimzi Kafka cluster with topics |
| **RabbitMQ** | `RabbitMQClusterModule` | RabbitMQ cluster with custom plugins/config |
| **Redis** | `RedisModule` | Standalone or cluster mode via OT Redis Operator |
| **Keycloak** | `KeycloakModule` | Keycloak identity server with realm import |
| **OpenSearch** | `OpenSearchClusterModule` | Search/analytics with dashboards |
| **Vault** | `VaultStaticSecretModule` | Sync secrets from HashiCorp Vault → K8s Secrets |
| **QuestDB** | `QuestDBModule` | Time-series database via Helm chart |
| **MinIO** | `MinIOTenantSpec` / `MinIOHelmSpec` | S3-compatible object storage (Operator CRD or Bitnami Helm) |

These are configured in `modules/` by platform engineers — you control environment-specific settings (replicas, storage size) via site configurations.

## Each Factory Has Only 2 Files

| File | Purpose | Who Writes It |
|---|---|---|
| `factory_seed.k` | Points to configurations, sets up the stack | Platform engineer (once per env) |
| `render.k` | Generic multi-format renderer | Framework-provided (identical everywhere) |

## Render Formats

### YAML / ArgoCD
Best for GitOps workflows. `yaml` and `argocd` both produce plain Kubernetes manifests suitable for ArgoCD or Flux-style deployment.
```bash
koncept render yaml
koncept render argocd
```

### Helmfile
Generates parameterized Helm charts with `values.yaml` + `helmfile.yaml`.
```bash
koncept render helmfile
# Output: output/charts/<name>/Chart.yaml, values.yaml, templates/
#         output/helmfile.yaml
```

### Helm
Generates standalone Helm chart structure.
```bash
koncept render helm
```

### Kusion
Generates Kusion spec with resources and dependency ordering.
```bash
koncept render kusion
```

### Kustomize
Generates a Kustomize base directory with `kustomization.yaml` and individual resource files.
```bash
koncept render kustomize
# Output: output/base/kustomization.yaml
#         output/base/<kind>-<name>.yaml
```

### Timoni
Generates CUE-based Timoni bundle manifests.
```bash
koncept render timoni
```

### Crossplane
Generates Crossplane-compatible YAML for managed resources.
```bash
koncept render crossplane
```

### Backstage
Generates Backstage catalog entity definitions from component/accessory metadata.
```bash
koncept render backstage
```

> **All 9 formats** are rendered from the same KCL source — change one config, re-render any format. Prefer Tier 1 (`yaml`, `argocd`, `helmfile`, `backstage`) unless your platform team has chosen another path.

For framework compatibility metadata and support windows, see [FRAMEWORK_VERSIONING.md](../platform-engineering/FRAMEWORK_VERSIONING.md).

## Validation

Always validate before rendering:
```bash
koncept validate
# ✅ Configuration is valid
# OR
# ❌ Validation failed: <error details>
```

## Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| `cannot find module` | Wrong directory | `cd` to the directory with `kcl.mod` |
| `attribute not found` | Spelling error in config | Check field names in `core_sources/` |
| `check block failed` | Invalid value (e.g., port out of range) | Fix the value per the error message |

For deeper troubleshooting, run `koncept doctor --factory <factory>` and then see [CLI_REFERENCE.md](./CLI_REFERENCE.md#troubleshooting).
