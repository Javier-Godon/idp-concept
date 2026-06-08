# IDP Assessment & Evolution Plan

> ⚠️ **This document is now the HISTORICAL EVOLUTION RECORD.** As of 2026-06-07 most of its open
> phases have been implemented and its "what to do next" sections are superseded. For the
> **current-state assessment and forward actions**, read
> [`docs/IDP_ASSESSMENT_2026H2.md`](./IDP_ASSESSMENT_2026H2.md). Keep this file for the history of
> how the platform evolved and the rationale/learnings captured along the way.
>
> Current-state assessment and roadmap for **idp-concept** as a practical Internal Developer Platform for a medium-sized company with several products.
>
> Last reviewed: 2026-05-31. Repository verification at review time: `./scripts/verify.sh`, golden drift checks, Go CLI package tests, and the policy gate passed.
>
> Update 2026-05-30: added `koncept completion`, `koncept policy check` (baseline security/ownership gate), `koncept init project` (full validating webapp skeleton), concise KCL module-resolution error hints, build metadata wiring, and CI image/build tooling (`Dockerfile`, `make docker`, `make checksums`). Generated projects render Tier-1 output and pass `koncept policy check` out of the box.
>
> Update 2026-05-30 (later): added `koncept init module <type> <name>` scaffolding for `webapp`, `database`, `postgres`, `redis`, `kafka`, `mongodb`, and `rabbitmq` (generates a module def under `modules/<area>/` and prints paste-ready stack wiring), and extended `koncept policy check` with two new rules — `no-secret-literals` (secret-looking env values must use a Secret reference) and `require-namespace` (Tier-1 workloads must declare an explicit namespace). Generated modules compile, render, and pass policy in a fresh project.
>
> Update 2026-05-30 (later still): completed the Phase B project-lifecycle scaffolding with `koncept init env <name>` (adds a profile + site + pre-release factory for an environment — `dev|stg|prod` presets plus arbitrary names) and `koncept init release <version>` (adds a versioned stack, a shared production site, and an immutable `releases/<version>_production/factory`). Both generators mirror the proven `erp_back` layout, never overwrite existing files, and were verified to `kcl run` cleanly in a freshly scaffolded project (staging renders the dev image tag, the release pins its own `appVersion`). Extended `koncept policy check` with the `require-network-policy` rule (warns when a namespace runs workloads but has no NetworkPolicy, encouraging a default-deny posture). All Go package tests pass.
>
> Update 2026-05-30 (golden workflow): shipped the golden render-drift review gate. `koncept golden check` now prints a concise line diff on drift (new `internal/golden` package, unit-tested), `scripts/golden.sh check|update` is the single entrypoint over the reference factories, and committed snapshots guard the `erp_back` dev (`yaml`+`argocd`), stg (`yaml`), and v1.0.0 production (`yaml`) factories. CI (`validate.yml`) runs `scripts/golden.sh check` after the policy gate. Renders are deterministic via the Go CLI's `WithSortKeys`. New workflow doc: `docs/GOLDEN_OUTPUTS.md`.
>
> Update 2026-05-31: added explicit policy exemptions for `koncept policy check` via `--exemptions <file>`. Exemptions are narrow (`rule` + workload target), owned, reasoned, and expiring; invalid, expired, or stale waivers fail the command. New workflow doc: `docs/POLICY_EXEMPTIONS.md`.
>
> Update 2026-05-31 (changelog workflow): added `koncept changelog new|check|render` for framework/platform release-note fragments under `.changes/unreleased/`. Fragments use Keep-a-Changelog categories and require owner metadata; CI validates fragments so release intent is reviewed with code. New workflow doc: `docs/CHANGELOG_WORKFLOW.md`.
>
> Update 2026-05-31 (framework compatibility): started Phase D with descriptive framework compatibility metadata before remote package publishing. `framework.models.compatibility.FrameworkCompatibility` can now be attached to `Stack`, `StackInstance`, and `Release`; `koncept init project` emits `koncept.yaml` plus stack compatibility metadata; and `koncept doctor` prints framework source/version constraints/support tier/tested versions. New workflow doc: `docs/FRAMEWORK_VERSIONING.md`.
>
> Update 2026-05-31 (Backstage catalog): improved the developer-portal path by enriching `kcl_to_backstage` entities with namespace, asset version, image/chart annotations, and `spec.dependsOn` relationships from framework dependencies. The Backstage custom action now targets the current Go CLI lifecycle commands (`init project|module|env|release|factory`) instead of the old init flag shape.
>
> Update 2026-05-31 (telemetry, packaging, runtime CI, governance docs): shipped Phase G opt-in **local** telemetry (`internal/metrics` + `koncept metrics`, enabled by `--metrics`/`KONCEPT_METRICS`, recorded as on-disk JSONL with coarse error categories — see `docs/PLATFORM_METRICS.md`); added `.github/workflows/release.yml` to publish cross-platform binaries + checksums and push a pinned GHCR image on `v*` tags (Phase A); added `.github/workflows/runtime.yml` for nightly/dispatch real-cluster runtime acceptance separate from the fast PR gate (Phase E); declared output **support tiers** and made the Go CLI the documented default in the README (Phase A); documented framework SemVer rules and a worked local-path→pinned `kcl.mod` migration in `docs/FRAMEWORK_VERSIONING.md` (Phase D); and added `docs/OPERATING_MODEL.md` covering roles, change categories, and approval paths (Phase F).
>
> Update 2026-05-31 (service-catalog metadata): completed the Phase F catalog-metadata deliverable. `framework.models.metadata.Metadata` gained explicit `sloTier`, `dataClassification`, and `runbook` fields (alongside existing `costCenter`/`support`), `RenderStack` now carries optional `metadata`, and `procedures.kcl_to_backstage.generate_catalog_from_stack` emits these as `koncept.io/*` annotations on every Domain/System/Component/Resource entity while letting `owner`/`lifecycle` override render defaults. The `erp_back` shared stack demonstrates the full set, and new procedure tests guard the behaviour (421 KCL + Go tests and golden `yaml`/`argocd` snapshots remain green).
>
> Update 2026-05-31 (init --wire + generated goldens): completed Phase B's generated golden fixtures and the long-deferred `init module --wire` enhancement together. `koncept init project` now emits stable wire markers in the generated stack; `koncept init module --wire` performs marker-scoped, fail-loud auto-wiring (refuses unmarked stacks, rejects re-wiring, never parses arbitrary KCL); and `scripts/golden_generated.sh` scaffolds webapp / webapp+postgres / webapp+redis / webapp+kafka end-to-end and snapshots the rendered Tier-1 YAML under `tests/golden_generated/`. CI gained the generated-golden check and a marker-contract unit test. See `docs/GOLDEN_OUTPUTS.md`.
>
> Update 2026-06-01 (Kubernetes metadata mirroring): completed the remaining Phase F metadata propagation gap for Tier-1 YAML/ArgoCD output. `procedures.kcl_to_yaml.yaml_stream_stack` now applies `RenderStack.metadata` centrally to rendered Kubernetes manifests: catalog fields (`owner`, `team`, `lifecycle`, `tier`, `sloTier`, `criticality`, `dataClassification`, `costCenter`, `runbook`, `support`) become `koncept.io/*` annotations, explicit `Metadata.annotations` are merged into manifest annotations, and explicit `Metadata.labels` are merged into manifest labels. Resource-specific labels/annotations win on conflicts, avoiding global metadata overwrites; arbitrary catalog fields are intentionally not inferred as labels because URLs/entity refs can violate Kubernetes label value constraints.
>
> Update 2026-06-01 (Helmfile/Crossplane V2 output parity): prioritized depth on existing strategic outputs before adding new breadth. Safe `RenderStack.metadata` catalog fields (`owner`, `team`, `lifecycle`, `tier`, `sloTier`, `criticality`, `dataClassification`, `costCenter`) plus explicit `metadata.labels` now flow into Helmfile top-level `labels`, `commonLabels`, and generated release labels, with Helmfile-specific options still taking precedence. Crossplane V2 rendering now has a stack-aware entrypoint and applies the same metadata labels/annotations used by YAML/ArgoCD to XRDs, Compositions, XRs, prerequisite Provider/Function resources, Crossplane `Object` wrappers, and the wrapped Kubernetes manifests. This closes an adoption/governance gap for the two outputs most likely to be used by platform/infrastructure teams.
>
> Update 2026-06-01 (Helmfile/Crossplane V2 ordering parity): implementation learning showed that metadata parity is necessary but not sufficient for production coherence. Helmfile generated releases now derive `needs` from framework component/accessory `dependsOn` relationships while allowing `releaseOverrides` to replace those values when operators need exact Helmfile orchestration. Crossplane V2 namespace dependency rules now point at the actual generated `ns-*` resources consumed by `function-sequencer`, aligning the rendered composition with the IDP dependency graph.
>
> Update 2026-06-01 (Crossplane V2 maturity research): the current Crossplane V2 output is now classified as a bridge, not the professional target architecture, when it wraps finalized Kubernetes manifests in `provider-kubernetes` Objects. Research against official Crossplane docs, crossplane-contrib functions, `vfarcic/crossplane-kubernetes`, and Upbound reference platforms sets a higher bar: typed intent-level XRDs/Claims, provider-native managed resources where available, versioned `function-kcl`/`function-go-templating` or custom Go functions for composition logic, explicit connection/status contracts, composition revision rollout strategy, and reconciliation/update/delete tests before support.
>
> Update 2026-06-03 (doc consolidation + Crossplane vs. templates clarification): consolidated the standalone root planning notes (`EVOLUTION_IMPLEMENTATION_2026_06_03.md`, `EVOLUTION_PHASE_5_2026_06_03.md`, `IMPLEMENTATION_PLAN_2026_06.md`) into this single roadmap and deleted them so this document remains the one source of truth for maturity state (Section 5.5). Their substance now lives in Sections 12.2 (delivered Helmfile/observability/distribution work) and 12.1 (Crossplane runtime fixtures). Also added Section 5.7 to answer a recurring architecture question: what `crossplane_v2/` is for, why Crossplane output is *generated* yet the directory is still *hand-authored*, and why `crossplane_v2/managed_resources/` is a curated subset of `framework/templates/` rather than a 1:1 mirror. Phase E2 gained explicit deliverables to close the template↔managed-resource parity gap and document the selection policy.
>
> Update 2026-06-03 (experimental no-legacy policy): formalized that this is a **first experimental IDP that keeps no legacy, no backward-compatibility shims, and no two versions of the same thing** (Section 1, Project Principles). Applied it immediately by **deleting** the superseded manifest-wrapping PostgreSQL Crossplane bridge (`*_legacy.yaml`, `LEGACY_MIGRATION.md`, the unused `postgres_init.sql`) and renaming the CNPG files to the single canonical set (`xrd_postgres.yaml`, `x_postgres.yaml`, `xr_instance_postgres.yaml`, API `xpostgresinstances.koncept.bluesolution.es`). Stale `docs/WORKFLOWS.md` paths were corrected, and a new AI resource (`.github/skills/crossplane-architecture/SKILL.md` + `.github/instructions/crossplane-architecture.instructions.md`) captures the two-track model so future automated changes do not reintroduce legacy or a `provider-kubernetes` Object wrapper for application workloads.
>
> Update 2026-06-07 (credentials, identity, and publishing-scope hardening): (1) **Credentials never leave the machine.** The git-ignored `credentials/` folder is the single source for the GHCR token (`credentials/ghcr.env`); `.gitignore` was made explicit (`/credentials/`, `**/credentials/`, `*credentials`, `*.credentials`) and verified untracked. (2) **Publishing reads the token from that folder** — added `scripts/publish_oci.sh {image|framework|all}` which authenticates with `--password-stdin` and never prompts for, echoes, or accepts a token on the command line. `docs/GHCR_PUBLISHING_GUIDE.md`, `docs/CLI_DISTRIBUTION.md`, and `docs/archive/EVOLUTION_IMPLEMENTATION_CHECKLIST.md` were rewritten to use this flow instead of `export CR_PAT=...`. (3) **Corrected wrong identity URLs.** Documentation that referenced `https://github.com/idp-concept/...` and `ghcr.io/idp-concept:...` now uses the real owner: repo `https://github.com/Javier-Godon/idp-concept`, GHCR namespace `ghcr.io/javier-godon`, CLI image `ghcr.io/javier-godon/idp-concept/koncept`, framework package `oras://ghcr.io/javier-godon/idp-concept-framework`. (The `github.com/idp-concept/koncept` strings in `cmd/koncept/**` are the Go *module path* — code identity — and are intentionally left unchanged.) (4) **Clarified what is published vs. what is an example.** The published artifacts are the framework OCI module, the `koncept` CLI image, and the CLI binaries. The `projects/` directory (`video_streaming`, `erp_back`, `pokedex`) is explicitly documented as **reference example usage**, not a shipped artifact (see Section 6a). (5) **Crossplane location question recorded.** The recurring "should `crossplane_v2/` live under `framework/templates/`?" question is addressed in Section 5.7 with the decision and rationale.


