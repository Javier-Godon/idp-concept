# idp-concept

An **Internal Developer Platform** (IDP) that uses [KCL](https://www.kcl-lang.io/) as a single source of truth to generate Kubernetes deployment manifests in **9 output formats** — so you never lock into one deployment tool.

## Why?

Teams get locked into specific tools (Helm, Kustomize, etc.). When requirements change — adopting GitOps, switching to Crossplane, adding Backstage — everything must be rewritten.

**idp-concept** solves this: define your applications and infrastructure **once** in KCL, then render to whatever format you need.

## Output Formats

| Format | Command | Use Case |
|---|---|---|
| **ArgoCD** | `koncept render argocd` | Plain YAML for GitOps deployment |
| **Helm** | `koncept render helm` | Standard Helm charts |
| **Helmfile** | `koncept render helmfile` | Helm charts + helmfile.yaml |
| **Kusion** | `koncept render kusion` | Kusion spec with dependency ordering |
| **Kustomize** | `koncept render kustomize` | Kustomize bases |
| **Timoni** | `koncept render timoni` | CUE-based Timoni bundles |
| **Crossplane** | `koncept render crossplane` | Crossplane managed resources |
| **Backstage** | `koncept render backstage` | Backstage catalog entities |
| **YAML** | `koncept render yaml` | Raw multi-document YAML |

## How It Works

```
 Define once                    Render to any format
┌──────────────┐               ┌─────────────────────┐
│  KCL schemas │──→ factory ──→│  argocd / helm /    │
│  (your apps) │               │  helmfile / kusion / │
└──────────────┘               │  kustomize / timoni /│
       ↑                       │  crossplane / ...    │
  Config layers                └─────────────────────┘
  kernel → profile
  → tenant → site
```

**Configuration layers** merge in order — each layer can override the previous:

1. **Kernel** — project-wide defaults (ports, image names)
2. **Profile** — stack/version settings (which modules to deploy)
3. **Tenant** — customer-specific overrides (feature flags)
4. **Site** — environment-specific overrides (replicas, resources, URLs)

## Quick Start

### 1. Install Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| [Nushell](https://www.nushell.sh/) (`nu`) | Runs `koncept` CLI | [TOOLING_SETUP.md](docs/TOOLING_SETUP.md#nushell) |
| [KCL](https://www.kcl-lang.io/) (`kcl`) | Renders configurations | [TOOLING_SETUP.md](docs/TOOLING_SETUP.md#kcl) |

### 2. Set Up the CLI

```bash
chmod +x platform_cli/koncept
mkdir -p ~/.local/bin
ln -s "$(pwd)/platform_cli/koncept" ~/.local/bin/koncept
```

### 3. Render Manifests

```bash
# Navigate to any pre-release or release environment
cd projects/erp_back/pre_releases/manifests/dev/

# Render plain YAML (ArgoCD-ready)
koncept render argocd

# Or any other format
koncept render helmfile
koncept render kusion
koncept render kustomize
```

### 4. Run Tests

```bash
cd framework && kcl test ./...
```

## Project Structure

```
idp-concept/
├── framework/           # Reusable platform engine (models, builders, templates, procedures)
│   ├── models/          #   Domain schemas (Project, Tenant, Site, Stack, Component, Accessory)
│   ├── builders/        #   Manifest builder lambdas (deployment, service, configmap, etc.)
│   ├── templates/       #   Module templates (WebApp, PostgreSQL, Kafka, Redis, etc.)
│   ├── procedures/      #   Output format converters (kcl_to_yaml, kcl_to_helm, etc.)
│   ├── factory/         #   Factory scaffolding (FactorySeed, render)
│   ├── assembly/        #   Stack helpers (namespace creation)
│   └── tests/           #   Framework test suite
├── projects/            # Your applications
│   ├── erp_back/        #   Example project (template approach — recommended)
│   └── video_streaming/ #   Example project (raw approach — full control)
├── platform_cli/        # Nushell CLI tools (koncept, koncepttask)
├── crossplane_v2/       # Crossplane XRDs, Compositions, Providers
└── docs/                # Documentation
```

## 17 Built-In Templates

Templates auto-generate Kubernetes manifests — Deployment, Service, ConfigMap, PV/PVC, leaders, and dependency tracking — from a few configuration fields.

| Template | What It Deploys |
|---|---|
| `WebAppModule` | Web application (Deployment + Service + ConfigMap) |
| `SingleDatabaseModule` | Database with persistent storage |
| `PostgreSQLClusterModule` | CloudNativePG HA cluster |
| `MongoDBCommunityModule` | MongoDB replica set |
| `KafkaClusterModule` | Strimzi Kafka cluster with topics |
| `RabbitMQClusterModule` | RabbitMQ cluster |
| `RedisModule` | Redis standalone or cluster |
| `KeycloakModule` | Keycloak identity server |
| `OpenSearchClusterModule` | OpenSearch with dashboards |
| `VaultStaticSecretModule` | Vault → K8s secret sync |
| `QuestDBModule` | QuestDB time-series database |
| `MinIOTenantSpec` / `MinIOHelmSpec` | S3-compatible object storage |
| `ObservabilityModule` | Prometheus + Grafana stack |
| `OpenTelemetryModule` | OpenTelemetry collector |

## Two Approaches to Define Modules

### Template Approach (Recommended)

Inherit from a framework template — 80-90% less boilerplate:

```kcl
import framework.templates.webapp as webapp

schema MyApp(webapp.WebAppModule):
    port = 8080
    # Deployment, Service, ConfigMap, leaders auto-generated
```

### Raw Approach (Full Control)

Build manifests directly using framework builders:

```kcl
import framework.models.modules.component as component
import framework.builders.deployment as dep

schema MyApp(component.Component):
    kind = "APPLICATION"
    leaders = [component.ComponentLeader { name = name, ... }]
    manifests = [dep.build_deployment(dep.DeploymentSpec { ... })]
```

See [projects/erp_back/](projects/erp_back/) for the template approach and [projects/video_streaming/](projects/video_streaming/) for the raw approach.

## Documentation

| Document | Audience | Content |
|---|---|---|
| [DEVELOPER_QUICKSTART](docs/DEVELOPER_QUICKSTART.md) | Developers | Day-to-day usage, render commands, config options |
| [PROJECT_ARCHITECTURE](docs/PROJECT_ARCHITECTURE.md) | All | Architecture, data flow, how everything connects |
| [FRAMEWORK_SCHEMAS](docs/FRAMEWORK_SCHEMAS.md) | Platform engineers | Complete schema reference |
| [DEVELOPER_GUIDE](docs/DEVELOPER_GUIDE.md) | Platform engineers | How to extend the framework |
| [TESTING_STRATEGY](docs/TESTING_STRATEGY.md) | Contributors | Testing patterns and conventions |
| [TOOLING_SETUP](docs/TOOLING_SETUP.md) | All | Installation and environment setup |
| [SECURITY](docs/SECURITY.md) | All | Security policy and approved tools |
| [PLATFORM_COMPARISON](docs/PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md) | Platform engineers | KCL vs Go, k0rdent/Fleet patterns |

## Technologies

- **[KCL](https://www.kcl-lang.io/)** — Configuration language (CNCF Sandbox)
- **[Nushell](https://www.nushell.sh/)** — CLI scripting
- **[Crossplane](https://www.crossplane.io/)** — Kubernetes-native infrastructure provisioning
- **[ArgoCD](https://argo-cd.readthedocs.io/)** — GitOps continuous delivery

## License

See [LICENSE](LICENSE).


