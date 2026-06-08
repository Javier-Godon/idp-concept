# Documentation Index

> The single entry point to **idp-concept** documentation. It gives one **ordered reading
> path** and a **complete catalog** grouped by topic, so you can read everything in a sensible
> order instead of guessing.
>
> For AI-assistant references, see [`.github/docs/`](../.github/docs/).

---

## Recommended reading path

Follow these in order. Stop wherever you have what you need.

1. **[Project README](../README.md)** — what the platform is, the KCL single-source-of-truth
   idea, and the output formats.
2. **[Distribution & Sharing Model](decisions/DISTRIBUTION_AND_SHARING_MODEL.md)** — the mental
   model: the `koncept` CLI is the installable package; teams share work through Git + GitOps.
3. **[Tooling Setup](TOOLING_SETUP.md)** — install the CLI and KCL. (Windows users:
   [Windows Local Setup](WINDOWS_LOCAL_SETUP.md).)
4. **[Developer Quickstart](DEVELOPER_QUICKSTART.md)** — render your first manifests.
5. **[CLI Reference](CLI_REFERENCE.md)** — the current `koncept` command surface.
6. **[Developer Guide](DEVELOPER_GUIDE.md)** — how the CLI maps to KCL, factories, stacks,
   and governance.
7. **[Project Architecture](PROJECT_ARCHITECTURE.md)** — how configuration merges
   (kernel → profile → tenant → site) and how everything connects.
8. **[Workflows](WORKFLOWS.md)** — role-based and step-by-step task recipes (rendering, adding
   modules/tenants/sites/releases, Crossplane, debugging).
9. **Go deeper for your role** — pick the relevant track in the catalog below.
10. **[Decisions](#decisions--adrs)** — read the ADRs to understand *why* the platform is shaped
   the way it is (rendering strategy, search stack, distribution).

---

## Catalog by topic

### Getting started

| Document | Audience | Description |
|---|---|---|
| [DEVELOPER_QUICKSTART.md](DEVELOPER_QUICKSTART.md) | Developers | Prerequisites, render commands, troubleshooting |
| [CLI_REFERENCE.md](CLI_REFERENCE.md) | Developers / Platform engineers | Current `koncept` command reference |
| [TOOLING_SETUP.md](TOOLING_SETUP.md) | All | Install the `koncept` CLI, KCL, and optional tools |
| [WINDOWS_LOCAL_SETUP.md](WINDOWS_LOCAL_SETUP.md) | Developers | WSL2 + Docker Desktop + kind local setup |
| [APPLICATION_CONFIGURATION_PATTERNS.md](APPLICATION_CONFIGURATION_PATTERNS.md) | Developers | Standard config/env patterns per language and framework |

### Architecture & reference

| Document | Audience | Description |
|---|---|---|
| [PROJECT_ARCHITECTURE.md](PROJECT_ARCHITECTURE.md) | All | Architecture, data flow, layers, how to extend |
| [FRAMEWORK_SCHEMAS.md](FRAMEWORK_SCHEMAS.md) | Platform engineers | Complete KCL schema reference |
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | Developers / Platform engineers | CLI-centered guide to projects, factories, stacks, templates, and governance |
| [PROJECT_FOLDER_STANDARD.md](PROJECT_FOLDER_STANDARD.md) | Platform engineers | Folder conventions and path-derived values |
| [FRAMEWORK_VERSIONING.md](FRAMEWORK_VERSIONING.md) | Platform engineers | Compatibility metadata, SemVer rules, support tiers |

### Workflows & guides

| Document | Audience | Description |
|---|---|---|
| [WORKFLOWS.md](WORKFLOWS.md) | Developers / Platform engineers | Role-based and step-by-step task recipes |
| [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) | Platform engineers | Migrate from raw manifests to the template pattern |
| [STORAGE_POLICY_PATTERNS.md](STORAGE_POLICY_PATTERNS.md) | Platform engineers | Storage baseline (local-path, Ceph, Longhorn) per environment |

### Testing & verification

| Document | Audience | Description |
|---|---|---|
| [TESTING_STRATEGY.md](TESTING_STRATEGY.md) | Contributors | Testing layers and the testing pyramid |
| [VERIFICATION_MATRIX.md](VERIFICATION_MATRIX.md) | Contributors | Canonical lint/test/render verification runbook |
| [ACCEPTANCE_TESTING.md](ACCEPTANCE_TESTING.md) | Contributors | kind dry-run acceptance matrix |
| [ACCEPTANCE_RUNTIME.md](ACCEPTANCE_RUNTIME.md) | Contributors | Real-cluster runtime acceptance layer |
| [ACCEPTANCE_DEPENDENCIES.md](ACCEPTANCE_DEPENDENCIES.md) | Contributors | Template acceptance levels and dependency scenarios |
| [GOLDEN_OUTPUTS.md](GOLDEN_OUTPUTS.md) | Contributors | Golden render-drift review gate |

### Operations & governance

| Document | Audience | Description |
|---|---|---|
| [OPERATING_MODEL.md](OPERATING_MODEL.md) | All | Roles, change categories, approval paths |
| [SECURITY.md](SECURITY.md) | All | Security policy, approved tools, fetch safety |
| [POLICY_EXEMPTIONS.md](POLICY_EXEMPTIONS.md) | Contributors | Narrow, owned, expiring policy waivers |
| [PLATFORM_METRICS.md](PLATFORM_METRICS.md) | Platform engineers | Opt-in local CLI telemetry and aggregation |
| [CHANGELOG_WORKFLOW.md](CHANGELOG_WORKFLOW.md) | Contributors | Release-note fragment workflow |

### Infrastructure & integrations

| Document | Audience | Description |
|---|---|---|
| [CROSSPLANE_PATTERNS.md](CROSSPLANE_PATTERNS.md) | Platform engineers | Crossplane XRD/Composition/function-kcl patterns |
| [BACKSTAGE_ADOPTION_ANALYSIS.md](BACKSTAGE_ADOPTION_ANALYSIS.md) | Platform engineers | Developer-portal adoption analysis |
| [BACKSTAGE_PLUGIN_GUIDE.md](BACKSTAGE_PLUGIN_GUIDE.md) | Platform engineers | Backstage plugin installation and integration |

### Decisions / ADRs

| Document | Audience | Description |
|---|---|---|
| [decisions/DISTRIBUTION_AND_SHARING_MODEL.md](decisions/DISTRIBUTION_AND_SHARING_MODEL.md) | All | CLI = installable package; Git + GitOps = how teams share work |
| [decisions/RENDERING_STRATEGY_DECISION.md](decisions/RENDERING_STRATEGY_DECISION.md) | Platform engineers | Kustomize for dev; Crossplane v2 for the variable stack; Timoni/Kusion assessment |
| [decisions/SEARCH_STACK_DECISION.md](decisions/SEARCH_STACK_DECISION.md) | Platform engineers | Elasticsearch vs OpenSearch recommendation and licensing |

### Planning & analysis (meta)

Keep this section small. Implementation progress reports, dated status docs, and one-off completion summaries belong in [archive/](archive/) once the active guides below explain the current behavior.

| Document | Audience | Description |
|---|---|---|
| [IDP_EVOLUTION_PLAN.md](IDP_EVOLUTION_PLAN.md) | All | Current-state assessment, phases, roadmap |
| [PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md](PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md) | Platform engineers | KCL vs Go analysis, k0rdent/Fleet patterns |

### Archive

| Location | Description |
|---|---|
| [archive/](archive/) | Historical implementation reports, status summaries, completion reports, and superseded checklists. Do not use archived files as the source for current commands. |