---

## 1. Executive Assessment

### Project Principles (read first)

> **This is a first experimental version of an IDP.** It deliberately keeps the surface area minimal:
>
> - **No legacy.** Superseded code, schemas, and manifests are **deleted**, not deprecated-in-place.
> - **No backward-compatibility shims.** Breaking changes are made cleanly; consumers update with the framework.
> - **No two versions of the same thing.** Every template, procedure, and managed resource has exactly one
>   canonical implementation. We do not keep `*_legacy`, `*_v2`, or parallel "old/new" variants side by side.
>
> These rules apply to all human and AI changes. When something is replaced, remove the predecessor in the
> same change. AI agents must not reintroduce compatibility layers or alternate versions "just in case".

### Is this IDP useful for a medium company?

**Yes — with the right scope and ownership model.**

This IDP is useful when the company has several Kubernetes-based products and wants a shared platform team to provide:

- standard application and infrastructure templates,
- consistent environment/tenant/site configuration layering,
- repeatable release rendering,
- GitOps-friendly output,
- typed configuration validation,
- a growing internal service catalog,
- optional compatibility with Helm, Helmfile, Kustomize, Crossplane, Timoni, Kusion, and Backstage.

It is **not** trying to be a generic “big tech” platform framework for every technology stack. That is a good constraint. For a medium company, the strongest value is not the number of output formats; it is the ability to standardize the 80% use cases across products while still allowing platform engineers to extend the framework for the remaining 20%.

### Short verdict

| Question | Assessment |
|---|---|
| **Useful?** | **Yes**, especially for Kubernetes/GitOps-oriented products that need shared templates and multi-environment rendering. |
| **Easy for application developers?** | **Potentially yes**, if developers use Backstage or simple `koncept` commands and do not edit KCL internals. Direct KCL authoring is not developer-friendly enough yet. |
| **Easy for platform engineers?** | **Moderate**. The template approach in `projects/erp_back/` is usable, but the framework has a large concept surface. |
| **Easy to create a new project?** | **Not yet easy enough**. The structure is clear, but project creation still requires many coordinated files unless Backstage or a richer Go CLI scaffold is used. |
| **Best-practice alignment?** | **Good foundation**: typed configs, GitOps outputs, operator-backed infra, tests, acceptance matrix, secret-reference patterns, CI policy gates, and golden drift review. Remaining: versioned distribution, platform telemetry, and production runtime validation for operators. |
| **Main risk?** | Too much framework surface area too early: many outputs, many templates, two CLIs, and stale docs can make adoption harder than the platform problem itself. |

### Recommended positioning

Use this as a **company-specific platform product**, not as a general-purpose open-source framework.

A good medium-company operating model would be:

1. **Developers** request or configure services through Backstage or a small set of CLI commands.
2. **Product platform champions** edit project-level KCL modules/stacks only when needed.
3. **Central platform engineers** maintain `framework/`, templates, output procedures, policy, testing, and distribution.

---

## 2. What Works Well Today

### 2.1 Strong architectural ideas

