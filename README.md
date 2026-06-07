# idp-concept

[![Validate KCL Configurations](https://github.com/YOUR_ORG/idp-concept/actions/workflows/validate.yml/badge.svg)](https://github.com/YOUR_ORG/idp-concept/actions/workflows/validate.yml)

An **Internal Developer Platform** (IDP) that uses [KCL](https://www.kcl-lang.io/) as a single source of truth to generate Kubernetes deployment manifests in **9 output formats** — so you never lock into one deployment tool.

## Why?

Teams get locked into specific tools (Helm, Kustomize, etc.). When requirements change — adopting GitOps, switching to Crossplane, adding Backstage — everything must be rewritten.

**idp-concept** solves this: define your applications and infrastructure **once** in KCL, then render to whatever format you need.

## Output Formats

Outputs are organized into **support tiers** so teams know what is production-supported
versus experimental (see the [evolution plan](docs/IDP_EVOLUTION_PLAN.md#51-output-format-sprawl)):

| Tier | Format | Command | Use Case |
|---|---|---|---|
| **Tier 1** | **ArgoCD/YAML** | `koncept render argocd` / `koncept render yaml` | Plain YAML for GitOps deployment — company default |
| **Tier 1** | **Helmfile** 🌟 | `koncept render helmfile` | Helm charts + orchestration — recommended for Helm-native teams |
| **Tier 1** | **Backstage** | `koncept render backstage` | Backstage catalog entities |
| **Tier 2** | **Crossplane** 🌟 | `koncept render crossplane` | Infrastructure-as-code + Kubernetes APIs — recommended for infrastructure provisioning |
| **Tier 2** | **Helm** | `koncept render helm` | Standard Helm charts |
| **Tier 2** | **Kustomize** | `koncept render kustomize` | Kustomize bases |
| **Tier 3** | **Timoni** | `koncept render timoni` | CUE-based Timoni bundles (experimental) |
| **Tier 3** | **Kusion** | `koncept render kusion` | Kusion spec with dependency ordering (experimental) |

**Tier 1** outputs are fully tested and documented for company usage. **Tier 2** are
maintained for platform/infrastructure teams. **Tier 3** are experimental unless adopted
by a real product team. Stack governance metadata is propagated through the supported
native surfaces: Kubernetes annotations/labels for YAML/ArgoCD and Crossplane V2,
Helmfile labels/commonLabels/release labels for Helmfile, and catalog annotations for
Backstage.

### 🚀 Helmfile & Crossplane: Production-Grade Multi-Format Output (June 2026)

**NEW**: Helmfile and Crossplane V2 outputs are now **production-ready** with full governance metadata, deterministic orchestration, and comprehensive acceptance testing. See the **[Helmfile & Crossplane Adoption Guide](docs/HELMFILE_CROSSPLANE_ADOPTION.md)** for detailed adoption patterns.

**When to use each:**
- **Helmfile** (`koncept render helmfile`): Multi-Helm-chart orchestration with dependency management and per-release customization. Ideal for applications already packaged as Helm charts.
- **Crossplane** (`koncept render crossplane`): Infrastructure-as-code via Kubernetes APIs with typed self-service provisioning. Ideal for infrastructure services (databases, message queues, object storage, identity). Includes 12+ curated managed resource APIs.

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
| [Go](https://go.dev/) | Builds the `koncept` CLI | [TOOLING_SETUP.md](docs/TOOLING_SETUP.md) |
| [KCL](https://www.kcl-lang.io/) (`kcl`) | Renders configurations | [TOOLING_SETUP.md](docs/TOOLING_SETUP.md#kcl) |

### 2. Set Up the CLI

The **Go CLI** (`cmd/koncept`) is the single, packaged interface — installed as a
cross-platform binary that every team member runs locally (see
[the distribution & sharing model](docs/decisions/DISTRIBUTION_AND_SHARING_MODEL.md)).

```bash
# Build the Go CLI (requires Go and kcl)
cd cmd/koncept
make build            # produces bin/koncept
make build-all        # cross-compile Linux/macOS/Windows
make checksums        # bin/SHA256SUMS for release artifacts
make docker           # build a pinned CI image (Dockerfile bundles the kcl toolchain)

# Add it to your PATH
ln -s "$(pwd)/bin/koncept" ~/.local/bin/koncept

# Shell completions
koncept completion bash > /etc/bash_completion.d/koncept   # or zsh|fish|powershell
```

### 3. Render Manifests

```bash
# Navigate to any pre-release or release environment
cd projects/erp_back/pre_releases/manifests/dev/

# Render plain YAML (ArgoCD-ready)
koncept render argocd

# Preview merged config + Helmfile/Crossplane orchestration plan first
koncept dry-run

# Or any other format
koncept render helmfile
koncept render kusion
koncept render kustomize
```

### 4. Scaffold, Validate, and Govern

```bash
# Scaffold a complete, validating webapp project skeleton
koncept init project "Inventory Service"
#   → projects/inventory_service/ … renders Tier-1 output out of the box

# Add a module to an existing project and print its stack wiring snippet
koncept init module webapp orders-api
koncept init module postgres orders-db    # also: redis, kafka, mongodb, rabbitmq, database
#   → modules/<area>/<name>/<name>_module_def.k + paste-ready stack wiring

# Or auto-wire the module straight into the project stack (marker-scoped, safe)
koncept init module redis orders-cache --wire
#   → inserts the import, instance block, and accessory list entry; refuses to
#     touch a stack that lacks the koncept wire markers

# Enforce baseline security/ownership policy on rendered manifests
koncept policy check --factory <factory-dir>
#   no privileged containers · no latest/untagged images
#   resource requests+limits on workloads · ownership labels
#   secret-looking env values must use Secret references · explicit namespaces
#   temporary waivers: --exemptions policy-exemptions.yaml

# Other helpers
koncept dry-run           # merged config + dependency graph + Helmfile/Crossplane plan
koncept crossplane test   # Crossplane checks + optional local render/runtime profiles (incl. matrix + plan)
koncept doctor            # dependency, version, path, and factory checks
koncept golden check      # detect render drift against committed golden files
koncept changelog check   # validate release-note fragments in .changes/unreleased
koncept deps              # troubleshoot KCL module resolution
koncept metrics           # summarize opt-in local telemetry (enable with --metrics)
```

> Two golden gates guard rendering: `scripts/golden.sh` for the hand-authored
> `erp_back` reference factories, and `scripts/golden_generated.sh` for what the
> CLI generates (`koncept init project` + `init module --wire` for webapp,
> webapp+postgres, webapp+redis, webapp+kafka). See `docs/GOLDEN_OUTPUTS.md`.


### 5. Run Tests

```bash
./scripts/verify.sh
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
├── cmd/koncept/         # Go CLI (the installable package)
├── crossplane_v2/       # Crossplane XRDs, Compositions, Providers
└── docs/                # Documentation
```

## 20 Built-In Templates

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
| `ValkeySpec` | Valkey cache via HelmRelease |
| `OpenBaoSpec` | OpenBao secrets management via HelmRelease |
| `CephSpec` | Rook Ceph operator via HelmRelease |
| `MinIOTenantSpec` / `MinIOHelmSpec` | S3-compatible object storage |
| `ObservabilityModule` | Prometheus + Grafana stack |
| `OpenTelemetryModule` | OpenTelemetry collector |

## Two Approaches to Define Modules

### Template Approach (Recommended)

Inherit from a framework template — 80-90% less boilerplate:

```kcl
import framework.templates.webapp.v1_0_0.webapp as webapp

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

Start at the **[documentation index](docs/README.md)** — it provides a single, ordered
reading path and groups every document by audience and topic.

Key entry points:

| Document | Audience | Content |
|---|---|---|
| [docs/README (index)](docs/README.md) | All | Master index and recommended reading path |
| [DEVELOPER_QUICKSTART](docs/DEVELOPER_QUICKSTART.md) | Developers | Day-to-day usage, render commands, config options |
| [PROJECT_ARCHITECTURE](docs/PROJECT_ARCHITECTURE.md) | All | Architecture, data flow, how everything connects |
| [WORKFLOWS](docs/WORKFLOWS.md) | Developers / Platform engineers | Role-based and step-by-step render workflows |
| [Distribution & Sharing Model](docs/decisions/DISTRIBUTION_AND_SHARING_MODEL.md) | All | How the CLI is installed and how teams share work via Git/GitOps |
| [Rendering Strategy Decision](docs/decisions/RENDERING_STRATEGY_DECISION.md) | Platform engineers | Kustomize for dev, Crossplane v2 for the variable stack |

## Technologies

- **[KCL](https://www.kcl-lang.io/)** — Configuration language and single source of truth (CNCF Sandbox)
- **[Go](https://go.dev/)** — The `koncept` CLI (the installable package)
- **[Crossplane](https://www.crossplane.io/)** — Kubernetes-native infrastructure provisioning
- **[ArgoCD](https://argo-cd.readthedocs.io/)** — GitOps continuous delivery

## License

See [LICENSE](LICENSE).
