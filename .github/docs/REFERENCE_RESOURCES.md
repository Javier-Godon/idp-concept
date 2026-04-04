# Reference Resources & Knowledge Base

## Purpose

This document curates high-quality, **official and verified** reference repositories, documentation, and learning resources relevant to the idp-concept project. Every resource listed here has been evaluated against (docs/SECURITY.md) criteria.

All resources are:
- Maintained by reputable organizations or recognized community leaders
- Open source with OSI-approved licenses
- Actively maintained (commits within last 6 months)
- Directly relevant to at least one core technology in this project

---

## Official Documentation

### Primary Technologies

| Technology | Official Docs | Status | Notes |
|---|---|---|---|
| **KCL** | [kcl-lang.io/docs](https://www.kcl-lang.io/docs/) | CNCF Sandbox | v0.10.0 (project), v0.11.2 (latest upstream). Constraint-based config language |
| **Nushell** | [nushell.sh/book](https://www.nushell.sh/book/) | Active OSS | Structured data shell used for platform CLI |
| **Crossplane** | [docs.crossplane.io](https://docs.crossplane.io/) | CNCF Graduated | Kubernetes-native infrastructure provisioning |
| **ArgoCD** | [argo-cd.readthedocs.io](https://argo-cd.readthedocs.io/) | CNCF Graduated | GitOps continuous delivery |
| **Helm** | [helm.sh/docs](https://helm.sh/docs/) | CNCF Graduated | Kubernetes package manager |
| **Helmfile** | [helmfile.readthedocs.io](https://helmfile.readthedocs.io/) | Active OSS | Declarative Helm chart management |
| **Kusion** | [kusionstack.io](https://www.kusionstack.io/) | Active OSS | Platform engineering engine |

### Infrastructure Components

| Component | Docs | Version in Project |
|---|---|---|
| **Kubernetes** | [kubernetes.io/docs](https://kubernetes.io/docs/) | 1.31.2 (k8s schema) |
| **Strimzi** (Kafka) | [strimzi.io/docs](https://strimzi.io/docs/) | 0.45.0 |
| **cert-manager** | [cert-manager.io/docs](https://cert-manager.io/docs/) | 1.17.2 |
| **Keycloak** | [keycloak.org/documentation](https://www.keycloak.org/documentation) | 26.4.0 |
| **go-task** | [taskfile.dev](https://taskfile.dev/) | v3 |

---

## Reference Repositories

### 1. kcl-lang/kcl — The KCL Language Core

- **URL**: [github.com/kcl-lang/kcl](https://github.com/kcl-lang/kcl)
- **Stars**: 2,300+ | **License**: Apache 2.0
- **Maintained by**: KCL Team (CNCF Sandbox project)
- **Language**: Rust (compiler), Go (toolchain)

**What to learn from this repo:**
- KCL language specification and edge cases
- Has a `CLAUDE.md` file — reference for how to instruct AI about KCL
- Testing patterns for KCL schemas
- Integration with Kubernetes ecosystem
- CRD-to-KCL import tooling (`kcl import`)

**Key paths:**
- `/CLAUDE.md` — AI instructions for KCL development (reference for our copilot-instructions)
- `/docs/` — Language reference docs
- `/kclvm/` — Compiler implementation (understand error messages)

---

### 2. kcl-lang/modules — Official KCL Module Registry

- **URL**: [github.com/kcl-lang/modules](https://github.com/kcl-lang/modules)
- **Stars**: 39+ | **License**: Apache 2.0
- **Maintained by**: KCL Team (CNCF)

**What to learn from this repo:**
- 200+ official KCL modules as examples of schema design patterns
- Directly relevant modules we can import or reference:
  - `crossplane/` — Base Crossplane schemas
  - `crossplane-provider-kubernetes/` — Kubernetes provider schemas
  - `crossplane-provider-helm/` — Helm provider schemas
  - `argo-cd/` — ArgoCD CRD schemas
  - `cert-manager/` — cert-manager CRD schemas
  - `strimzi-kafka-operator/` — Strimzi Kafka schemas
  - `crossplane_provider_keycloak/` — Keycloak provider schemas (regenerated recently)
- Module structure conventions (`kcl.mod`, `main.k`, models organization)
- How to publish and version KCL modules

**Key insight:** Many of these modules are auto-generated from CRDs using `kcl import`, the same approach used in this project for ArgoCD models.

---

### 3. vfarcic/dot-ai — DevOps AI Toolkit

- **URL**: [github.com/vfarcic/dot-ai](https://github.com/vfarcic/dot-ai)
- **Stars**: 308+ | **License**: MIT
- **Author**: Viktor Farcic (Developer Advocate at Upbound/Crossplane)

**What to learn from this repo:**
- MCP-based AI toolkit for DevOps operations
- TypeScript server implementation with Nushell scripting
- How to structure AI-assisted DevOps workflows
- Claude is listed as a **contributor** — AI-assisted development patterns
- Kubernetes operations (get/create/update/delete resources, logs, events)
- Shell command execution patterns for AI tools
- GitHub integration via MCP (issues, PRs, file management)

**Key patterns to adopt:**
- MCP tool definitions for infrastructure operations
- Nushell + AI integration patterns
- Security-conscious tool design (limited scope operations)

**Relevance to idp-concept:** Shows how to build AI-powered platform engineering tools. The MCP server approach could be a future extension for `koncept` CLI — making KCL rendering and stack management available as MCP tools.

---

### 4. vfarcic/cncf-demo — CNCF Technology Showcase

- **URL**: [github.com/vfarcic/cncf-demo](https://github.com/vfarcic/cncf-demo)
- **Stars**: 231+ | **License**: MIT
- **Author**: Viktor Farcic

**What to learn from this repo:**
- End-to-end CNCF project integration patterns
- Chapters covering: **Crossplane** (IDP setup), **ArgoCD** (GitOps), **Helm** (packaging), **Backstage** (developer portal)
- Has an **"IDP" chapter** — directly relevant to idp-concept
- Uses Nushell (2.5% of codebase) alongside Bash and Go
- Multi-cloud infrastructure patterns (AWS, Azure, GCP, Civo, DigitalOcean)
- Practical examples of Crossplane Compositions in real use

**Key paths:**
- `/manuscript/idp/` — Internal Developer Platform chapter
- `/manuscript/crossplane/` — Crossplane usage patterns
- `/manuscript/argocd/` — ArgoCD GitOps patterns
- `/manuscript/gitops/` — GitOps methodology
- `/manuscript/helm/` — Helm chart patterns

**Relevance to idp-concept:** Validates our architecture decisions. Shows how Crossplane + ArgoCD + Helm fit together in production IDP scenarios from someone at Upbound.

---

### 5. kcl-lang/crossplane-kcl — Crossplane KCL Function

- **URL**: [github.com/kcl-lang/crossplane-kcl](https://github.com/kcl-lang/crossplane-kcl)
- **Stars**: 30+ | **License**: Apache 2.0
- **Maintained by**: KCL Team / Crossplane community

**What to learn from this repo:**
- How to use KCL as a Crossplane Composition Function
- Bridge between our KCL schemas and Crossplane pipelines
- Already referenced in our `crossplane_v2/functions/function_kcl.yaml`
- Examples of KCL inline code within Composition pipelines

**Relevance to idp-concept:** This is the exact integration point between our KCL-first approach and Crossplane compositions. Critical reference for the `crossplane_v2/` directory.

---

### 6. vfarcic/crossplane-kubernetes — KCL+Crossplane+Nushell Reference

- **URL**: [github.com/vfarcic/crossplane-kubernetes](https://github.com/vfarcic/crossplane-kubernetes)
- **Stars**: 50+ | **License**: Not specified
- **Maintained by**: Viktor Farcic (Upbound) + Claude (AI-assisted development)
- **Language**: KCL 66%, Nushell 30.6%, Just 3%

**What to learn from this repo:**
- **Closest external match to idp-concept's technology stack** (KCL + Crossplane + Nushell)
- Production-grade Crossplane compositions written in KCL
- `CLAUDE.md` — mature AI instruction patterns for KCL+Crossplane development
- `.mcp.json` — MCP configuration patterns for AI-assisted workflow
- TDD workflow with Kyverno Chainsaw tests
- PRD-driven AI development with product requirement documents in `prds/`
- KCL-to-YAML pipeline: `kcl/` source → `just package-generate` → `package/` output
- Multi-cloud provider compositions (AWS, Azure, GCP, UpCloud)
- Crossplane v2 migration patterns

**Key paths:**
- `/CLAUDE.md` — AI instructions for KCL+Crossplane development
- `/kcl/` — KCL source files (data.k, definition.k, compositions.k, provider-specific files)
- `/tests/` — Chainsaw test suites per cloud provider
- `/prds/` — Product Requirement Documents (AI-driven feature development)

**Relevance to idp-concept:** The most relevant external project. Demonstrates the same KCL→Crossplane pipeline with Nushell tooling. Shows how to structure AI-assisted development with PRDs and CLAUDE.md. The `kcl/data.k` schema definitions parallel our `framework/models/` approach.

---

### 7. vfarcic/crossplane-app — App-Level Crossplane+KCL

- **URL**: [github.com/vfarcic/crossplane-app](https://github.com/vfarcic/crossplane-app)
- **Stars**: 11+ | **License**: Not specified
- **Maintained by**: Viktor Farcic (Upbound)
- **Language**: Nushell 78.7%, KCL 20.4%

**What to learn from this repo:**
- Application-level Crossplane compositions (vs infrastructure-level in crossplane-kubernetes)
- Prometheus scaling, KEDA integration patterns
- Heavy Nushell scripting patterns for infrastructure automation
- CLAUDE.md and MCP config for AI-assisted development

**Relevance to idp-concept:** Complements crossplane-kubernetes with app-layer patterns. The heavy Nushell usage is directly relevant to our `platform_cli/` scripts.

---

### 8. crossplane-contrib/function-kcl — Crossplane KCL Function (Canonical)

- **URL**: [github.com/crossplane-contrib/function-kcl](https://github.com/crossplane-contrib/function-kcl)
- **Stars**: 150+ | **License**: Apache 2.0
- **Maintained by**: Crossplane community (canonical, supersedes kcl-lang/crossplane-kcl)

**What to learn from this repo:**
- **Definitive** KCL-in-Crossplane API: `option("params").oxr / .ocds / .dxr / .dcds / .ctx`
- Source modes: inline KCL, OCI artifacts, Git references, filesystem
- Conditions, events, connection details, extra resources in KCL compositions
- This is the canonical implementation referenced in our `crossplane_v2/functions/function_kcl.yaml`

**Relevance to idp-concept:** The authoritative source for how KCL functions work inside Crossplane pipelines. Must-reference when creating or modifying compositions in `crossplane_v2/`.

---

### 9. kcl-lang/krm-kcl — KRM KCL Specification

- **URL**: [github.com/kcl-lang/krm-kcl](https://github.com/kcl-lang/krm-kcl)
- **Stars**: 34+ | **License**: Apache 2.0
- **Maintained by**: KCL Team (CNCF)

**What to learn from this repo:**
- KRM (Kubernetes Resource Model) KCL specification
- Integration points: Kubectl, Kustomize, Helm, Helmfile, Crossplane, KPT
- KCLInput / KCLRun CRD definitions
- Source support: inline, OCI, Git, filesystem

**Relevance to idp-concept:** Defines the bridge spec connecting KCL to all K8s tooling. Essential reference for understanding how our KCL schemas integrate with Helm, Helmfile, and Crossplane pipelines.

---

### 10. kcl-lang/konfig — KCL K8s Configuration Framework

- **URL**: [github.com/kcl-lang/konfig](https://github.com/kcl-lang/konfig)
- **Stars**: 14+ | **License**: Apache 2.0
- **Maintained by**: KCL Team (CNCF)

**What to learn from this repo:**
- KCL-native Kubernetes configuration abstraction layer
- Server model, frontend/backend rendering pattern
- Metadata, mixins, templates approach
- Similar architecture to our `framework/` directory

**Relevance to idp-concept:** Reference architecture for KCL-based K8s abstraction layers. Our `framework/models/` and `framework/templates/` follow a similar pattern. Useful for validating our schema design decisions.

---

### 11. kcl-lang/examples — Official KCL Examples

- **URL**: [github.com/kcl-lang/examples](https://github.com/kcl-lang/examples)
- **Stars**: 34+ | **License**: Apache 2.0
- **Maintained by**: KCL Team (CNCF)

**What to learn from this repo:**
- Comprehensive examples covering all KCL use cases: configuration, mutation, validation, abstraction, data integration, automation
- Kubernetes-specific examples, GitOps patterns, CI/CD integration
- Best practices for KCL project structure

**Relevance to idp-concept:** The official examples repository. Consult when unsure about KCL patterns or when creating new module types.

---

### 12. KusionStack/kusion — Platform Orchestrator

- **URL**: [github.com/KusionStack/kusion](https://github.com/KusionStack/kusion)
- **Stars**: 1,287+ | **License**: Apache 2.0
- **Maintained by**: KusionStack (CNCF listed)

**What to learn from this repo:**
- Intent-driven Platform Orchestrator with deep KCL integration
- Developer Portal, AppConfiguration patterns
- Day 0/Day 1 workflow examples
- Server mode with RESTful APIs
- Kusion spec YAML format (directly used by our `kcl_to_kusion` procedure)

**Relevance to idp-concept:** Authoritative reference for Kusion spec generation. Our `framework/procedures/kcl_to_kusion.k` generates Kusion-compatible output. Understanding Kusion's architecture validates our IDP design decisions.

---

## Multi-Cluster & GitOps at Scale (Reference Architectures)

### 13. k0rdent/kcm — Enterprise Multi-Cluster K8s Management

- **URL**: [github.com/k0rdent/kcm](https://github.com/k0rdent/kcm)
- **Stars**: 180+ | **License**: Apache 2.0
- **Maintained by**: Mirantis (k0rdent project)
- **Language**: Go 93.7%

**What to learn from this repo:**
- Enterprise multi-cluster Kubernetes management with template-based lifecycle
- **ClusterTemplate/ServiceTemplate/TemplateChain** patterns — typed templates with priority-based ordering and versioning chains
- `HelmSpec` + `HelmValues` reusable types for Helm-native resource lifecycle
- `TemplateValidationStatus` with constraint checking (providers, contract version)
- Template chain upgrade paths (e.g., v1→v2→v3 with supported upgrade matrix)
- Management vs child cluster separation patterns

**Applicable patterns for idp-concept:**
- Template versioning chains could enhance our Release/Stack versioning
- Priority-based template ordering parallels our `dependsOn` mechanism
- The `TemplateChain` concept (supported upgrades between template versions) could be adapted for stack version migration
- `HelmSpec` reusable struct pattern validates our approach of extracting common schemas

**Key paths:**
- `/api/v1alpha1/templates_common.go` — Shared template types (HelmSpec, TemplateStatusCommon)
- `/api/v1alpha1/clustertemplate_types.go` — ClusterTemplate CRD definition
- `/api/v1alpha1/servicetemplate_types.go` — ServiceTemplate CRD definition
- `/api/v1alpha1/templatechain_types.go` — Template versioning chain patterns

**Docs**: [docs.k0rdent.io](https://docs.k0rdent.io/)

---

### 14. rancher/fleet — GitOps at Scale

- **URL**: [github.com/rancher/fleet](https://github.com/rancher/fleet)
- **Stars**: 1,700+ | **License**: Apache 2.0
- **Maintained by**: SUSE/Rancher
- **Language**: Go 92.7%

**What to learn from this repo:**
- GitOps deployment at scale: GitRepo → Bundle → BundleDeployment three-stage pipeline
- **Everything converts to Helm** internally — raw YAML, Kustomize, and Helm charts all normalized to Helm releases
- Multi-cluster targeting with label-based selectors (similar to our Site concept)
- Bundle grouping by path within a Git repository (parallels our factory/ structure)
- Dependency ordering between bundles via `dependsOn`
- Diff-based change detection for efficient reconciliation

**Applicable patterns for idp-concept:**
- The "normalize everything to Helm" strategy validates our multi-format output approach
- Bundle path-based grouping could inform how we organize factory/ output directories
- Fleet's cluster targeting by labels parallels our Site→Tenant→Stack selection
- `dependsOn` in Fleet Bundles is conceptually identical to our module/manifest `dependsOn`
- Potential future 10th output format: `kcl_to_fleet` generating Fleet GitRepo + Bundle specs

**Key concepts:**
- `GitRepo` — Points to a Git repository with paths to deploy
- `Bundle` — Collection of resources from a single path, normalized to Helm
- `BundleDeployment` — Per-cluster deployment of a Bundle
- `ClusterGroup` — Label-based cluster targeting (parallels our Site model)

**Docs**: [fleet.rancher.io](https://fleet.rancher.io/)

---

## Alternative Tools & Emerging Technologies

These tools represent alternative or complementary approaches worth monitoring. They are NOT currently used in idp-concept but may influence future design or serve as additional output formats.

### Timoni — CUE-Powered K8s Package Manager

- **URL**: [github.com/stefanprodan/timoni](https://github.com/stefanprodan/timoni) | [timoni.sh](https://timoni.sh/)
- **Stars**: 1,900+ | **License**: Apache 2.0
- **By**: Stefan Prodan (Flux maintainer) | **Language**: Go 92%, CUE 6%
- **Status**: Active development (v0.26.0, APIs still evolving)

**Why it matters:** Timoni is the strongest Helm alternative. Uses CUE instead of Go templates, providing type safety. Its Module/Instance/Bundle concepts parallel idp-concept's schema/instance pattern. Could be a future output format alongside Helm/Helmfile.

### Score — Platform-Agnostic Workload Spec

- **URL**: [github.com/score-spec/spec](https://github.com/score-spec/spec) | [score.dev](https://score.dev/)
- **Stars**: 8,000+ | **License**: Apache 2.0
- **Status**: CNCF Sandbox, active development (v0.3.0)

**Why it matters:** Score describes "what I need" (developer intent) while idp-concept describes "how to build it" (platform implementation). Score could be a future input format — developers write Score specs, the IDP generates manifests.

### Kratix — Platform Framework with Promises

- **URL**: [github.com/syntasso/kratix](https://github.com/syntasso/kratix) | [docs.kratix.io](https://docs.kratix.io/)
- **Stars**: 741+ | **License**: Apache 2.0
- **Status**: Active development

**Why it matters:** Kratix's "Promise" concept (platform APIs backed by pipelines) parallels our Stack/Module pattern. Direct competitor/inspiration for IDP framework design.

### cdk8s — Imperative K8s Configs

- **URL**: [github.com/cdk8s-team/cdk8s](https://github.com/cdk8s-team/cdk8s) | [cdk8s.io](https://cdk8s.io/)
- **Stars**: 4,800+ | **License**: Apache 2.0
- **Status**: CNCF Sandbox, active

**Why it matters:** Imperative TypeScript/Python/Go approach to K8s manifests. Contrasts with KCL's declarative model. Shows how AWS CDK patterns apply to K8s.

### Carvel ytt — YAML Templating with Starlark

- **URL**: [github.com/carvel-dev/ytt](https://github.com/carvel-dev/ytt)
- **Stars**: 1,800+ | **License**: Apache 2.0

**Why it matters:** Structural-aware YAML templating. Overlay concept parallels KCL's union operator (`|`).

---

## CNCF Platform Engineering References

### CNCF TAG App Delivery — Platform Engineering Working Group

- **URL**: [github.com/cncf/tag-app-delivery](https://github.com/cncf/tag-app-delivery)
- **Stars**: 833+ | **License**: Apache 2.0
- **Status**: Archived (Sep 2025) — content is definitive, not changing

**Critical documents:**
- **Platforms Whitepaper** — Foundational CNCF whitepaper on what platforms are, why they matter, their capabilities
- **Platform Engineering Maturity Model v1** — Framework for assessing IDP maturity (use to position idp-concept)
- **Published at**: [tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model)

**Relevance to idp-concept:** The canonical CNCF reference for platform engineering. Use to validate architecture decisions against industry standards and position idp-concept within the maturity model.

---

## About Viktor Farcic

[Viktor Farcic](https://github.com/vfarcic) is a **Developer Advocate at Upbound** (the company behind Crossplane). He is one of the most prolific educators in the platform engineering, Crossplane, and Kubernetes space.

- **YouTube**: [DevOps Toolkit](https://www.youtube.com/@DevOpsToolkit) — Hundreds of videos on Crossplane, ArgoCD, IDP, KCL
- **Location**: Barcelona
- **Contributions**: 3,300+/year, 504 repositories
- **Key expertise**: Crossplane, Platform Engineering, GitOps, AI-assisted DevOps, CNCF ecosystem
- **Recent work**: MCP OAuth authentication, Dex OIDC, Crossplane cost management, dot-agent-deck (AI agent toolkit)

His work is considered authoritative because:
1. He works at Upbound (makers of Crossplane)
2. His repos demonstrate real-world production patterns
3. He actively explores AI + DevOps integration (directly relevant to our AI tooling)
4. The cncf-demo repo is endorsed by CNCF as a learning resource

---

## How to Use These Resources

### For AI Assistants (Copilot, Claude)

When working on this project, AI assistants should:

1. **Fetch KCL docs** when unsure about syntax: `https://www.kcl-lang.io/docs/reference/lang/`
2. **Reference kcl-lang/modules** for schema design patterns when creating new module definitions
3. **Check vfarcic/crossplane-kubernetes** for KCL+Crossplane composition patterns (closest match to this project)
4. **Fetch Nushell docs** when modifying `platform_cli/koncept`: `https://www.nushell.sh/book/`
5. **Reference crossplane-contrib/function-kcl** for KCL-in-Crossplane API details
6. **Check kcl-lang/konfig** for K8s abstraction layer patterns
7. **ONLY fetch from the trusted domain allowlist** in [SECURITY.md](SECURITY.md) — no exceptions
8. **NEVER fetch localhost, 127.0.0.1, 0.0.0.0, private IPs, or cloud metadata** — the fetch server runs in a Docker container with network isolation, but the allowlist is still enforced
9. **NEVER fetch raw IP addresses** — always use domain names from the trusted list

### Priority Order for External Reference

When the AI needs patterns or examples beyond the local codebase:

| Priority | Source | When to Use |
|---|---|---|
| 1st | **Local project** (`framework/`, `projects/erp_back/`, `projects/video_streaming/`) | Always check first — this is the source of truth for project conventions |
| 2nd | **vfarcic/crossplane-kubernetes** | KCL+Crossplane patterns, closest external match |
| 3rd | **kcl-lang/modules** + **kcl-lang/examples** | KCL schema patterns, module structure, language idioms |
| 4th | **crossplane-contrib/function-kcl** | KCL-in-Crossplane API details |
| 5th | **Official docs** (kcl-lang.io, nushell.sh, docs.crossplane.io) | Syntax reference, API docs |
| 6th | **KusionStack/kusion** | Kusion spec format, IDP orchestration patterns |
| 7th | **CNCF TAG App Delivery** | Platform engineering maturity, architectural validation |

### For Human Developers

1. **Start with kcl-lang docs** for KCL syntax questions
2. **Study vfarcic/cncf-demo** chapters for architecture inspiration
3. **Browse kcl-lang/modules** when you need to model a new CRD
4. **Watch DevOps Toolkit YouTube** for Crossplane deep dives
5. **Check dot-ai repo** for AI integration inspiration

### Prompt Engineering References

When creating new `.github/prompts/` files, reference:
- `kcl-lang/kcl/CLAUDE.md` — How the KCL team instructs AI about their language
- `vfarcic/dot-ai` MCP tool definitions — How to describe DevOps operations to AI
- Our own `.github/copilot-instructions.md` — Project-specific conventions

---

## Kubernetes Operators for Production Infrastructure

Production-ready IDP deployments require managed stateful services. These operators provide Kubernetes-native lifecycle management (provisioning, backup, scaling, failover) via CRDs.

### Recommended Operators

#### CloudNativePG — PostgreSQL

- **URL**: [github.com/cloudnative-pg/cloudnative-pg](https://github.com/cloudnative-pg/cloudnative-pg)
- **Stars**: 8,300+ | **License**: Apache 2.0 | **Status**: CNCF Sandbox, very active
- **Key features**: Kubernetes-native (no external tools like Patroni), immutable containers, rolling updates with controlled switchover, failover quorum, plugin interface (CNPG-I), kubectl plugin, OpenSSF Best Practices certified
- **Why recommended**: Newest design, direct K8s API integration, CNCF-backed, EDB-supported, 205+ contributors
- **IDP integration**: CRD → `kcl import` → KCL schema; Crossplane can manage via function-kcl; Helm chart available; KCL module exists on ArtifactHub

#### Zalando Postgres Operator — PostgreSQL (Alternative)

- **URL**: [github.com/zalando/postgres-operator](https://github.com/zalando/postgres-operator)
- **Stars**: 5,100+ | **License**: MIT | **Status**: Active, production-proven 5+ years at Zalando
- **Key features**: PGBouncer connection pooling, live volume resize (EBS, PVC), WAL archiving to S3/GCS, major version upgrades, standby clusters
- **IDP integration**: Helm + kustomize support; well-documented CRDs for KCL import

#### Crunchy PostgreSQL Operator (PGO) — PostgreSQL (Enterprise)

- **URL**: [github.com/CrunchyData/postgres-operator](https://github.com/CrunchyData/postgres-operator)
- **Stars**: 4,400+ | **License**: Apache 2.0 | **Status**: Active
- **Key features**: pgBackRest backup/restore, pgBouncer pooling, scheduled backups, S3/GCS/Azure storage, TLS enforcement, Prometheus monitoring, multi-cluster standby
- **When to use**: Enterprise environments requiring commercial support

#### OT-Container-Kit Redis Operator — Redis

- **URL**: [github.com/ot-container-kit/redis-operator](https://github.com/ot-container-kit/redis-operator)
- **Stars**: 1,300+ | **License**: Apache 2.0 | **Status**: Active (releases every 2-3 weeks)
- **Key features**: Standalone/cluster/replication/sentinel modes, TLS, redis-exporter monitoring, Prometheus ServiceMonitor, Grafana dashboards, IPv4/IPv6
- **IDP integration**: Helm charts via Quay; CRD → KCL schema; standard Accessory module pattern

#### Strimzi — Kafka (Already in Project)

- **URL**: [github.com/strimzi/strimzi-kafka-operator](https://github.com/strimzi/strimzi-kafka-operator)
- **Stars**: 4,900+ | **License**: Apache 2.0 | **Status**: CNCF Incubating
- **Already used**: Referenced in `crossplane_v2/managed_resources/kafka_strimzi/` and `projects/video_streaming/`
- **KCL module**: Available on ArtifactHub as `strimzi-kafka-operator`

### Deprecated/Archived — Do NOT Use

| Operator | Status | Alternative |
|---|---|---|
| `mongodb/mongodb-kubernetes-operator` | **Deprecated** (Dec 2025) | Use `mongodb/mongodb-kubernetes` (new repo) or Bitnami MongoDB Helm chart |
| `minio/operator` | **Archived** (Mar 2026) | Use MinIO Helm chart directly or Bitnami MinIO |
| `spotahome/redis-operator` | **Archived** (3 years inactive) | Use OT-Container-Kit Redis Operator |

### Operator Integration Pattern

For any K8s operator, the IDP integration is:
1. **Install**: Operator deployed via Helm chart (ThirdParty module) or Crossplane
2. **CRD Import**: `kcl import --mode crd -f operator-crds.yaml` → generates KCL schemas
3. **Module**: Wrap CRDs in Accessory schemas with check blocks and sensible defaults
4. **Stack**: Compose operator instances alongside application Components
5. **Deploy**: ArgoCD/Helmfile deploys operator + managed resources together

---

## Third-Party Helm Charts for Reuse

### Bitnami Charts — Production-Grade Baseline

- **URL**: [github.com/bitnami/charts](https://github.com/bitnami/charts)
- **Stars**: 10,300+ | **License**: Apache 2.0 | **Status**: Very active (daily commits, 2,555 contributors)
- **Maintained by**: Broadcom (formerly VMware)
- **Key offerings**: 100+ production-grade charts for databases, caching, messaging, monitoring, CI/CD, networking
- **Security**: Bitnami Secure Images (BSI) — hardened Photon Linux, vulnerability scanning, VEX/KEV/EPSS scores, FIPS/STIG compliance, SBOM generation
- **Multi-arch**: ARM64 and x86_64 support; Kubernetes 1.23+

**Directly usable charts for idp-concept**:

| Chart | Use Case | IDP Module Type |
|---|---|---|
| `bitnami/postgresql` | PostgreSQL without operator | ThirdParty (Helm) |
| `bitnami/redis` | Redis without operator | ThirdParty (Helm) |
| `bitnami/mongodb` | MongoDB (replaces deprecated operator) | ThirdParty (Helm) |
| `bitnami/minio` | MinIO object storage | ThirdParty (Helm) |
| `bitnami/keycloak` | Keycloak IAM | ThirdParty (Helm) |
| `bitnami/kafka` | Kafka without Strimzi | ThirdParty (Helm) |
| `bitnami/nginx-ingress-controller` | Ingress | ThirdParty (Helm) |
| `bitnami/cert-manager` | TLS | ThirdParty (Helm) |
| `bitnami/prometheus` | Monitoring | ThirdParty (Helm) |
| `bitnami/grafana` | Dashboards | ThirdParty (Helm) |

**Integration via Helmfile** (target for Phase 2):
```yaml
releases:
  - name: mongodb
    chart: oci://registry-1.docker.io/bitnamicharts/mongodb
    version: "16.4.3"  # pin specific version
    namespace: infra
    values:
      - ./charts/mongodb/values.yaml
```

### ArtifactHub — KCL Module Registry

- **URL**: [artifacthub.io (KCL org)](https://artifacthub.io/packages/search?org=kcl&sort=relevance)
- **346+ KCL modules** indexed
- **Key categories**: Kubernetes APIs, CNCF project CRDs, Crossplane providers, policy validation, utilities
- **Notable modules**: `k8s` (all K8s 1.31.2 APIs), `konfig` (high-level abstractions), CloudNativePG, cert-manager, Strimzi, ArgoCD, FluxCD, all Crossplane providers

---

## KCL Plugin Ecosystem

KCL integrates with the K8s tool ecosystem via plugins that enable mutation and validation of existing manifests:

| Plugin | Description | Repository |
|---|---|---|
| **kubectl-kcl** | Mutate/validate K8s manifests with KCL | [kcl-lang/kubectl-kcl](https://github.com/kcl-lang/kubectl-kcl) |
| **helm-kcl** | Post-render Helm charts with KCL | [kcl-lang/helm-kcl](https://github.com/kcl-lang/helm-kcl) |
| **kustomize-kcl** | Use KCL as Kustomize transformer | [kcl-lang/kustomize-kcl](https://github.com/kcl-lang/kustomize-kcl) |
| **crossplane function-kcl** | KCL as Crossplane composition function | [crossplane-contrib/function-kcl](https://github.com/crossplane-contrib/function-kcl) |
| **kcl-openapi** | OpenAPI → KCL schema generation | [kcl-lang/kcl-openapi](https://github.com/kcl-lang/kcl-openapi) |

### KCL + Third-Party Tools Integration Pattern

KCL can both **generate from scratch** and **mutate existing** manifests:

```
Generate (idp-concept today):     KCL → builders → manifests → output format
Mutate (future integration):      Helm chart → helm-kcl plugin → KCL policy → validated output
Validate (future integration):    kubectl apply → kubectl-kcl → KCL schema check → admission
```

---

## Alternative Package Distribution Formats

Beyond Helm, the IDP should support consuming and producing these formats:

### Kustomize

- **URL**: [kubernetes-sigs/kustomize](https://github.com/kubernetes-sigs/kustomize) | **Stars**: 11,000+ | **License**: Apache 2.0
- **Pattern**: Base + overlays for environment-specific overrides
- **IDP integration**: KCL generates `kustomization.yaml` + `base/` + `overlays/` structure; `kustomize-kcl` plugin enables KCL transforms; many operators provide kustomize installers
- **When to use**: Teams already using kustomize; lightweight overlays without Helm chart overhead

### Jsonnet

- **URL**: [google/jsonnet](https://github.com/google/jsonnet) | **Stars**: 7,100+ | **License**: Apache 2.0
- **Pattern**: Data templating language for JSON/YAML
- **IDP integration**: ThirdParty module `packageManager = "JSONNET"` is already defined in framework; Jsonnet bundles (e.g., kube-prometheus) can be wrapped as IDP modules
- **When to use**: Adopting existing Jsonnet bundles (Prometheus, Grafana mixins); interop with Tanka

### cdk8s

- **URL**: [cdk8s-team/cdk8s](https://github.com/cdk8s-team/cdk8s) | **Stars**: 4,800+ | **License**: Apache 2.0 | **Status**: CNCF Sandbox
- **Pattern**: Imperative TypeScript/Python/Go K8s manifests using constructs
- **IDP integration**: Could generate cdk8s constructs as output format (Phase 5+); not currently planned
- **When to use**: Teams with strong TypeScript/Python skills wanting imperative control

### OCI Artifacts

- **URL**: Part of [OCI Distribution Spec](https://github.com/opencontainers/distribution-spec) | **Status**: Industry standard
- **Pattern**: Package any artifact (KCL modules, Helm charts, Crossplane configs) as OCI images
- **IDP integration**: KCL modules already published to `ghcr.io/kcl-lang/*`; Helm charts support `oci://` references; Crossplane packages are OCI images
- **When to use**: Always — OCI is the universal distribution mechanism for cloud-native artifacts

---

## Knowledge Refresh Schedule

| Resource | Check Frequency | What to Update |
|---|---|---|
| kcl-lang/kcl releases | Monthly | Version in copilot-instructions if breaking changes |
| kcl-lang/modules | Monthly | New modules relevant to our stack |
| vfarcic repos | Quarterly | New patterns, tools, or AI integration approaches |
| Crossplane docs | On version bump | API changes, new function types |
| Strimzi/cert-manager/Keycloak docs | On version bump | CRD schema changes |
| K8s operators (CNPG, Redis, etc.) | Quarterly | New releases, deprecations, breaking CRD changes |
| Bitnami charts | Monthly | Security patches, new chart versions |
| ArtifactHub KCL modules | Monthly | New modules for operators/CRDs we use |
| CNCF TAG App Delivery | Quarterly | Maturity model updates, new whitepapers |

---

*Last reviewed: 2026-03-31*
*Next scheduled review: 2026-06-30*