- **Single source of truth**: KCL models produce multiple deployment outputs from one definition.
- **Layered configuration**: `kernel → profile → tenant → site` is a good model for a medium company with several products, customers, and environments.
- **Template-first development**: `projects/erp_back/` demonstrates the right path: high-level templates instead of raw Kubernetes boilerplate.
- **Schema + instance pattern**: provides a predictable boundary between validated authoring schemas and flattened render data.
- **Framework/project separation**: `framework/` vs `projects/<name>/` maps well to platform-team vs product-team responsibility.
- **RenderStack path**: acceptance fixtures render through the same stack-to-YAML path used by real factories, which is a solid testing design.

### 2.2 Good engineering practices already present

- **416 passing KCL tests** verified by `./scripts/verify.sh`.
- **Acceptance testing strategy** with fast render checks, server-side dry-run, lightweight kind apply, and opt-in runtime checks.
- **Operator-backed infrastructure templates** for PostgreSQL, MongoDB, Kafka, RabbitMQ, Redis, Keycloak, OpenSearch, MinIO, OpenTelemetry, and related platform services.
- **Pinned/versioned template imports** under `framework/templates/<ecosystem>/<version>/...`.
- **Security-conscious conventions**: no hardcoded credentials in generated examples, use of Secret references, no privileged defaults, pinned images/charts expected.
- **Backstage assets**: catalog, plugin guide, and scaffolder templates exist, which is important for self-service adoption.
- **Go CLI is the single interface** under `cmd/koncept/`, distributed as the installable package.

### 2.3 Good fit for medium-company needs

The IDP is strongest for companies with:

- 5–50 services/products,
- a small platform team,
- Kubernetes as the standard runtime,
- GitOps as the deployment pattern,
- repeated infrastructure needs across products,
- several environments or customer-specific deployments,
- desire to move developers away from direct Kubernetes YAML authoring.

---

## 3. Usability Assessment

### 3.1 Developer experience

**Current state:** usable only if developers stay behind CLI/Backstage abstractions.

For a typical application developer, KCL, factory directories, module imports, `.instance`, and `kcl.mod` resolution are too much detail. The intended developer path should be:

```bash
koncept init app
koncept render argocd
koncept validate
koncept diff
```

or a Backstage form that generates and validates the change.

**Assessment:**

| Area | Current rating | Reason |
|---|---:|---|
| Render existing environment | Good | `koncept render` and `kcl run render.k -D output=...` paths exist. |
| Understand what changed | Medium | Go CLI has `diff`, but golden-output and PR annotation workflows need to be institutionalized. |
| Add environment-specific config | Medium | The model is good, but requires KCL familiarity today. |
| Add a new service | Medium/Low | Templates help, but scaffolding and documentation need simplification. |
| Debug errors | Medium/Low | KCL errors and module-resolution errors can be unfamiliar. More curated CLI diagnostics are needed. |

### 3.2 Platform engineer experience

**Current state:** powerful but concept-heavy.

A platform engineer can create templates, builders, and output procedures, and the test suite gives confidence. However, the architecture has many moving parts:

- KCL module system,
- framework schemas,
- project schemas,
- stack assembly,
- release/pre-release factories,
- render procedures,
- many output formats,
- Backstage templates,
- a single Go CLI surface.

**Assessment:** this is acceptable for a central platform team, but too much for occasional product-team contributors. The platform should provide **golden paths** and discourage casual framework modification.

### 3.3 New project creation

**Current state:** structurally clear but not easy enough.

A new project currently needs coordinated files for:

- `kcl.mod`,
- `kernel/`,
- `core_sources/`,
- `modules/`,
- `stacks/`,
- `tenants/`,
- `sites/`,
- `pre_releases/` or `releases/`,
- factory files.

The `erp_back` pattern is the right reference, but a medium company should not ask every team to copy it manually.

**Target:** one command or one Backstage flow should create a minimal, validated project:

```bash
koncept init project erp-back \
  --template webapp-postgres \
  --tenant vendor \
  --env dev \
  --output argocd

koncept validate --all
koncept render argocd --all
```

---

## 4. Best-Practice Alignment

### 4.1 Practices followed well

| Practice | Evidence |
|---|---|
| **Platform as a product** | Dedicated CLI, docs, templates, test suite, Backstage artifacts. |
| **Golden paths** | `WebAppModule`, database/cache/messaging/search/observability templates. |
| **Typed contracts** | KCL schemas, check blocks, framework model layer. |
| **GitOps readiness** | YAML/ArgoCD/Kustomize/Helmfile render paths. |
| **Environment separation** | Kernel/profile/tenant/site layering. |
| **Operator-first stateful services** | CNPG, Strimzi, MongoDB Community Operator, RabbitMQ, Redis, Keycloak, OpenSearch. |
| **Testing pyramid** | Unit tests, render fixtures, server dry-run, lightweight apply, opt-in runtime tests. |
| **Security direction** | Secret references, pinned versions, no privileged defaults. |

### 4.2 Practices partially implemented

| Practice | Current gap |
|---|---|
| **Self-service onboarding** | Backstage templates exist, but the CLI and docs still expose too much internal structure. |
| **Versioned platform distribution** | Projects still primarily depend on local path-based framework modules. |
| **CI/CD governance** | `.github/workflows/validate.yml` now runs Go tests, render smoke, policy gate, changelog-fragment validation, golden drift check, `scripts/verify.sh`, and `git diff --check`. Remaining: golden coverage for more projects and required-check enforcement/branch protection. |
| **Policy as code** | Enforced in CI via `koncept policy check` (privileged/latest/resources/owner/secret-literal/namespace/network-policy rules) with explicit owner/reason/expiry exemptions. Remaining: external OPA/Kyverno admission parity. |
| **Golden-file review workflow** | Shipped: `koncept golden check` with inline drift diff, `scripts/golden.sh`, committed snapshots for the `erp_back` reference factories, and a CI drift gate. Remaining: extend to more reference projects/formats. See `docs/GOLDEN_OUTPUTS.md`. |
| **Output metadata parity** | YAML/ArgoCD, Backstage, Helmfile, and Crossplane V2 now consume `RenderStack.metadata` for their supported metadata surfaces. Remaining: decide whether Tier 2/3 formats such as Helm/Kustomize/Timoni/Kusion need the same support based on real consumers. |
| **Crossplane V2 professional management** | Current output can generate Crossplane packages, but the bridge still wraps Kubernetes manifests in provider-kubernetes Objects. Target: intent-level XRDs, provider-native resources, composition functions, explicit status/connection details, composition revisions, and lifecycle tests. See `docs/CROSSPLANE_PATTERNS.md`. |
| **Operational telemetry** | No platform adoption/error/render metrics yet. |
| **Runtime proof for operators** | Many operator-heavy cases are dry-run only unless opt-in runtime scripts are used with real dependencies. |

### 4.3 Practices to avoid

- Do not optimize for “all output formats are equally important.” Pick a company default, likely ArgoCD YAML or Helmfile, and keep other outputs as compatibility paths.
- Do not let product teams fork framework internals. Provide extension points, versioned packages, or platform-team-owned changes.
- Do not make every developer learn KCL. Use KCL as the platform configuration language, not as the primary developer UX.
- Do not treat dry-run CRD stubs as production validation. They are useful for schema shape checks only.
- Do not promote Crossplane V2 APIs that are just large `provider-kubernetes` Object wrappers around copied Deployments, Services, ConfigMaps, or CRDs. Use Object only for small cluster glue or temporary migration bridges with tests and an exit path.

---

## 5. Main Design Risks and Bad Smells

### 5.1 Output-format sprawl

The 9-output strategy is a differentiator, but it can become a maintenance burden. Every new template must keep outputs coherent across YAML, Helm, Helmfile, Kustomize, Timoni, Crossplane, Backstage, etc.

**Recommendation:** define support tiers:

| Tier | Outputs | Support expectation |
|---|---|---|
| Tier 1 | `yaml`/`argocd`, `helmfile`, `backstage` | Fully tested and documented for company usage. Governance metadata must flow through the output's native metadata surface. |
| Tier 2 | `helm`, `kustomize`, `crossplane` | Maintained for platform/infrastructure teams. Crossplane V2 now has stack metadata parity because it is a priority infrastructure output. |
| Tier 3 | `timoni`, `kusion` | Experimental unless adopted by a real product team. |

