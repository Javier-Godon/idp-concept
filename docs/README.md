# Documentation

> User-facing documentation for **idp-concept** — organized by role.
>
> For AI assistant references, see [`.github/docs/`](../.github/docs/).

## By User Profile

### Developer (Profile 1)

Start here if you deploy and configure applications using the `koncept` CLI.

| Document | Description |
|---|---|
| [DEVELOPER_QUICKSTART.md](DEVELOPER_QUICKSTART.md) | Get started in 5 minutes — prerequisites, commands, troubleshooting |
| [DEVELOPMENT_WORKFLOWS.md](DEVELOPMENT_WORKFLOWS.md) | Step-by-step guides for rendering YAML, Helm, Helmfile, Kusion |
| [APPLICATION_CONFIGURATION_PATTERNS.md](APPLICATION_CONFIGURATION_PATTERNS.md) | Standard config files and env vars for Python, Go, Rust, Kotlin, and frontend apps |

### Platform Engineer — High-Level (Profile 2)

Start here if you compose stacks, tenants, sites, and modules using framework templates.

| Document | Description |
|---|---|
| [PROJECT_ARCHITECTURE.md](PROJECT_ARCHITECTURE.md) | Architecture overview — configuration merge, output formats, module types |
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | Comprehensive guide — schemas, factories, templates, migration |
| [FRAMEWORK_SCHEMAS.md](FRAMEWORK_SCHEMAS.md) | Complete schema reference for all framework models |
| [PROJECT_FOLDER_STANDARD.md](PROJECT_FOLDER_STANDARD.md) | Convention-based project, stack, tenant, site, and release folder layout |
| [SEARCH_STACK_DECISION.md](SEARCH_STACK_DECISION.md) | Elasticsearch vs OpenSearch recommendation, licensing notes, and versioned templates |

### Platform Engineer — Low-Level (Profile 3)

Start here if you design framework internals — builders, templates, procedures.

| Document | Description |
|---|---|
| [TESTING_STRATEGY.md](TESTING_STRATEGY.md) | Testing approach — KCL unit tests, kubeconform, Helm lint, CI/CD |
| [ACCEPTANCE_TESTING.md](ACCEPTANCE_TESTING.md) | Optional kind-based deployment smoke tests for generated manifests |
| [CROSSPLANE_PATTERNS.md](CROSSPLANE_PATTERNS.md) | Crossplane composition patterns used in `crossplane_v2/` |
| [IDP_EVOLUTION_PLAN.md](IDP_EVOLUTION_PLAN.md) | Roadmap — phases, implementation progress, priority tree |
| [PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md](PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md) | KCL vs Go analysis, k0rdent/Fleet patterns, factory improvements |

### All Users

| Document | Description |
|---|---|
| [SECURITY.md](SECURITY.md) | Security policy — approved tools, MCP fetch safety, trusted domains |
| [STORAGE_POLICY_PATTERNS.md](STORAGE_POLICY_PATTERNS.md) | Environment storage policy baseline (local-path, Ceph, Longhorn) |
| [OPERATING_MODEL.md](OPERATING_MODEL.md) | Roles, change categories, and approval paths for platform/app/env changes |
| [PLATFORM_METRICS.md](PLATFORM_METRICS.md) | Opt-in local CLI telemetry — enabling, storage, and aggregation |
