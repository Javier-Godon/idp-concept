# GitHub Copilot Custom Instructions for idp-concept

## Project Identity

This is **idp-concept**, an Internal Developer Platform (IDP) that uses **KCL** (Kusion Configuration Language) as the single source of truth to generate Kubernetes deployment manifests in multiple output formats: plain YAML (for ArgoCD/GitOps), Helm charts, Helmfile, Kusion specs, and Crossplane compositions. The CLI is written in **Nushell** (`nu`).

## Core Technologies — Learn These Deeply

### 1. KCL (Kusion Configuration Language)
- **Official docs**: https://www.kcl-lang.io/docs/
- **Version**: v0.10.0 edition, using `k8s = "1.31.2"` dependency
- KCL is a constraint-based record & functional language for configuration and policy
- Key features used: **schema inheritance**, **schema composition**, **lambda functions**, **union operators (`|`)** for config merging, **string interpolation** (`${var}`), **list comprehensions**, **conditional expressions**
- The `kcl.mod` file (TOML) declares packages and dependencies (similar to `go.mod`)
- `import` statements reference packages by path relative to `kcl.mod`
- Schema instances use `SchemaName { field = value }` syntax
- The `.instance` pattern is used throughout: schemas have an `instance` property that creates a flattened instance of itself
- `manifests.yaml_stream()` is a built-in for serializing to multi-document YAML
- `$type` is used instead of `type` for Kubernetes YAML fields (KCL reserved word escape)
- Private variables start with `_` (not exported)
- `option("key")` reads `-D key=value` CLI arguments

#### KCL Module System (Go-like)
- Each directory with a `kcl.mod` is a **package** — the `name` field is the import root
- Dependencies are declared in `[dependencies]` with `path` (local) or version (registry)
- **Transitive resolution**: If A depends on B, and B depends on C, A can import C without declaring it
- **Nested packages** (e.g., `pre_releases/`) should depend only on the parent project — framework resolves transitively
- Within a package, sibling imports can omit the package name prefix: `import models.stack` inside `framework/`
- Relative imports use `.` prefix: `import .factory_seed` for same-directory imports
- Paths in `kcl.mod` are relative to the `kcl.mod` file itself, NOT to the source file
- See `.github/instructions/kcl-module-system.instructions.md` for the full reference

### 2. Nushell (nu)
- **Official docs**: https://www.nushell.sh/book/
- The CLI tool `platform_cli/koncept` is a Nushell script (`#!/usr/bin/env nu`)
- Uses `def main` with typed parameters and flags (`--factory: string`, `--output: string`)
- String interpolation: `$"text ($variable) more text"`
- Path manipulation: `path basename`, `path dirname`, `path expand`, `path join`
- Environment variables: `$env.PWD`, `$env.FILE_PWD`
- Control flow: `match` expressions with `=>` arms
- External commands: prefixed with `^` (e.g., `^task`)
- Directory operations: `mkdir`, `touch`
- There is also `platform_cli/koncepttask` which delegates to Taskfile YAML (`go-task`)

### 3. Crossplane
- **Official docs**: https://docs.crossplane.io/
- Used in `crossplane_v2/` for Kubernetes-native infrastructure provisioning
- **XRDs** (CompositeResourceDefinitions): Define custom API types under `koncept.bluesolution.es` and `gitops.bluesolution.es`
- **Compositions**: Pipeline mode using functions (patch-and-transform, auto-ready, go-templating, KCL, sequencer)
- **Providers**: Helm provider and Kubernetes provider with `InjectedIdentity` credentials
- Managed resources: cert-manager, Kafka (Strimzi), PostgreSQL, Keycloak
- All compositions use `kubernetes.crossplane.io/v1alpha2 Object` to create raw K8s manifests

### 4. ArgoCD
- Used as GitOps deployment target
- KCL models auto-generated from CRDs via `kcl import` tool
- Application, ApplicationSet, AppProject schemas modeled in `framework/custom/argocd/models/v1alpha1/`
- Specification examples in `framework/custom/argocd/specifications/`

### 5. Helm & Helmfile
- `framework/custom/helm/helm.k`: KCL schemas for Chart.yaml, values, dependencies
- `framework/custom/helmfile/helmfile.k`: KCL schemas for helmfile.yaml (repositories, releases, environments)
- The project generates complete Helm chart structures (Chart.yaml, values.yaml, templates/) from KCL