### 5.2 Single CLI implementation

**Resolved.** The project standardized on a single Go binary (`cmd/koncept`). The earlier
Nushell CLI and its Taskfile wrappers have been removed; there is no longer any CLI
duplication or coexistence to maintain.

### 5.3 Factory duplication

Each release/pre-release has factory files. That is understandable, but copied render contracts can drift.

**Recommendation:** keep factories minimal and generated. Long-term, factory discovery and render contracts should be managed by the CLI and framework conventions, not hand-copied.

### 5.4 Project scaffolding is incomplete

The current Go `init` command scaffolds a factory, not a full project/product. Backstage templates cover some workflows, but the CLI should support full project lifecycle scaffolding too.

**Recommendation:** prioritize `koncept init project`, `koncept init module`, `koncept init env`, and `koncept init release` before adding more output formats.

**Implementation learning (2026-05-30):** `koncept init module` deliberately *generates the module def file and prints a paste-ready stack wiring snippet* rather than programmatically editing the stack `.k` file. Auto-rewriting KCL with regex/AST surgery is brittle and risks corrupting hand-authored stacks; printing a verified snippet keeps the secure path while still removing the boilerplate. Infra modules are emitted as accessories under `modules/infraops/` and webapps as components under `modules/appops/`, matching the framework's component/accessory split. Generated webapp + postgres modules were verified to compile, render, and pass `koncept policy check` in a fresh scaffolded project. A future enhancement can offer an opt-in `--wire` flag that appends to a clearly marked stack region once a stable insertion marker convention exists.

**Implementation learning (2026-05-31, `init module --wire`):** the opt-in `--wire` flag from the 2026-05-30 note shipped, built on the secure path that note required. `koncept init project` now emits four stable markers in the generated stack (`# koncept:imports:end`, `# koncept:modules:end`, and trailing `# koncept:components` / `# koncept:accessories` on the list lines). `--wire` edits *only* inside those markers: it inserts the import before the imports marker, the `_<module> = ...{}.instance` block before the modules marker, and appends the instance var to the correct list line. Three guarantees keep it from corrupting hand-authored stacks: (1) if any required marker is absent it refuses and falls back to printing the paste snippet, leaving the file byte-for-byte unchanged; (2) re-wiring an already-present module errors instead of duplicating; (3) it never parses arbitrary KCL — only marker lines and the bracketed list region are touched, so the brittle "regex/AST surgery" the original note warned against is avoided. This unblocked Phase B's generated golden fixtures: `scripts/golden_generated.sh` now scaffolds webapp / webapp+postgres / webapp+redis / webapp+kafka end-to-end (project + `--wire` + render) and snapshots the rendered YAML, so the scaffolding templates, the wiring, and the framework templates are all drift-guarded together. A new project test locks the marker contract so wiring can never silently regress.

**Implementation learning (2026-05-30, env/release):** `koncept init env` and `koncept init release` reuse the same template engine and "never overwrite, fail loudly" guarantees as `init project`/`init module`. Two design choices proved important: (1) *shared vs. owned files* — a release's production site (`sites/production/default/...`) and `releases/kcl.mod` are shared across versions, so they are skipped-if-present rather than treated as errors, while version-specific stack/factory files must not pre-exist; this lets a project accumulate `v1_0_0`, `v2_0_0`, ... without manual cleanup. (2) *render-friendly defaults* — generated environments default to `storageClassName = "local-path"` and `useLocalPersistentVolumes = True` so a brand-new environment renders and applies on a laptop/kind cluster out of the box; teams harden these for real staging/production. Both new factories were verified to `kcl run` cleanly: staging inherits the shared stack's image tag, while the release stack pins its own `appVersion`. The CLI prints the exact `--factory` path for `validate`/`render`/`policy check`, mirroring the secure no-auto-edit philosophy of `init module`.

### 5.5 Documentation drift

Some docs describe desired future capabilities as already complete. This is risky for adoption: teams will trust the platform less if docs and implementation diverge.

**Recommendation:** add a documentation verification checklist to every release and keep this document as the source of truth for maturity state.

### 5.6 KCL expertise bottleneck

KCL is a strong fit for typed configuration, but it is niche. A medium company should assume few engineers know it.

**Recommendation:** centralize KCL expertise in the platform team, provide generated examples, and use Backstage/CLI workflows for most users.

### 5.7 Crossplane: "generated output" vs. the hand-authored `crossplane_v2/` directory

A recurring and legitimate question is: *if Crossplane manifests are supposed to be **generated** from the single source of truth, what is the `crossplane_v2/` folder for, and shouldn't `managed_resources/` mirror `framework/templates/` one-for-one?*

The short answer: there are **two different Crossplane concerns**, and conflating them is the source of the confusion.

| Concern | Location | Authored how | Purpose |
|---|---|---|---|
| **Generated Crossplane output** | `framework/procedures/kcl_to_crossplane.k` (+ `koncept render crossplane`) | **Generated** from any stack | One of the 9 output formats. Turns a rendered stack into XRD + Composition + XR + prerequisites. Today it is a **bridge**: it wraps finalized K8s manifests in `provider-kubernetes` `Object`s (see Section 5.1 anti-pattern note and `docs/CROSSPLANE_PATTERNS.md` §12). |
| **Hand-authored Crossplane platform** | `crossplane_v2/` | **Hand-authored, not generated** | Cluster prerequisites + curated, professional reference platform APIs. This is the *maturity target* the generated path should converge toward. |

`crossplane_v2/` itself has two sub-roles, and only one of them is even a candidate for mirroring templates:

1. **`crossplane_v2/providers/` and `crossplane_v2/functions/`** — pinned Provider installs (`provider-kubernetes`, `provider-helm`) and Composition Function installs (`function-kcl`, `function-patch-and-transform`, `function-sequencer`, `function-auto-ready`, `function-go-templating`). These are **cluster-level bootstrap**, installed once per cluster. They are *not derivable from a stack* and have no relationship to `framework/templates/`.
2. **`crossplane_v2/managed_resources/`** — hand-authored, intent-level XRD/Composition/XR examples (cert-manager, Kafka/Strimzi, Keycloak, PostgreSQL/CNPG). These are the **professional reference APIs**: provider-native resources and operator CRDs instead of manifest-wrapping. They demonstrate the bar from `docs/CROSSPLANE_PATTERNS.md`.

> **Experimental, single-version policy.** This is a first experimental IDP. The repository keeps **no legacy,
> no backward-compatibility shims, and no two versions of the same thing**. When a resource is superseded
> (e.g. the earlier manifest-wrapping PostgreSQL bridge that used `provider-kubernetes` Objects), the old
> version is **deleted outright** rather than parked behind a `*_legacy` suffix. Each managed resource has a
> single canonical file set (`xrd_<name>.yaml`, `x_<name>.yaml`, `xr_instance_<name>.yaml`). See the project
> principle in Section 1 / 5.5.

**Is the intuition "`managed_resources/` should contain the same elements as `framework/templates/`" correct?** *Partially.* It correctly identifies a coverage gap and an inconsistency, but the **target is a curated subset, not a 1:1 mirror**, for two reasons:

- **Not every template should become a Crossplane API.** Per `docs/CROSSPLANE_PATTERNS.md` §4 (Pattern 4) and §7, *application workloads* (e.g. `WebAppModule`, generic `SingleDatabaseModule`) belong to Tier-1 GitOps YAML/ArgoCD, **not** to Crossplane wrapping every Deployment/Service. Crossplane earns its place only for **platform/infrastructure control-plane services** where a typed self-service API plus ongoing reconciliation/lifecycle management adds real value (databases, messaging, identity, certificates, object storage, secrets).
- **The two tracks must converge, not duplicate.** Today a template like PostgreSQL can produce Crossplane two unrelated ways: (a) the generated *bridge* via `kcl_to_crossplane`, and (b) the hand-authored *professional* `managed_resources/postgres` (CNPG). They are currently disconnected. The fix is to define a **selection policy** (which templates warrant a Crossplane API), publish a **parity matrix**, close the gaps, and make the generated path emit/reference the professional APIs instead of opaque `Object` blobs.

