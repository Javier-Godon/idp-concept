# Developer Guide

> idp-concept is operated through the `koncept` Go CLI. KCL is still the source language and framework model, but the CLI is the supported user layer for scaffolding, validation, rendering, governance, and troubleshooting.

## Who This Is For

| Role | Start here | Main responsibility |
|---|---|---|
| Application developer | [DEVELOPER_QUICKSTART.md](DEVELOPER_QUICKSTART.md) | Render, validate, and review application/environment output |
| Platform engineer | This guide + [CLI_REFERENCE.md](CLI_REFERENCE.md) | Scaffold projects/modules/environments, maintain stacks, enforce policy |
| Framework contributor | This guide + [FRAMEWORK_SCHEMAS.md](FRAMEWORK_SCHEMAS.md) | Extend KCL schemas, builders, templates, and render procedures |
| Operator / release engineer | [WORKFLOWS.md](WORKFLOWS.md) + [GOLDEN_OUTPUTS.md](GOLDEN_OUTPUTS.md) | Run promotion, drift, policy, and release-note gates |

## Mental Model

The platform has two layers:

1. **CLI layer**: `cmd/koncept` is the installable Go package. Users run `koncept init`, `koncept validate`, `koncept dry-run`, `koncept render`, `koncept policy`, and related commands.
2. **KCL layer**: `framework/` and `projects/` define the desired platform state. KCL provides schemas, config merging, templates, builders, and output conversion procedures.

Most users should not run raw `kcl` commands for normal work. Raw KCL is for framework debugging, tests, and low-level investigation. The CLI wraps the repository conventions so commands behave the same in local development and CI.

```text
koncept CLI
  -> finds project and factory
  -> validates KCL context
  -> runs the generic factory renderer
  -> writes output or runs governance checks

KCL source of truth
  kernel -> profile -> tenant -> site
  modules + stack -> factory -> output format
```

## Day-To-Day Command Loop

From a project root, pass the factory path explicitly:

```bash
cd projects/erp_back

koncept doctor --factory pre_releases/manifests/dev/factory
koncept validate --factory pre_releases/manifests/dev/factory
koncept dry-run --factory pre_releases/manifests/dev/factory
koncept render argocd --factory pre_releases/manifests/dev/factory
koncept policy check --factory pre_releases/manifests/dev/factory
```

From a release or pre-release directory that contains `factory/`, the default path is enough:

```bash
cd projects/erp_back/releases/v1_0_0_production

koncept validate
koncept dry-run
koncept render helmfile
koncept golden check --formats yaml,helmfile
```

Use [CLI_REFERENCE.md](CLI_REFERENCE.md) for the full command reference.

## Output Tiers

| Tier | Formats | Who should use them |
|---|---|---|
| Tier 1 | `yaml`, `argocd`, `helmfile`, `backstage` | Product teams and default GitOps/developer-portal workflows |
| Tier 2 | `helm`, `crossplane`, `kustomize` | Platform/infrastructure teams and maintained integrations |
| Tier 3 | `kusion`, `timoni` | Explicit experiments only |

Prefer Tier 1 unless the team has a documented reason to use another output. Tier 3 renderers are kept for learning and compatibility; they should not become a production dependency without an adoption decision.

## Creating And Evolving A Project

### Create A Project

```bash
koncept init project "Orders API" \
  --owner payments-team \
  --git-repo https://github.com/example/orders-api \
  --image ghcr.io/example/orders-api \
  --version 1.2.3 \
  --port 8080
```

The generated project contains:

```text
projects/orders_api/
  kernel/               project identity and base config
  core_sources/         project configuration schema and merge function
  modules/              application and infrastructure modules
  stacks/               module assembly by lifecycle/version
  tenants/              customer/team overrides
  sites/                environment overrides
  pre_releases/         mutable dev/staging factories
  releases/             immutable production factories
  koncept.yaml          CLI metadata and output defaults
```

Validate immediately:

```bash
koncept validate --factory projects/orders_api/pre_releases/manifests/dev/factory
koncept render argocd --factory projects/orders_api/pre_releases/manifests/dev/factory
```

### Add A Module

Supported module scaffold types are `webapp`, `database`, `postgres`, `redis`, `kafka`, `mongodb`, and `rabbitmq`.

```bash
cd projects/orders_api

koncept init module webapp billing-api \
  --image ghcr.io/example/billing-api \
  --version 1.0.0 \
  --port 8080

koncept init module postgres billing-db --storage 20Gi
```

Use `--wire` only when the target stack has CLI wire markers:

```bash
koncept init module redis billing-cache --wire
```

Without `--wire`, the command creates the module and prints stack wiring for a platform engineer to review and paste.

### Add An Environment

```bash
koncept init env staging \
  --namespace orders-stg-apps \
  --storage-class local-path
```

This creates an environment profile, site config, and pre-release factory. Use well-known names such as `dev`, `staging`, and `prod` when possible so defaults remain predictable.

### Add A Release

```bash
koncept init release 1.0.0 --storage-class rook-ceph-block
```

Release factories are immutable snapshots. Review drift with golden files and policy checks before promotion.

## How Configuration Merges

Every rendered deployment is a merge of four configuration layers:

| Layer | Question | Typical content |
|---|---|---|
| Kernel | What is this project? | Base names, default ports, image names, global defaults |
| Profile | Which lifecycle or version is this? | Stack defaults, namespaces, version settings |
| Tenant | Who is this for? | Customer/team branding, feature flags, product-specific overrides |
| Site | Where does it run? | Replicas, resources, storage class, URLs, environment-specific values |

KCL merges these with the union operator, where later layers override earlier ones:

```kcl
final_config = kernel | profile | tenant | site
```

Developers usually change tenant or site values. Platform engineers change profiles, stacks, and modules. Framework contributors change shared schemas and render procedures.

## Factories

A factory is the render entry point for one environment or release.

```text
factory/
  factory_seed.k   imports project/profile/tenant/site/stack and creates the render stack
  render.k         calls the shared framework renderer
```

The CLI expects a factory path. If you are in a release or pre-release directory, `factory` is the default. Elsewhere, pass `--factory`.

```bash
koncept render argocd --factory pre_releases/manifests/dev/factory
```

Do not hand-edit generated output as the source of truth. Change the KCL source, then re-render.

## Modules, Templates, And Stacks

### Modules

A module is a deployable unit. The framework uses these module categories:

| Module type | Use |
|---|---|
| Component | Application or infrastructure workload, usually Deployment/Service/ConfigMap |
| Accessory | Supporting resources such as operator CRDs, secrets, topics, or storage |
| K8sNamespace | Namespace resource |
| ThirdParty | External package such as a Helm chart |

### Templates

Templates are the preferred way to create modules. They reduce boilerplate and keep output consistent.

Common templates include `WebAppModule`, `PostgreSQLClusterModule`, `MongoDBCommunityModule`, `KafkaClusterModule`, `RabbitMQClusterModule`, `RedisModule`, `KeycloakModule`, `OpenSearchClusterModule`, `VaultStaticSecretModule`, `QuestDBModule`, `MinIOTenantSpec`, `MinIOHelmSpec`, `ObservabilityModule`, and `OpenTelemetryModule`.

Example:

```kcl
import framework.templates.webapp.v1_0_0.webapp as webapp

schema OrdersApi(webapp.WebAppModule):
    name = "orders-api"
    port = 8080
```

### Stacks

A stack selects which modules deploy together and declares dependency order. Stacks consume module `.instance` values rather than raw schema objects.

```kcl
stack = stack_model.Stack {
    name = "orders-dev"
    components = [orders_api.instance]
    accessories = [orders_db.instance]
}
```

The CLI can scaffold module files, but stack changes still deserve review because they define platform behavior and dependencies.

## Governance Gates

Use these commands before merging platform-affecting changes:

```bash
koncept validate --factory <factory>
koncept dry-run --factory <factory>
koncept policy check --factory <factory>
koncept golden check --factory <factory> --formats yaml,helmfile
koncept changelog check
```

Policy checks cover privileged containers, unpinned images, missing resources, owner labels, secret-looking literal env values, namespaces, and NetworkPolicies. Use [POLICY_EXEMPTIONS.md](POLICY_EXEMPTIONS.md) for narrow, owned, expiring waivers.

Golden files are expected-output snapshots. Update them only after reviewing the render diff:

```bash
koncept diff argocd --factory <factory>
koncept golden update --factory <factory> --formats yaml,helmfile
```

## Troubleshooting

| Symptom | Command | Fix |
|---|---|---|
| CLI cannot find `render.k` | `koncept doctor --factory <factory>` | Pass the correct factory or run from the release/pre-release directory |
| KCL import fails with `cannot find module` | `koncept deps` | Fix the nearest `kcl.mod`; nested project modules should usually depend on the parent project, not directly on `framework` |
| Render output changed unexpectedly | `koncept diff <format>` | Review source changes and update golden files only if the drift is intended |
| Policy check fails on a temporary exception | `koncept policy check --exemptions policy-exemptions.yaml` | Add a narrow waiver with owner and expiry |
| Tier 3 warning appears | `koncept render yaml` or `koncept render helmfile` | Use Tier 1 unless the experiment is intentional |

## When To Use Raw KCL

Use raw `kcl` commands when you are developing the framework itself, debugging KCL language behavior, or running framework tests directly:

```bash
cd framework
kcl test ./...

cd projects/erp_back/pre_releases/manifests/dev/factory
kcl run render.k -D output=yaml
```

For product and platform workflows, prefer `koncept` because it owns output routing, factory discovery, governance checks, telemetry hooks, and repository conventions.

## Documentation Map

- [CLI_REFERENCE.md](CLI_REFERENCE.md) — complete `koncept` command reference.
- [DEVELOPER_QUICKSTART.md](DEVELOPER_QUICKSTART.md) — shortest path to first render.
- [WORKFLOWS.md](WORKFLOWS.md) — role-based task recipes.
- [PROJECT_ARCHITECTURE.md](PROJECT_ARCHITECTURE.md) — deeper architecture and data-flow explanation.
- [FRAMEWORK_SCHEMAS.md](FRAMEWORK_SCHEMAS.md) — KCL schema reference.
- [TOOLING_SETUP.md](TOOLING_SETUP.md) — installing `koncept`, KCL, and optional tools.