### 6. Kusion
- The project generates Kusion spec YAML with `KusionResource` entries
- Each manifest becomes a Kusion resource with `id`, `type: Kubernetes`, `attributes`, and `dependsOn`
- The `id` format: `apiVersion:kind:namespace:name` or `apiVersion:kind:name`

## Architecture — The "Single Source of Truth" Pattern

```
kernel/ (project definition + base configurations)
    ↓
core_sources/ (configuration schema + merge function)
    ↓
stacks/ (profile + stack: what components/accessories to deploy)
    ↓
tenants/ (customer-specific config overrides)
    ↓
sites/ (target environment config overrides)
    ↓
pre_releases/ or releases/ (merge all configs → factory/ → output format)
    ↓
factory/ builders → framework/procedures/* → OUTPUT (yaml, helm, helmfile, kusion)
```

### Configuration Merge Order
Configurations merge with KCL's union operator (`|`) in this order:
1. **Kernel** (project base) → 2. **Profile** (stack/version) → 3. **Tenant** (customer) → 4. **Site** (target environment)

Later values override earlier ones.

## Key Directory Mapping

| Directory | Purpose |
|---|---|
| `framework/models/` | Core domain schemas: Project, Tenant, Site, Profile, Stack, Release |
| `framework/models/modules/` | Component, Accessory, K8sNamespace, ThirdParty schemas |
| `framework/models/configurations.k` | BaseConfigurations schema + generic merge_configurations lambda |
| `framework/builders/` | Manifest builder lambdas: deployment, service, configmap, storage, service_account, leader, network_policy, pdb |
| `framework/templates/` | Module templates: WebAppModule, SingleDatabaseModule, KafkaClusterModule, PostgreSQLClusterModule, MongoDBCommunityModule, RabbitMQClusterModule, RedisModule, KeycloakModule, OpenSearchClusterModule, VaultStaticSecretModule, QuestDBModule, MinIOTenantSpec/MinIOHelmSpec |
| `framework/assembly/` | Stack utilities: create_namespace helpers |
| `framework/factory/` | Factory scaffolding: FactorySeed schema |
| `framework/procedures/` | Conversion functions: `kcl_to_yaml`, `kcl_to_helm`, `kcl_to_kusion`, `kcl_to_argocd` |
| `framework/custom/` | Output-format-specific schemas: ArgoCD, Helm, Helmfile, Spring |
| `projects/video_streaming/kernel/` | Project definition and base configurations |
| `projects/video_streaming/core_sources/` | Project-specific config schema + merge function |
| `projects/video_streaming/modules/` | Concrete K8s manifests (applications and infrastructure) |
| `projects/video_streaming/stacks/` | Stack definitions (which modules to deploy, at what profile/version) |
| `projects/video_streaming/tenants/` | Per-tenant configuration overrides |
| `projects/video_streaming/sites/` | Per-site (environment) configuration overrides |
| `projects/video_streaming/pre_releases/` | Development/staging deployments |
| `projects/video_streaming/releases/` | Production versioned deployments per site |
| `projects/erp_back/` | ERP Back project — uses new framework templates (recommended pattern) |
| `platform_cli/` | Nushell CLI tools (`koncept`, `koncepttask`) and Taskfile templates |
| `crossplane_v2/` | Crossplane XRDs, Compositions, Functions, Providers |

## Module Types

- **Component** (`kind: "APPLICATION" | "INFRASTRUCTURE"`): Main deployable units with Deployment, Service, ConfigMap, etc.
- **Accessory** (`kind: "CRD" | "SECRET"`): Supporting resources like Kafka clusters, MongoDB, PVs
- **K8sNamespace**: Kubernetes namespace resources
- **ThirdParty** (`packageManager: "HELM" | "JSONNET" | ...`): External vendor-managed resources

## Code Conventions