So `crossplane_v2/` is genuinely necessary (prerequisites can never be "generated away", and the reference APIs define the quality bar), but `managed_resources/` should track a **documented, curated subset** of `framework/templates/` — the infrastructure/middleware ones — with explicit parity tracking. The concrete work to resolve this is in **Phase E2** (Section 12.1) and the policy/matrix is documented in `docs/CROSSPLANE_PATTERNS.md`.

### 5.7.1 "Should `crossplane_v2/` just live under `framework/templates/`?"

This is a fair question — `managed_resources/` really is "the same infrastructure, expressed
in Crossplane form", so co-locating it with `framework/templates/` is intuitive. The decision
is to **keep `crossplane_v2/` as its own top-level track, not fold it into `framework/templates/`**,
for three concrete reasons:

1. **Two of its three contents are not templates at all.** `crossplane_v2/providers/` and
   `crossplane_v2/functions/` are **cluster bootstrap** (pinned Provider/Function installs applied
   once per cluster). They are not derivable from a stack, are not imported by any KCL package, and
   have no analogue under `framework/templates/`. Moving them under `templates/` would mislabel
   cluster prerequisites as reusable module templates.
2. **Different authoring and lifecycle model.** `framework/templates/` are KCL schemas consumed by
   the render path and packaged into the published framework OCI module. `crossplane_v2/` is
   hand-authored YAML applied directly to a cluster and is **not** part of the published framework
   package. Mixing them would force one of them to change packaging/versioning model.
3. **The intended end-state is convergence, not relocation.** Per Phase E2, the *generated*
   `kcl_to_crossplane` path should eventually emit/reference the curated `managed_resources/` APIs.
   That convergence is about the **render procedure** referencing the curated APIs, which works
   regardless of directory location; physically nesting the YAML under `templates/` does not advance
   it and would churn the Go CLI (`internal/crossplane`), scripts, and the acceptance matrix.

What *did* change to address the underlying confusion: the published-vs-example boundary is now
explicit (Section 6a), `crossplane_v2/` is documented as an applied-per-cluster, non-published track,
and the parity matrix (Section 12.1) keeps the `templates/` ↔ `managed_resources/` relationship
reviewable. If a future decision still wants relocation, the cleanest target would be a top-level
`framework/crossplane/` (NOT `framework/templates/`), keeping prerequisites and curated APIs together
but clearly separate from KCL templates — and it must update the CLI, scripts, skill, and instructions
in the same change.


---

## 6. Missing or Underdeveloped Features

### Highest impact missing capabilities

1. **Full new-project scaffolding**
   - Generate a complete `projects/<name>/` with one app, one environment, and passing validation.

2. **Primary Go CLI distribution**
   - Release binaries, container image for CI, installation docs, and shell completions.

3. **CI workflow in repository**
   - Run `./scripts/verify.sh`, Go tests, `git diff --check`, and selected acceptance tests on PRs.

4. **Golden-output workflow**
   - Shipped for the `erp_back` reference factories; extend only when another project/format has a real consumer that needs snapshot review.

5. **Policy-as-code gate**
   - Enforce no `latest` tags, no privileged pods, required resources, required labels, secret-looking values must use Secret references, and namespace/network policy conventions.

6. **Framework versioning/distribution**
   - Publish `framework` as versioned KCL/OCI artifacts or at least tag and pin framework compatibility per project.

7. **Support tiers and deprecation policy**
   - Make it clear which templates/outputs are production supported vs experimental.

8. **Runtime acceptance for real operators**
   - Nightly or pre-release jobs that install real pinned operators and verify Ready conditions for selected production templates.

9. **Platform metrics**
   - Track render failures, validation failures, template usage, project count, onboarding time, and most common errors.

10. **Developer-facing service catalog metadata**
    - Owners, lifecycle, SLO tier, data classification, cost center, docs, runbooks, and support contacts now flow into the Backstage catalog via `models.metadata.Metadata` on the `Stack` (rendered as `koncept.io/*` annotations). The Tier-1 YAML/ArgoCD path now mirrors those catalog fields to Kubernetes annotations and merges explicit stack labels/annotations into rendered manifests.

11. **Crossplane V2 maturity**
    - Replace "hello world" and manifest-wrapping Crossplane examples with professional platform APIs: typed XRDs/Claims, provider-native managed resources, versioned composition functions, explicit status/connection handling, and real reconciliation/update/delete tests.

---

## 6a. What This Project Publishes vs. What Is an Example

A recurring adoption question is *"what exactly do consumers install, and what is just a demo?"*
The answer keeps the surface area small and explicit:

| Item | Role | Published? | Reference |
|---|---|---|---|
| `framework/` | The reusable platform (schemas, builders, templates, procedures) | **Yes** — versioned OCI module | `oras://ghcr.io/javier-godon/idp-concept-framework:<version>` |
| `cmd/koncept/` | The single CLI interface | **Yes** — binaries + container image | `ghcr.io/javier-godon/idp-concept/koncept:<version>` + GitHub Release assets |
| `projects/video_streaming`, `projects/erp_back`, `projects/pokedex` | **Reference example usages** of the framework | **No** | Copy-as-starting-point; `erp_back` is the recommended template-first layout |
| `crossplane_v2/` | Hand-authored cluster prerequisites + curated reference Crossplane APIs | **No** (applied per cluster) | See Section 5.7 |
| `backstage/` | Catalog + scaffolder assets | **No** (deployed into a Backstage instance) | `docs/BACKSTAGE_PLUGIN_GUIDE.md` |

So the **only two consumable, versioned artifacts are the framework OCI module and the
`koncept` CLI**. Everything under `projects/` is intentionally an example: it exists to
demonstrate the framework and to back golden/acceptance tests, not to be pulled as a
dependency. Publishing tooling (`scripts/publish_oci.sh`) therefore only ever packages
`framework/` and the CLI image — never `projects/`.

---



The previous roadmap emphasized many future phases. Given the current state, the next work should be more focused: **productize the golden path before expanding the framework**.

### Roadmap principles

1. **Adoption before breadth**: improve the developer/platform-engineer workflow before adding output formats.
2. **One default deployment path**: choose a company default output and make it excellent.
3. **Automate project creation**: no manual copy-paste onboarding.
4. **Version and govern the platform**: framework changes must be reviewable, testable, and reversible.
5. **Measure usefulness**: collect opt-in/internal metrics and feedback loops.

---

## 8. Phase A — Productize the Golden Path (P0)

**Goal:** make the IDP easy and safe for a medium company to adopt for real products.

### Deliverables

- [x] Declare Tier 1 outputs: `yaml`/`argocd`, `helmfile`, and `backstage`. (README "Output Formats" now groups all outputs into Tier 1/2/3 with support expectations.)
- [x] Update README and quickstart to make the Go CLI the path. (Prerequisites lead with Go; Nushell removed.)
- [x] Build and publish Go CLI binaries for Linux/macOS/Windows. (`make build-all`/`make checksums` cross-compile + checksum; `.github/workflows/release.yml` publishes them as GitHub Release assets on `v*` tags.)
- [x] Publish a pinned container image for CI usage. (`cmd/koncept/Dockerfile` + `make docker` build a pinned image; `release.yml` pushes it to GHCR on tags.)
- [x] Remove the Nushell CLI and Taskfile wrappers; the Go CLI is the single interface.
- [x] Add shell completions and concise error messages for common KCL module-resolution failures.
- [x] Verify the Go CLI render paths against the same smoke matrix used by `scripts/verify.sh`.
- [x] Fix any Go CLI output routing mismatches found during verification, especially ensuring each render command calls the matching KCL output format.
- [x] Add a `koncept doctor` command for dependency, version, path, and factory checks.

### Success criteria

- A new developer can install one binary and render an existing environment in under 10 minutes.
- CI can run with one maintained container image.
- Docs require only the Go CLI as the user path.

---

## 9. Phase B — Make New Projects Easy (P0)

**Goal:** creating a project should be a guided workflow, not a file-copy exercise.

### Deliverables

