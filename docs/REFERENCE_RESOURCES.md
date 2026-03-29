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
3. **Check vfarcic/cncf-demo** for Crossplane composition patterns
4. **Fetch Nushell docs** when modifying `platform_cli/koncept`: `https://www.nushell.sh/book/`
5. **ONLY fetch from the trusted domain allowlist** in [SECURITY.md](SECURITY.md) — no exceptions
6. **NEVER fetch localhost, 127.0.0.1, 0.0.0.0, private IPs (10.x, 172.16-31.x, 192.168.x), or cloud metadata (169.254.169.254)** — the fetch server has unrestricted network access and this is a critical SSRF risk
7. **NEVER fetch raw IP addresses** — always use domain names from the trusted list

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

## Knowledge Refresh Schedule

| Resource | Check Frequency | What to Update |
|---|---|---|
| kcl-lang/kcl releases | Monthly | Version in copilot-instructions if breaking changes |
| kcl-lang/modules | Monthly | New modules relevant to our stack |
| vfarcic repos | Quarterly | New patterns, tools, or AI integration approaches |
| Crossplane docs | On version bump | API changes, new function types |
| Strimzi/cert-manager/Keycloak docs | On version bump | CRD schema changes |

---

*Last reviewed: 2026-03-28*
*Next scheduled review: 2026-06-28*