1. **Schema + Instance pattern**: Every model (Project, Tenant, Site, etc.) has both a `Schema` and `SchemaInstance` — the instance is a flat data container, the schema validates and populates it
2. **Private variables** (`_var`): Used for intermediate computations not exported to output
3. **factory/ folders**: Each release/pre_release has a `factory/` directory containing builder KCL files that compose the stack and call framework procedures
4. **`factory_seed.k`**: Sets up the release context (configs, stack, project, tenant, site)
5. **`*_builder.k`**: Generates specific output format by calling framework procedures
6. **Module definitions** end with `_module_def.k` and extend framework schemas via inheritance

## When Generating KCL Code

### Recommended Approach (using templates)
- For web apps: `schema MyApp(webapp.WebAppModule):` — set port, probes, env, resources
- For databases: `schema MyDb(database.SingleDatabaseModule):` — set port, dataPath, storageSize, env
- For Kafka: `schema MyKafka(kafka.KafkaClusterModule):` — set clusterName, topics
- For PostgreSQL: `schema MyPg(postgresql.PostgreSQLClusterModule):` — set instances, storageSize, pgVersion
- For MongoDB: `schema MyMongo(mongodb.MongoDBCommunityModule):` — set members, version, users
- For RabbitMQ: `schema MyRmq(rabbitmq.RabbitMQClusterModule):` — set replicas, storageSize
- For Redis: `schema MyRedis(redis.RedisModule):` — set mode (standalone/cluster), replicas
- For Keycloak: `schema MyKc(keycloak.KeycloakModule):` — set instances, hostname, db
- For OpenSearch: `schema MyOs(opensearch.OpenSearchClusterModule):` — set nodePools, dashboards
- For Vault secrets: `schema MyVault(vault.VaultStaticSecretModule):` — set mount, path
- For QuestDB: `schema MyQdb(questdb.QuestDBModule):` — set storageSize, httpPort
- For MinIO: `minio.MinIOTenantSpec` (Operator CRD) or `minio.MinIOHelmSpec` (Bitnami Helm) — set servers, storageSize
- Templates auto-generate leaders, manifests, Deployment, Service, ConfigMap, etc.
- See `projects/erp_back/` for a complete example using templates

### Raw Approach (full control)
- Import from `framework.models.*` for base schemas
- Use schema inheritance: `schema MyModule(component.Component):`
- Set `kind`, `leaders`, `manifests` in module schemas
- Use builders from `framework.builders.*` to reduce boilerplate
- See `projects/video_streaming/` for examples with raw manifests

### Universal Rules
- Use `dependsOn` for ordering (references to namespace instances)
- Access `.instance` property when passing to stack definitions
- Use `$type` for Kubernetes `type` fields
- Use `${var}` for string interpolation in manifest values
- Use `framework.assembly.helpers` for namespace creation in stacks
- Extend `framework.models.configurations.BaseConfigurations` for project configs

## When Working with the CLI

- `koncept render argocd` — generates plain YAML via `kcl_to_yaml`
- `koncept render helmfile` — generates Helm charts + helmfile.yaml
- `koncept render kusion` — generates Kusion spec YAML
- Must be run from within a pre_release or release directory
- Uses `factory/` relative path by default, configurable with `--factory`

## When Working with Crossplane

- XRDs define the API at `koncept.bluesolution.es/v1alpha1`
- Compositions use `mode: Pipeline` with function steps
- Always reference `provider-kubernetes` or `helm-provider` in `providerConfigRef`
- Use `patches` for dynamic value injection from composite fields

## Security Rules — Non-Negotiable

These rules apply to ALL AI-generated code and tool recommendations:

1. **Only official, mainstream tools** — Never suggest experimental, abandoned, or poorly-maintained dependencies
2. **No secrets in code** — Never generate hardcoded credentials, tokens, or passwords. Use `$env.VAR`, `option("key")`, or `${input:name}`
3. **No privileged containers** — Never generate `privileged: true`, `hostNetwork: true`, or excessive capabilities in K8s manifests
4. **Pin dependency versions** — Always pin specific versions in `kcl.mod`, `Chart.yaml`, `helmfile.yaml`. No floating tags like `latest`
5. **Validate Crossplane RBAC** — Never generate overly permissive ClusterRoles. Follow least-privilege
6. **Sanitize Nushell scripts** — Never use `rm -rf` without safeguards; never pass raw user input to `^` external commands
7. **MCP fetch targets** — Only fetch URLs from trusted documentation domains listed in `docs/SECURITY.md`
8. **NEVER fetch internal/local addresses** — The MCP fetch server can access localhost and private IPs. NEVER fetch `localhost`, `127.0.0.1`, `0.0.0.0`, `169.254.169.254`, or any private IP range (10.x, 172.16-31.x, 192.168.x). This is a **critical SSRF risk**. Only fetch domains from the trusted allowlist in `docs/SECURITY.md`.
9. **Review before apply** — All generated Crossplane Compositions and K8s manifests must be reviewed before deployment