- [x] `koncept init project <name>` creates a complete, validating project skeleton.
- [x] `koncept init module webapp <name>` adds a `WebAppModule` and prints its stack wiring.
- [x] `koncept init module postgres|redis|kafka|mongodb|rabbitmq <name>` adds common infrastructure templates.
- [x] `koncept init env <dev|stg|prod>` creates site/profile/pre-release structure.
- [x] `koncept init release <version>` creates immutable release structure.
- [x] Generated projects use the recommended minimal transitive `kcl.mod` pattern.
- [~] Backstage scaffolder actions call the same Go CLI scaffold lifecycle as local users (`koncept init project|module|env|release|factory`). Remaining: review every template workflow end-to-end in a real Backstage backend and keep generated YAML inputs aligned with the CLI scaffold fields.
- [x] Add golden generated fixtures for at least:
  - webapp only,
  - webapp + PostgreSQL,
  - webapp + Redis,
  - webapp + Kafka.
  (Shipped: `scripts/golden_generated.sh` scaffolds each combo with
  `koncept init project` + `koncept init module --wire`, renders Tier-1 `yaml`,
  and diffs against committed snapshots under `tests/golden_generated/<combo>/`.
  CI runs the check in the Go CLI job. The earlier `erp_back` factory goldens
  remain the hand-authored reference guard. See `docs/GOLDEN_OUTPUTS.md`.)

### Success criteria

- A platform engineer can create a new product skeleton and render Tier 1 outputs in under 15 minutes.
- New projects do not require manual knowledge of every directory in the architecture.

---

## 10. Phase C — Governance and CI/CD (P0/P1)

**Goal:** make platform changes safe for several products.

### Deliverables

- [x] Add `.github/workflows/validate.yml` or equivalent CI workflow.
- [x] CI runs:
  - `go test ./...` under `cmd/koncept`,
  - `./scripts/verify.sh`,
  - `git diff --check`,
  - selected CLI smoke checks for the ERP dev factory.
- [x] Add golden-output checks for reference projects.
- [x] Add policy-as-code checks for rendered YAML (`koncept policy check`):
  - [x] no privileged containers,
  - [x] no `latest` tags,
  - [x] resource requests/limits required for Tier 1 workloads,
  - [x] required ownership labels/annotations,
  - [x] secret-looking values must use Secret references,
  - [x] namespace and network-policy conventions (explicit-namespace rule and per-namespace default-deny NetworkPolicy convention both shipped as warnings).
- [x] Document and implement policy exemptions with owner, reason, and expiry.
- [x] Add release notes/changelog generation for framework changes.

### Success criteria

- Pull requests show whether KCL, Go CLI, rendered manifests, and policies pass.
- Render drift is visible and intentionally approved.
- Security conventions are enforced, not only documented.

**Implementation learning (2026-05-30, golden workflow):** golden snapshots were placed *next to each factory* (`<factory>/../golden/<format>/manifests.yaml`) rather than in a central `golden/` tree, so a project owns its snapshots alongside the factory that produces them and removing a factory removes its goldens. Determinism was the key risk: ad-hoc `kcl run` does not sort map keys, but the Go CLI render path uses `WithSortKeys(true)`, so `golden update`/`check` both go through `factory.Render` and are byte-stable — this is why the gate routes through the CLI, not raw `kcl run`. Coverage is deliberately scoped to Tier-1 `yaml`/`argocd` for the `erp_back` reference (a webapp+PostgreSQL stack) plus one `yaml` snapshot each for staging and the production release; multi-file formats (`helmfile`, `backstage`) are left to render smoke checks until a real consumer needs snapshot review, keeping the maintainer's "accept the diff" burden proportional to value. The drift output prints a prefix/suffix-elided line diff so reviewers see only the changed region in CI logs.

**Implementation learning (2026-05-31, policy exemptions):** the safer exemption path is not another `--no-*` rule toggle. Whole-rule disabling hides unrelated regressions and tends to persist in CI. The implemented model requires a `rule`, Kubernetes target (`kind` plus `namespace` or `name`), `owner`, `reason`, and `expiresOn`, and it fails on expired or stale exemptions. That makes an exemption a reviewable operational decision, not a quiet configuration default. Auto-discovery was deliberately avoided in this slice: CI should opt into a reviewed exemption file explicitly with `--exemptions`, so the presence of a local waiver file cannot accidentally weaken policy enforcement.

**Implementation learning (2026-05-31, changelog fragments):** framework release notes should be captured as close to the code change as possible, but not by hand-editing a long changelog during every small PR. The implemented workflow uses small YAML fragments in `.changes/unreleased/`, validates them in CI, and renders a release section only when preparing a platform release. This follows the industry pattern used by towncrier/changesets-style tooling while keeping the IDP low-dependency and Go-CLI-native. Owner metadata is required because release notes are also an accountability artifact for platform consumers; anonymous fragments are rejected. The command intentionally renders to stdout by default and writes only when `--file` is explicit, avoiding surprising edits to `CHANGELOG.md`.

---

## 11. Phase D — Framework Versioning and Multi-Repo Readiness (P1)

**Goal:** allow several products to consume the framework safely without all changing at once.

### Deliverables

- [x] Define semantic versioning rules for `framework/`. (Patch/minor/major table in `docs/FRAMEWORK_VERSIONING.md`.)
- [x] Add framework compatibility metadata to stacks/releases.
- [~] Publish framework packages as versioned OCI artifacts or a clearly tagged KCL module distribution. (Tooling shipped: `scripts/publish_oci.sh framework <version>` packages `framework/` and pushes `oras://ghcr.io/javier-godon/idp-concept-framework:<version>`, authenticating from the git-ignored `credentials/ghcr.env` so no token is ever prompted/echoed. Remaining: execute the first real publish and switch consuming projects to the pinned reference. See `docs/GHCR_PUBLISHING_GUIDE.md`.)
- [x] Provide migration docs from local path dependencies to version-pinned dependencies. (Worked `kcl.mod` before/after example in `docs/FRAMEWORK_VERSIONING.md`.)
- [x] Add `koncept deps` output suitable for troubleshooting module resolution.
- [x] Define support windows and deprecation policy for templates and output procedures.

### Success criteria

- Product A can stay on framework version `x.y.z` while Product B upgrades.
- Framework breaking changes have a documented migration path.

**Implementation learning (2026-05-31, framework compatibility):** the first safe step toward multi-repo readiness is a visible compatibility contract, not immediate OCI/package publishing. Generated projects now carry framework expectations in both `koncept.yaml` (for CLI/project diagnostics) and KCL stack metadata (for render-time/platform review context). The metadata remains optional and descriptive because existing projects still use local path dependencies and no authoritative remote version source exists yet. This matches the same secure rollout pattern used for policy exemptions: expose intent, make drift reviewable, then add enforcement only after real projects have pinned versions and migration docs.

---

## 12. Phase E — Production Runtime Confidence (P1/P2)

**Goal:** prove not only that manifests render, but that supported templates reconcile in real clusters.

### Deliverables

- [x] Keep `./scripts/verify.sh` as the fast default PR gate. (`validate.yml` runs it; runtime checks live in a separate workflow.)
- [x] Add nightly or release-candidate runtime jobs for selected real operators/controllers. (`.github/workflows/runtime.yml`: nightly schedule + manual group selector calling `scripts/acceptance_runtime.sh`.)
- [x] Prioritize runtime checks for production-supported templates:
  - WebApp,
  - PostgreSQL/CloudNativePG,
  - Redis,
  - Kafka/Strimzi,
  - RabbitMQ,
  - MongoDB,
  - Keycloak + PostgreSQL,
  - OpenTelemetry/observability.
  (Runtime case groups exist for each in `scripts/acceptance_runtime.sh` and are selectable from the workflow dispatch.)
- [x] Document exact operator versions, resource requirements, and expected Ready conditions. (`docs/ACCEPTANCE_RUNTIME.md` + pinned versions in `scripts/acceptance_runtime.sh`.)
- [x] Keep dry-run stubs clearly separated from runtime validation. (Dry-run lives in `acceptance_kind.sh`; real apply only in `acceptance_runtime.sh`.)

