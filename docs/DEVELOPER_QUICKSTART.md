# Developer Quickstart

> Deploy and manage your applications using the **koncept** CLI — zero Kubernetes knowledge required.

## Prerequisites

- [KCL](https://www.kcl-lang.io/docs/user_docs/getting-started/install) (v0.11+)
- [Nushell](https://www.nushell.sh/book/installation.html) (v0.90+)
- [kubeconform](https://github.com/yannh/kubeconform) (optional, for validation)

## Quick Commands

```bash
# Navigate to your environment directory
cd projects/<project>/pre_releases/manifests/<env>/

# Validate configuration (catches errors before rendering)
koncept validate

# Render manifests
koncept render argocd          # Plain K8s YAML for GitOps deployment
koncept render helmfile        # Helm charts + helmfile.yaml
koncept render kusion          # Kusion spec
koncept render kustomize       # Kustomize base with kustomization.yaml

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

### ArgoCD (plain YAML)
Best for GitOps workflows. Generates Kubernetes manifests + ArgoCD Application CRDs.
```bash
koncept render argocd
```

### Helmfile
Generates parameterized Helm charts with `values.yaml` + `helmfile.yaml`.
```bash
koncept render helmfile
# Output: output/charts/<name>/Chart.yaml, values.yaml, templates/
#         output/helmfile.yaml
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