See `docs/SECURITY.md` for the complete security policy, approved tools registry, and tool evaluation criteria.

## Knowledge Reliability Warning

**This project uses niche technologies (KCL, Nushell, Kusion) where AI training data is limited and unreliable.** The project code in `framework/` and `projects/` represents functional working solutions by a practitioner (not a KCL/IDP expert). Always cross-reference with authoritative sources before generating code.

**Trust hierarchy:**
1. Official docs (kcl-lang.io, nushell.sh, docs.crossplane.io) — **authoritative**
2. Official repos (kcl-lang/*, crossplane-contrib/function-kcl) — **authoritative**
3. Expert repos (vfarcic/crossplane-kubernetes: 66% KCL + 30.6% Nushell) — **high trust**
4. Local project code — **functional but not authoritative**
5. AI training data for KCL/Kusion — **unreliable, always verify**

Use the `knowledge-research` skill (`.github/skills/knowledge-research/SKILL.md`) when working with unfamiliar patterns.

## Reference Knowledge Sources

### KCL Ecosystem (CNCF)
- **kcl-lang/kcl** (2,300+ stars) — KCL language core. Has a `CLAUDE.md` with AI instruction patterns
- **kcl-lang/modules** (200+ modules) — Official KCL modules for crossplane, argocd, strimzi, cert-manager
- **crossplane-contrib/function-kcl** (150+ stars) — Canonical KCL-in-Crossplane function (API: `option("params").oxr/.ocds/.dxr/.dcds/.ctx`)
- **kcl-lang/krm-kcl** (34+ stars) — KRM KCL spec bridging KCL to Helm, Helmfile, Crossplane
- **kcl-lang/konfig** (14+ stars) — KCL K8s abstraction framework (similar architecture to our `framework/`)
- **kcl-lang/examples** (34+ stars) — Comprehensive KCL examples for all use cases
- **KCL docs**: https://www.kcl-lang.io/docs/

### Platform Engineering References (Viktor Farcic / Upbound)
- **vfarcic/crossplane-kubernetes** (50+ stars) — **Closest external match**: 66% KCL + 30.6% Nushell, Crossplane compositions, CLAUDE.md, MCP config
- **vfarcic/crossplane-app** (11+ stars) — 78.7% Nushell + 20.4% KCL, app-level Crossplane compositions
- **vfarcic/dot-ai** (308+ stars) — MCP-based DevOps AI toolkit, Nushell + K8s operations
- **vfarcic/cncf-demo** (231+ stars) — End-to-end CNCF stack with IDP, Crossplane, ArgoCD chapters

### Platform Framework Alternatives (monitor for ideas)
- **KusionStack/kusion** (1,287+ stars) — Intent-driven Platform Orchestrator, deep KCL integration
- **stefanprodan/timoni** (1,900+ stars) — CUE-powered Helm alternative (possible future output format)
- **score-spec/spec** (8,000+ stars) — Platform-agnostic workload spec (possible future input format)
- **syntasso/kratix** (741+ stars) — Platform framework with Promises (parallels Stack/Module pattern)

### CNCF References
- **cncf/tag-app-delivery** (833+ stars) — Platform Engineering Maturity Model + Platforms Whitepaper

### Official Documentation
- KCL: https://www.kcl-lang.io/docs/
- Nushell: https://www.nushell.sh/book/
- Crossplane: https://docs.crossplane.io/
- ArgoCD: https://argo-cd.readthedocs.io/
- Helm: https://helm.sh/docs/
- Kusion: https://www.kusionstack.io/docs/
- CNCF Platform Maturity Model: https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model

See `.github/docs/REFERENCE_RESOURCES.md` for the complete curated knowledge base.