### Success criteria

- Platform releases include evidence that Tier 1 and selected Tier 2 templates work against real controllers.
- Heavy tests run outside the default local developer loop.

---

## 12.1 Phase E2 — Crossplane V2 Professional Management (P1)

**Goal:** raise Crossplane V2 from simple generated examples to a real platform-control-plane path that operators can manage after deployment.

### Deliverables

- [ ] Reclassify current manifest-wrapping `kcl_to_crossplane` output as a compatibility bridge and document it as non-final for production Crossplane APIs.
- [ ] **Define the template→Crossplane-API selection policy** (which `framework/templates/` modules warrant a hand-authored `crossplane_v2/managed_resources/` API vs. which stay Tier-1 GitOps-only). Application workloads (`WebAppModule`, generic `SingleDatabaseModule`) stay Tier-1 GitOps/YAML; only platform/infrastructure services (databases, messaging, identity, certificates, object storage, secrets) become Crossplane APIs. Document the rule in `docs/CROSSPLANE_PATTERNS.md`.
- [ ] **Publish and maintain a template↔managed-resource parity matrix** so the coverage relationship between `framework/templates/` and `crossplane_v2/managed_resources/` is explicit and reviewable. Current state below; close the gaps deliberately, do not blanket-mirror.

  | Infra template (`framework/templates/`) | Curated Crossplane API (`crossplane_v2/managed_resources/`) | Status |
  |---|---|---|
  | `postgresql` (CNPG) | `postgres/*` (CNPG-native) | ✅ professional (CNPG-native) |
  | `kafka` (Strimzi) | `kafka_strimzi/*` | ✅ Helm/operator-based |
  | `keycloak` | `keycloak/*` | ✅ operator CRD + glue |
  | (no template — cluster infra) | `cert_manager/*` | ✅ Helm Release |
  | `mongodb`, `rabbitmq`, `redis`/`valkey`, `opensearch`, `minio`, `vault`/`openbao`, `questdb`, `elastic`, `opentelemetry` | — | ⬜ gap: decide per selection policy, add only where a control-plane API adds value |
  | `webapp`, generic `database` | — | 🚫 intentionally excluded (Tier-1 GitOps/YAML) |

- [ ] **Converge the two tracks**: make the generated `kcl_to_crossplane` path emit/reference the curated professional APIs (provider-native/operator CRDs) for templates that have one, instead of opaque `Object` wrappers, and fall back to the bridge only for unmodeled resources. Keep `crossplane_v2/providers/` and `crossplane_v2/functions/` as cluster prerequisites independent of any stack.
- [ ] Define an XRD design checklist for every supported Crossplane API: intent-level fields, OpenAPI validation, defaults/enums, descriptions, status fields, printer columns, claim scope, connection-secret contract, and versioning policy.
- [ ] Prefer provider-native managed resources and operator CRDs over `provider-kubernetes` Objects. Allow `Object` only for namespaces, small RBAC/bootstrap glue, or temporary migration bridges with an owner and removal path.
- [ ] Move advanced composition logic into pinned, reviewed packages using `function-kcl`, `function-go-templating`, or custom functions built with `function-sdk-go`; inline functions remain limited to examples/prototypes.
- [ ] Add Crossplane package tests:
  - local `crossplane render` fixtures with function results,
  - golden drift checks for generated XRD/Composition/XR output,
  - cluster reconciliation tests that create an XR/Claim and verify Synced/Ready,
  - update tests that prove changes propagate to composed resources,
  - delete tests that prove cleanup or intentional orphaning,
  - composition revision or `compositionRevisionRef` rollback tests for supported APIs.
- [~] Add Go CLI support, likely `koncept crossplane test`, that wraps render, static policy checks, `crossplane render`, and optional kind/runtime reconciliation checks with consistent output. (Shipped wrapper: static Crossplane contract checks + pinned package checks + optional local `crossplane render` execution with `--require-cli`/`--skip-render`/`--keep-artifacts`, plus opt-in kubectl runtime checks via explicit modes and profile presets (`smoke`, `lifecycle`, `catalog`, `api-lifecycle`, `matrix`); richer reconciliation/update/delete/revision suites remain.)
- [ ] Create or refactor at least one serious reference API, such as PostgreSQL or Keycloak+PostgreSQL, using provider-native/operator-managed resources and function-based composition instead of copied nested manifests.
- [ ] Document the operating runbook for deployed Crossplane APIs: inspect XR/Claim conditions, trace composed resources, read function results, locate connection Secrets, perform safe updates, pin/roll back composition revisions, and clean up resources.

### Success criteria

- A platform engineer can install Crossplane prerequisites, apply one supported API package, create a Claim, update it, observe status/connection outputs, roll back a composition revision, and delete it using documented commands.
- Supported Crossplane APIs have tests that prove ongoing management, not only initial YAML generation.
- New Crossplane APIs cannot be marked supported unless they pass the checklist and tests in `docs/CROSSPLANE_PATTERNS.md`.

**Implementation learning (2026-06-02, Crossplane test wrapper):** the first secure step for Crossplane CLI maturity is a deterministic local contract gate, not immediate runtime orchestration in one command. `koncept crossplane test` now renders with the same factory path as production output and validates required sections, pipeline shape, and pinned provider/function packages before optionally running `crossplane render` (auto-skip when binary is missing unless `--require-cli`). Runtime checks now support both explicit modes and named profile presets (`smoke`, `lifecycle`, `catalog`, `api-lifecycle`, `matrix`) with conflict protection against ambiguous mode+profile combinations, safety defaults (no prerequisites unless requested, cleanup enabled, prerequisite cleanup disabled), and opt-in execution so teams can progressively validate behavior without making heavyweight checks mandatory in every environment. The `matrix` profile standardizes staged validation order (`smoke -> catalog -> api-lifecycle`) and supports inclusive boundaries (`--runtime-matrix-from` / `--runtime-matrix-stop-on`) so PR and nightly pipelines can share one command with different confidence depth. The new `--runtime-plan` mode lets teams preview resolved runtime execution intent without touching a cluster, which reduces CI/operator misconfiguration risk. Remaining work is full API-specific lifecycle/revision validation.

**Implementation learning (2026-06-03, Crossplane vs. templates clarification):** the architecture ambiguity called out in Section 5.7 was traced to conflating the *generated* `kcl_to_crossplane` output with the *hand-authored* `crossplane_v2/` directory. The resolution is policy, not more code: (1) cluster prerequisites (`providers/`, `functions/`) are never generated and stay independent of stacks; (2) `managed_resources/` is a deliberately curated subset of `framework/templates/` — only platform/infrastructure services earn a Crossplane control-plane API, application workloads stay Tier-1 GitOps; (3) the generated bridge and the curated professional APIs must *converge* (generate/reference provider-native resources), not duplicate. The parity matrix above makes the coverage relationship reviewable so contributors stop assuming a 1:1 mirror is the goal.

---

## 12.2 Phase E3 — Delivered Output-Depth Work (Helmfile, Observability, Distribution) (P1)

> This section consolidates three standalone June 2026 planning notes that previously lived at the repository root
> (`EVOLUTION_IMPLEMENTATION_2026_06_03.md`, `EVOLUTION_PHASE_5_2026_06_03.md`, `IMPLEMENTATION_PLAN_2026_06.md`).
> They were merged here and deleted so this roadmap stays the single source of truth (Section 5.5).

**Goal:** deepen the highest-priority existing outputs (Helmfile, Crossplane V2) and harden CLI distribution before adding new breadth.

### Delivered

- [x] **Helmfile integration testing fixtures.** Added a `helmfile-integration` case to `INTEGRATION_CASES` in `scripts/acceptance_kind.sh` with a realistic multi-release scenario (Redis + PostgreSQL + WebApp 3-tier plus independent Kafka). It exercises `needs` generation derived from `dependsOn` chains, multi-repository setup, and per-release `releaseOverrides`. Prepared for real `helm template` validation in CI. See `docs/HELMFILE_ADOPTION.md`.
- [x] **Crossplane runtime/lifecycle fixture.** Added a full-lifecycle Crossplane fixture (XRD → Composition → XR → Prerequisites → Readiness → Cleanup) using a stacked database + app workload, registered for runtime-only execution. Validates dependency ordering via concrete sequencer rule names and governance-metadata propagation through the composition pipeline.
- [x] **Dry-run observability foundation.** Expanded the dry-run YAML structure to support a resource-footprint section and prepared the Go CLI handlers to display cluster-footprint summaries. Heavy resource-total calculation is intentionally deferred to the Go layer (KCL stays declarative), with full computation/display the remaining step.
- [x] **CLI distribution hardening (docs).** Published `docs/CLI_DISTRIBUTION.md` covering Linux/macOS/Windows installation, checksum verification, container-image usage, and CI/CD integration, complementing the shipped `make build-all`/`make checksums`/`make docker` targets and `.github/workflows/release.yml`.

### Key learnings (preserved from the merged notes)

- **KCL is declarative by design.** Heavy calculations (resource footprint totals, node estimates) belong in the imperative Go layer after rendering, not inside KCL lambdas. This is a feature, not a limitation.
- **Dependency identity parity is a coherence signal.** Helmfile effective release names (after `releaseDefaults`/`releaseOverrides`) and Crossplane concrete sequencer resource names both derive from the same framework `dependsOn` graph; when they line up, the multi-format model is internally consistent.
- **Governance metadata flows uniformly.** Stack metadata reaches Helmfile (`labels`/`commonLabels`/per-release labels) and Crossplane (annotations on XRD/Composition/XR/prerequisites/wrapped Objects) from one contract, validating the schema design.
- **Documentation-first drives adoption.** Teams need workflows and storage-class patterns as much as schemas; adoption guides moved the needle more than additional features.

### Remaining

- [ ] Pair the Helmfile fixture with real `helm template` execution in CI.
- [ ] Finish dry-run resource-footprint computation and human-readable display in the Go CLI.
- [ ] Wire the Crossplane lifecycle fixture into `scripts/acceptance_runtime.sh` with full Ready waits (tracked under Phase E2).

---

## 13. Phase F — Developer Portal and Service Catalog Maturity (P1/P2)

**Goal:** make Backstage the preferred self-service interface for non-platform engineers.

### Deliverables

- [~] Connect Backstage templates to the same project/module scaffolding contracts as the CLI. The shared custom action now invokes the current Go CLI lifecycle commands; full portal workflow validation is still pending.
- [x] Generate catalog entities with ownership, lifecycle, system, domain, repository, docs, support metadata, and dependency graph data. SLO tier, data classification, cost center, runbook, and support-contact now have explicit `models.metadata.Metadata` fields (`sloTier`, `dataClassification`, `costCenter`, `runbook`, `support`) that flow into the Backstage catalog as `koncept.io/*` annotations on every entity, with `owner`/`lifecycle` overriding render defaults. The same governance fields now mirror into Kubernetes manifest annotations on the YAML/ArgoCD render path, while explicit `Metadata.labels`/`Metadata.annotations` are merged into rendered manifests with resource-specific values taking precedence.
- [ ] Add workflow templates for:
  - new web app,
  - new database/cache/queue,
  - new environment,
  - new release,
  - promote release to environment.
- [ ] Add preview/diff before publishing generated changes.
- [x] Add documentation for the operating model: who approves platform changes, app changes, and environment changes. (`docs/OPERATING_MODEL.md`.)

### Success criteria

- Most product teams use Backstage or simple CLI commands instead of editing framework internals.
- Service ownership and lifecycle are visible in the catalog.

---

## 14. Phase G — Observability and Product Metrics (P2)

**Goal:** know whether the platform is actually helping.

### Deliverables

- [~] Add opt-in/internal OpenTelemetry metrics to the Go CLI. (Shipped opt-in **local** telemetry — `internal/metrics` + `koncept metrics`, enabled by `--metrics`/`KONCEPT_METRICS`. Data stays on-disk as JSONL; OTLP export to a backend is the remaining step. See `docs/PLATFORM_METRICS.md`.)
- [x] Track:
  - render duration,
  - render failures,
  - validation failures,
  - most common error categories,
  - output format usage,
  - (template usage and project onboarding time still pending dedicated events).
- [ ] Add a small platform dashboard.
- [~] Add a feedback loop: quarterly review of failed validations, support tickets, and most requested templates. (Escalation/feedback process documented in `docs/OPERATING_MODEL.md`; recurring review cadence not yet automated.)

### Success criteria

- Platform priorities are driven by product-team usage and pain, not only framework ideas.

---

## 15. Phase H — Ecosystem Expansion Only After Adoption (P2/P3)

**Goal:** add breadth only where it serves real product needs.

Potential future work:

- Fleet output for multi-cluster GitOps if the company uses Rancher/Fleet.
- ArgoCD ApplicationSet generation if multi-cluster ArgoCD becomes the default.
- Score input if developers need a platform-neutral workload spec.
- Plugin architecture if product teams need extension without framework forks.
- Additional infrastructure templates based on actual product demand.

**Implementation learning (2026-06-01):** the safest strategic path is not to add Fleet or Score immediately. The higher-leverage step is to make priority existing outputs production-coherent first. Helmfile and Crossplane V2 now share the same stack metadata contract as YAML/ArgoCD/Backstage where their formats support it, and both priority outputs now preserve framework dependency ordering in their native orchestration surfaces. This improves governance, reviewability, and rollout safety without adding another output surface.

**Rule:** no new Tier 1 output or template family without:

- a named internal consumer,
- tests,
- docs,
- ownership,
- lifecycle/deprecation plan.

---

## 16. Revised Priority Matrix

| Priority | Work | Why |
|---|---|---|
| **P0** | Go CLI packaging and verification | Removes niche CLI dependency friction. |
| **P0** | Full project/module/environment scaffolding | Directly answers “is it easy to create a new project?” |
| **P0** | CI workflow + policy basics | Required before several products depend on the platform. |
| **P1** | Extend golden outputs where justified | Makes render changes reviewable without turning snapshots into a high-maintenance burden. |
| **P1** | Framework versioning | Allows product teams to upgrade independently. |
| **P1** | Backstage workflow integration | Makes the platform self-service for non-KCL users. |
| **P1** | Crossplane V2 professional management | Converts the current manifest-wrapper bridge into typed, testable, provider-native platform APIs. |
| **P1/P2** | Runtime operator validation | Builds confidence in production infrastructure templates. |
| **P2** | Platform telemetry | Measures adoption and pain points. |
| **P2/P3** | Fleet/Score/plugin expansion | Valuable only after the golden path is adopted. |

---

## 17. Recommended Operating Model

### Roles

| Role | Responsibilities |
|---|---|
| **Application developers** | Use Backstage/CLI, configure approved inputs, review diffs. |
| **Product platform champions** | Own product stacks/modules within `projects/<name>/`, request new templates. |
| **Central platform team** | Own `framework/`, `cmd/koncept/`, templates, policy, CI, release process, docs. |
| **Security/operations reviewers** | Approve policy exceptions, runtime dependencies, production changes. |

### Change categories

| Change | Approval path |
|---|---|
| Site/tenant config change | Product team + normal app review. |
| New service from existing template | Product team, generated diff review. |
| New framework template | Platform team review + tests + docs + acceptance fixture. |
| New output procedure | Platform team architecture review + support-tier decision. |
| Policy exception | Security/operations owner with expiry. |

---

## 18. Final Recommendation

This IDP is a promising and useful platform for a medium company **if it is treated as an internal product with a small set of strongly supported golden paths**.

The current implementation already has significant value:

- tested KCL framework,
- many reusable templates,
- multiple render outputs,
- Backstage artifacts,
- Go CLI foundation,
- acceptance testing structure.

The next improvements should not be more breadth. They should be:

1. make the Go CLI the primary packaged interface,
2. make project creation one guided workflow,
3. add CI/policy/golden review gates,
4. version the framework,
5. make Backstage the self-service layer,
6. measure adoption and errors.

If those items are completed, this IDP can be genuinely useful and maintainable for several products in a medium-sized organization. Without them, it remains a strong technical prototype that may be too complex for broad adoption.
