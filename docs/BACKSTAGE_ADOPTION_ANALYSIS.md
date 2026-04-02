# Backstage Adoption Analysis for idp-concept

> Comprehensive study of developer portal options, compatibility assessment, gap analysis, and adoption roadmap.

## Table of Contents

- [1. Executive Summary](#1-executive-summary)
- [2. Current IDP State](#2-current-idp-state)
- [3. Developer Portal Landscape](#3-developer-portal-landscape)
- [4. Backstage Deep Dive](#4-backstage-deep-dive)
- [5. Compatibility Assessment](#5-compatibility-assessment)
- [6. Concept Mapping: idp-concept → Backstage](#6-concept-mapping-idp-concept--backstage)
- [7. Plugin Ecosystem for Our Stack](#7-plugin-ecosystem-for-our-stack)
- [8. Nushell CLI Coexistence Strategy](#8-nushell-cli-coexistence-strategy)
- [9. Gap Analysis](#9-gap-analysis)
- [10. CNCF Maturity Model Alignment](#10-cncf-maturity-model-alignment)
- [11. Adoption Roadmap](#11-adoption-roadmap)
- [12. Risks and Mitigations](#12-risks-and-mitigations)
- [13. Decision Record](#13-decision-record)

---

## 1. Executive Summary

**Recommendation**: Adopt **Backstage** (CNCF Incubation) as the developer portal for idp-concept.

**Key Findings**:
- Backstage is the **only viable free OSS developer portal** with sufficient maturity and ecosystem
- **Full compatibility** with all our technologies: KCL (via custom actions), Crossplane (TeraSky plugin), ArgoCD (Roadie plugin), Helm, Kubernetes, Kafka, Keycloak, Vault
- The **TeraSky Kubernetes Ingestor** plugin is a perfect bridge — it auto-ingests K8s workloads and Crossplane claims as Backstage catalog entities, and auto-generates Templates from Crossplane XRDs
- The Nushell CLI (`koncept`) **remains essential** as the build/render tool; Backstage wraps it as a self-service UI layer
- **One new output procedure** is needed: `kcl_to_backstage` to generate `catalog-info.yaml` from KCL models
- New technology requirement: **Node.js + TypeScript + React** for Backstage customization

**Gaps to Fill Before Adoption**:
1. `kcl_to_backstage` output procedure (catalog-info.yaml generation from KCL models)
2. Custom Backstage scaffolder actions wrapping `koncept` CLI
3. Node.js/TypeScript development capability

---

## 2. Current IDP State

### Completed Phases (1-7)

| Capability | Status |
|---|---|
| 8 output formats (YAML, Helm, Helmfile, Kusion, ArgoCD, Kustomize, Timoni, Crossplane) | ✅ |
| 268 unit tests, full TDD | ✅ |
| Nushell CLI (`koncept`) with render/validate/init/publish | ✅ |
| 16 framework templates (WebApp, Database, Kafka, PostgreSQL, MongoDB, RabbitMQ, Redis, Keycloak, OpenSearch, Vault, QuestDB, MinIO, Observability, OpenTelemetry) | ✅ |
| Framework builders (deployment, service, configmap, storage, service_account, leader, network_policy, pdb) | ✅ |
| Security (secretKeyRef, ExternalSecrets, check blocks, kubeconform) | ✅ |
| Crossplane compositions (cert-manager, Kafka, PostgreSQL, Keycloak) | ✅ |
| Generic `render.k` pattern with `-D output=TYPE` | ✅ |

### Current Architecture

```
Developer → koncept CLI → KCL Source → factory/ → output procedures → YAML/Helm/ArgoCD/etc.
```

### What's Missing

- **No web UI** — all interactions via CLI
- **No service catalog** — no central view of what's deployed where
- **No self-service** — developers need KCL/CLI knowledge
- **No visualizations** — no dependency graphs, health dashboards
- **No golden path templates** — scaffolding exists but only via CLI

---

## 3. Developer Portal Landscape

### Free Open-Source Options Evaluated

| Tool | Stars | License | Type | Verdict |
|---|---|---|---|---|
| **Backstage** (Spotify/CNCF) | 33,000+ | Apache-2.0 | Developer portal | **RECOMMENDED** — dominant OSS portal, massive plugin ecosystem |
| **Kratix** (Syntasso) | 739 | Apache-2.0 | Platform framework | NOT a portal — uses "Promises" like Crossplane, complementary |
| **Janus-IDP** (Red Hat) | — | Apache-2.0 | Backstage distribution | Based on Backstage, adds K8s plugins. Could use instead of vanilla Backstage |
| **Platformatic** | 2,000 | Apache-2.0 | Node.js app server | NOT relevant — application server, not developer portal |
| **Port.dev** | — | Commercial | Developer portal | NOT free — commercial SaaS |
| **Cortex** | — | Commercial | Service catalog | NOT free — commercial |
| **OpsLevel** | — | Commercial | Service catalog | NOT free — commercial |

### Conclusion

The free OSS developer portal space is **dominated by Backstage** with no comparable alternatives. Kratix is a platform framework (complementary to Crossplane, not a portal). All other portals with comparable features (Port, Cortex, OpsLevel) are commercial.

---

## 4. Backstage Deep Dive

### Architecture

```
┌──────────────────────────────────────────────┐
│              Backstage Frontend               │
│    React + TypeScript + Material UI           │
│    Plugin-based: standalone, service-backed   │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────┴───────────────────────────┐
│              Backstage Backend                │
│    Node.js + TypeScript                       │
│    Plugin-based: independent services         │
│    Extension points + wire protocol           │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────┴───────────────────────────┐
│              Database (PostgreSQL)             │
│    Knex-based migrations                      │
│    SQLite for development                     │
└──────────────────────────────────────────────┘
```

### Core Features

| Feature | Description | Relevance to idp-concept |
|---|---|---|
| **Software Catalog** | Central registry of all software (Components, APIs, Resources, Systems, Domains) | Maps to our Project/Stack/Module/Component hierarchy |
| **Software Templates** (Scaffolder) | Wizard-driven project creation with step-based actions | Maps to our KCL templates + `koncept init` |
| **TechDocs** | Docs-as-code from Markdown alongside source | Our `docs/` directory and README files |
| **Kubernetes Plugin** | View deployment health, pods, objects across clusters | Direct monitoring of our rendered outputs |
| **Search** | Full-text search across catalog, docs, and APIs | Service discovery across projects |

### Plugin Architecture

- **5 core features** (Catalog, Templates, TechDocs, Kubernetes, Search)
- **205 active community plugins** (as of 2025)
- **Plugin types**: standalone (frontend widgets), service-backed (backend API + frontend), third-party-backed (external service integration)
- **Custom actions**: TypeScript functions registered in the scaffolder backend, using `createTemplateAction` with zod schema validation

### Catalog Entity Model

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component  # or API, Resource, System, Domain, Group, User, Template, Location
metadata:
  name: my-service
  description: "..."
  labels: {}
  annotations: {}
  tags: []
  links: []
spec:
  type: service    # service, website, library (custom)
  lifecycle: production  # experimental, production, deprecated
  owner: team-name
  system: my-system
  dependsOn: []
  providesApis: []
  consumesApis: []
```

---

## 5. Compatibility Assessment

### Technology Matrix

| Our Technology | Backstage Support | Plugin/Integration | Status |
|---|---|---|---|
| **Kubernetes** | Core Plugin | `@backstage/plugin-kubernetes` (frontend + backend) | ✅ Native — shows deployments, pods, objects |
| **ArgoCD** | Community Plugin | Argo CD by Roadie | ✅ Active — view sync status, health |
| **Crossplane** | Community Plugin | Crossplane Resources by TeraSky | ✅ Active — view claims, XRs, managed resources, graph view |
| **Crossplane Claims** | Community Plugin | Kubernetes Ingestor by TeraSky | ✅ Active — auto-ingest claims as Components, XRDs as Templates |
| **Helm** | Via K8s Plugin | Kubernetes plugin tracks Helm releases | ✅ Indirect — via K8s resource monitoring |
| **Kafka** (Strimzi) | Community Plugin | Kafka plugin | ✅ Active — observability for clusters/topics |
| **Keycloak** | Community Plugin | Keycloak auth by Red Hat | ✅ Active — load users/groups for RBAC |
| **Vault** (HashiCorp) | Community Plugin | Vault plugin | ✅ Active — visualize secrets |
| **PostgreSQL** (CloudNativePG) | Via K8s Plugin | Kubernetes plugin monitors CRDs | ✅ Indirect |
| **KCL** | Custom Action needed | No existing plugin | ⚠️ Custom scaffolder action required |
| **Nushell CLI** | Custom Action needed | No existing plugin | ⚠️ Custom scaffolder action wrapping CLI |
| **Grafana** | Community Plugin | Grafana plugin | ✅ Active — embed dashboards |
| **Prometheus** | Community Plugin | Prometheus by Roadie | ✅ Active — metrics visualization |
| **SonarQube** | Community Plugin | SonarQube by SDA SE | ✅ Active — code quality |
| **GitHub** | Core/Community | GitHub Actions, PRs, Insights | ✅ Active — CI/CD, code |

### Verdict: **Fully Compatible**

Every technology in our stack has either a native Backstage plugin or can be integrated via custom actions. The two custom integrations needed (KCL execution, Nushell CLI wrapping) are straightforward scaffolder actions.

---

## 6. Concept Mapping: idp-concept → Backstage

### Entity Mapping

| idp-concept Concept | Backstage Kind | Backstage spec.type | Notes |
|---|---|---|---|
| **Project** (video_streaming, erp_back) | **Domain** | `product-area` | Groups all systems/components for a project |
| **Stack** | **System** | `product` or `service` | Collection of modules deployed together |
| **Component** (kind: APPLICATION) | **Component** | `service` | Backend services, web apps |
| **Component** (kind: INFRASTRUCTURE) | **Resource** | `database`, `cache`, `message-queue` | Infrastructure a system needs |
| **Accessory** (kind: CRD) | **Resource** | `kubernetes-crd` | Operator CRDs (Kafka, PostgreSQL, etc.) |
| **Accessory** (kind: SECRET) | **Resource** | `secret` | ExternalSecrets, Vault references |
| **ThirdParty** (HELM) | **Component** | `library` or **Resource** | External Helm charts |
| **K8sNamespace** | — | — | Implicit in Backstage namespace field |
| **Tenant** | **Group** | `customer` | Maps to organizational entity |
| **Site** | Labels/Annotations | `koncept.io/site: dev-cluster` | Environment metadata on entities |
| **Profile** | Labels | `koncept.io/profile: v1.0.0` | Version metadata |
| **Pre-release** | `spec.lifecycle` | `experimental` | Not yet production |
| **Release** | `spec.lifecycle` | `production` | Production deployment |
| **KCL Template** (WebAppModule) | **Template** | `service` | Scaffolder template for creating new services |
| **Crossplane XRD** | **API** + **Template** | `crd` | Via TeraSky Kubernetes Ingestor |

### Relationship Mapping

| idp-concept Relationship | Backstage Relation |
|---|---|
| Stack contains Components | System `hasPart` Component |
| Component `dependsOn` namespace | Component `dependsOn` Resource |
| Component consumes database | Component `dependsOn` Resource (type: database) |
| Tenant owns Project | Group `ownerOf` Domain |
| Module extends template | Template → catalog-info.yaml generation |

### Example: erp_back → Backstage Catalog

```yaml
# Domain: erp_back project
apiVersion: backstage.io/v1alpha1
kind: Domain
metadata:
  name: erp-back
  description: ERP Back project — uses new framework templates
spec:
  owner: platform-team

---
# System: erp_back stack (e.g., "full" stack)
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: erp-back-full
  description: Full deployment stack for ERP Back
  tags: [kcl, kubernetes]
spec:
  owner: platform-team
  domain: erp-back

---
# Component: erp-api application
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: erp-api
  description: ERP Back API service
  annotations:
    backstage.io/kubernetes-id: erp-api
    argocd/app-name: erp-api
    koncept.io/module-type: WebAppModule
  tags: [java, spring-boot, kcl]
spec:
  type: service
  lifecycle: production
  owner: platform-team
  system: erp-back-full
  dependsOn:
    - resource:default/erp-db

---
# Resource: PostgreSQL database
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: erp-db
  description: PostgreSQL cluster for ERP Back
  annotations:
    backstage.io/kubernetes-id: erp-db-cluster
    koncept.io/module-type: PostgreSQLClusterModule
spec:
  type: database
  lifecycle: production
  owner: platform-team
  system: erp-back-full
```

---

## 7. Plugin Ecosystem for Our Stack

### Tier 1: Must-Have Plugins (Day One)

| Plugin | By | Purpose | Why |
|---|---|---|---|
| **Kubernetes** | Backstage Core | View pods, deployments, objects | Core visibility into our K8s outputs |
| **Kubernetes Ingestor** | TeraSky | Auto-create catalog from K8s resources | Bridges K8s → Backstage catalog automatically |
| **Crossplane Resources** | TeraSky | View Crossplane claims, XRs, graph | Our crossplane_v2/ compositions |
| **Argo CD** | Roadie | View ArgoCD sync status | GitOps deployment status |
| **Catalog Graph** | SDA SE | Visualize entity relationships | Dependency graphs between services |

### Tier 2: High-Value Plugins (Week One)

| Plugin | By | Purpose |
|---|---|---|
| **Kafka** | @nirga | Monitor Strimzi clusters and topics |
| **Keycloak Auth** | Red Hat | SSO login, load users/groups into catalog |
| **Vault** | Spread Group | Visualize secrets |
| **Grafana** | K-Phoen | Embed monitoring dashboards |
| **Prometheus** | Roadie | Metrics and alerts |
| **GitHub Actions** | Spotify | CI/CD pipeline status |
| **TechDocs** | Backstage Core | Docs-as-code from our `docs/` |

### Tier 3: Nice-to-Have Plugins (Month One)

| Plugin | Purpose |
|---|---|
| **SonarQube** | Code quality metrics |
| **Cost Insights** / **OpenCost** | Cloud cost monitoring |
| **DORA Metrics** | Engineering performance tracking |
| **Tech Radar** | Technology standards visualization |
| **API Docs** | OpenAPI/AsyncAPI browsing |

### Critical Plugin: TeraSky Kubernetes Ingestor

This plugin deserves special attention because it **solves our biggest integration challenge**:

**What it does**:
1. **Auto-ingests K8s workloads** (Deployments, StatefulSets, etc.) as Backstage Components
2. **Auto-ingests Crossplane Claims** as Backstage Components
3. **Auto-generates Backstage Templates** from Crossplane XRDs (our `crossplane_v2/` XRDs become self-service forms!)
4. **Creates API entities** for XRDs with CRD YAML definitions
5. **Maps relationships** between claims and APIs automatically
6. **Rich annotation system** for customizing entity creation

**How it fits our architecture**:
- Our `koncept render crossplane` generates XRDs/Compositions → deployed to K8s → Ingestor auto-creates Templates
- Our `koncept render argocd` generates K8s manifests → deployed via ArgoCD → Ingestor auto-creates Components
- No manual `catalog-info.yaml` maintenance needed for deployed resources

**Annotations we'd add to our K8s manifests**:
```yaml
metadata:
  annotations:
    terasky.backstage.io/owner: "platform-team"
    terasky.backstage.io/system: "erp-back-full"
    terasky.backstage.io/lifecycle: "production"
    terasky.backstage.io/component-type: "service"
    terasky.backstage.io/source-code-repo-url: "https://github.com/org/idp-concept"
```

---

## 8. Nushell CLI Coexistence Strategy

### Question: Does `koncept` still make sense alongside Backstage?

**Answer: Yes, absolutely. They serve different roles.**

### Role Separation

| Aspect | `koncept` CLI | Backstage Portal |
|---|---|---|
| **Role** | Build/render tool ("compiler") | Self-service UI ("IDE/dashboard") |
| **Users** | Platform engineers, CI/CD pipelines | Developers, managers, new team members |
| **Interaction** | Terminal commands | Web browser, forms |
| **Strengths** | Fast, scriptable, automatable, works offline | Visual, discoverable, guided workflows |
| **K8s knowledge** | Some required (understand outputs) | Zero required |
| **Analogy** | `gcc`/`cargo`/`npm build` | IDE with GUI builder |

### Architecture with Both

```
┌─────────────────────────────────────────────────────────┐
│                    BACKSTAGE PORTAL                       │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐   │
│  │  Catalog     │  │  Templates   │  │  K8s Status   │   │
│  │  (entities)  │  │  (scaffolder)│  │  (monitoring)  │   │
│  └──────┬───────┘  └──────┬───────┘  └───────────────┘   │
│         │                 │                               │
│         │    ┌────────────┴────────────┐                  │
│         │    │  Custom Scaffolder      │                  │
│         │    │  Actions (TypeScript)   │                  │
│         │    └────────────┬────────────┘                  │
└─────────┼────────────────┼────────────────────────────────┘
          │                │
          ▼                ▼
┌─────────────────────────────────────────────────────────┐
│                   KONCEPT CLI (Nushell)                    │
│  koncept render argocd | helmfile | kusion | crossplane   │
│  koncept validate | koncept init | koncept publish        │
└─────────────────────────────┬───────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│                  KCL SOURCE OF TRUTH                      │
│  framework/ → projects/ → factory/ → output procedures    │
└─────────────────────────────────────────────────────────┘
```

### Integration Pattern

Backstage **wraps** `koncept` via custom scaffolder actions:

```typescript
// Example: backstage-plugin-koncept/src/actions/render.ts
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { z } from 'zod';
import { execSync } from 'child_process';

export const konceptRenderAction = createTemplateAction({
  id: 'koncept:render',
  description: 'Render KCL manifests using koncept CLI',
  schema: {
    input: z.object({
      output: z.enum(['argocd', 'helmfile', 'kusion', 'crossplane', 'kustomize', 'timoni']),
      factory: z.string().optional(),
    }),
  },
  async handler(ctx) {
    const { output, factory } = ctx.input;
    const cmd = `koncept render ${output}${factory ? ` --factory ${factory}` : ''}`;
    const result = execSync(cmd, { cwd: ctx.workspacePath, encoding: 'utf-8' });
    ctx.logger.info(result);
  },
});
```

### When to Use Which

| Scenario | Tool |
|---|---|
| Platform engineer developing new templates | `koncept` CLI |
| CI/CD pipeline rendering manifests | `koncept` CLI |
| Developer creating a new service | Backstage Template (→ calls `koncept init`) |
| Developer deploying to a new environment | Backstage Template (→ calls `koncept render`) |
| Viewing deployment health | Backstage K8s plugin |
| Discovering what services exist | Backstage Catalog |
| Debugging a failed render | `koncept validate` CLI |
| Publishing a KCL module | `koncept publish` CLI |

---

## 9. Gap Analysis

### Gaps to Fill BEFORE Backstage Adoption

| Gap | Priority | Effort | Description |
|---|---|---|---|
| **`kcl_to_backstage` output procedure** | P0 | Medium | Generate `catalog-info.yaml` from KCL Stack/Component/Accessory models. New output procedure in `framework/procedures/` |
| **Backstage annotations in manifests** | P0 | Low | Add TeraSky Ingestor annotations to K8s manifests generated by builders (system, owner, lifecycle, component-type) |
| **Node.js/TypeScript development setup** | P1 | Low | Package.json, TypeScript config for custom Backstage plugins/actions |
| **Custom scaffolder actions** | P1 | Medium | `koncept:render`, `koncept:validate`, `koncept:init` actions wrapping CLI |
| **Backstage instance infrastructure** | P1 | Medium | PostgreSQL (use CloudNativePG template), Node.js deployment, ingress config |
| **Authentication setup** | P2 | Medium | Keycloak integration or GitHub OAuth for portal access |

### Gaps Already Filled (No Action Needed)

| Requirement | Already Have |
|---|---|
| PostgreSQL for Backstage database | CloudNativePG template (`framework/templates/postgresql.k`) |
| Service health monitoring | K8s core plugin works with our deployed manifests |
| Crossplane resource visibility | TeraSky Crossplane plugin reads our XRDs |
| ArgoCD status | Roadie ArgoCD plugin reads our ArgoCD Applications |
| Keycloak auth | Red Hat Keycloak plugin reads from our Keycloak instance |
| Git-based catalog source | Our monorepo works with Backstage Location entities |
| Documentation | TechDocs reads Markdown from `docs/` |

### New Output Procedure: `kcl_to_backstage`

This is the **most important pre-work** before adopting Backstage. It generates Backstage `catalog-info.yaml` descriptors from our KCL Stack model.

```
Input: Stack (components, accessories, namespaces, metadata)
Output: Multi-document YAML with Backstage entity descriptors

- 1 Domain entity per Project
- 1 System entity per Stack
- 1 Component entity per APPLICATION Component
- 1 Resource entity per INFRASTRUCTURE Component
- 1 Resource entity per Accessory (CRD, SECRET)
- 1 Location entity pointing to all descriptors
```

This follows the same pattern as our existing output procedures (`kcl_to_yaml`, `kcl_to_helm`, etc.) — TDD, 8+ tests, integrated into `render.k` and `koncept` CLI.

---

## 10. CNCF Maturity Model Alignment

### Current State: Level 2 (Operationalized)

| Aspect | Current | Evidence |
|---|---|---|
| Investment | Dedicated tooling (KCL, Nushell CLI) | framework/, platform_cli/ |
| Adoption | Platform engineers use it, developers need training | CLI requires KCL/factory knowledge |
| Interfaces | CLI only (`koncept`) | No web UI, no self-service portal |
| Operations | Manual factory creation, some scaffolding | `koncept init` exists but basic |
| Measurement | No metrics | No render success rates, adoption tracking |

### Target State: Level 3 (Scalable) — WITH Backstage

| Aspect | Target | How Backstage Helps |
|---|---|---|
| Investment | Product-like platform with dedicated team | Backstage infrastructure, plugin maintenance |
| Adoption | Developers use portal without K8s knowledge | Self-service templates, guided workflows |
| Interfaces | CLI + Web portal | Backstage homepage, catalog, templates |
| Operations | Automated provisioning, catalog sync | TeraSky Ingestor auto-syncs, scaffolder automates |
| Measurement | Track template usage, render times, adoption | Backstage analytics, `backstage.io/time-saved` annotation |

### Maturity Progression

```
Level 2 (Current)                 Level 3 (With Backstage)
─────────────────                 ──────────────────────────
CLI-only interface           →    CLI + Web portal (dual interface)
Manual catalog management    →    Auto-ingested catalog from K8s
Training-dependent adoption  →    Self-service golden paths
No metrics                   →    Template usage, render stats
Engineers create projects    →    Anyone creates via portal wizard
```

---

## 11. Adoption Roadmap

### Phase 8: Backstage Catalog Foundation

**Owner**: Platform Engineer (Low-Level) for procedures; Platform Engineer (High-Level) for configuration

**Duration**: 2-4 weeks

#### 8.1 `kcl_to_backstage` Output Procedure (TDD)

New output procedure to generate Backstage catalog descriptors from Stack:

```
framework/procedures/kcl_to_backstage.k
framework/tests/procedures/backstage_test.k
```

Deliverables:
- `generate_backstage_component` lambda
- `generate_backstage_resource` lambda
- `generate_backstage_system` lambda
- `generate_backstage_domain` lambda
- `generate_backstage_location` lambda
- `generate_catalog_from_stack` lambda (composes all above)
- 10+ TDD unit tests
- Integration into `render.k` (`-D output=backstage`)
- CLI support: `koncept render backstage`

#### 8.2 Backstage Annotations in Manifests

Add annotations to generated K8s manifests for TeraSky Ingestor:

- Update `framework/builders/deployment.k` to include Backstage annotations
- Annotations: `system`, `owner`, `lifecycle`, `component-type`, `source-code-repo-url`
- Source from `BaseConfigurations` (already has `gitRepoUrl`, extend with `backstageOwner`, `backstageSystem`)

#### 8.3 Backstage Instance Setup

- PostgreSQL via CloudNativePG template (already exists)
- Node.js deployment (Backstage app) — Helm chart or KCL Component
- `app-config.yaml` with catalog locations pointing to our monorepo
- GitHub or Keycloak authentication

### Phase 9: Portal Plugin Integration

**Owner**: Platform Engineer (High-Level) for plugin configuration; Developer for testing

**Duration**: 2-3 weeks

#### 9.1 Core Plugin Installation

Install and configure:
- Kubernetes plugin → connect to target clusters
- TeraSky Kubernetes Ingestor → auto-discover workloads and Crossplane claims
- TeraSky Crossplane Resources → view claim/XR/managed resource graphs
- Argo CD plugin → view GitOps sync status
- Catalog Graph → visualize relationships

#### 9.2 Auth & RBAC

- Keycloak integration → SSO for portal access
- Role mapping: Developer → read-only catalog + template usage; PE → full access

#### 9.3 TechDocs

- Configure TechDocs to read from `docs/` directory
- Add `backstage.io/techdocs-ref` annotations to catalog entities

### Phase 10: Self-Service Scaffolder

**Owner**: Platform Engineer (Low-Level) for custom actions; Platform Engineer (High-Level) for templates

**Duration**: 3-4 weeks

#### 10.1 Custom Scaffolder Actions

Create TypeScript actions wrapping `koncept` CLI:
- `koncept:render` — render manifests in specified format
- `koncept:validate` — validate configurations
- `koncept:init` — scaffold new project/release
- `koncept:publish` — publish KCL module

#### 10.2 Backstage Templates

Create Backstage Templates mapping to our KCL templates:

| Backstage Template | KCL Template | What it creates |
|---|---|---|
| "New Web Application" | WebAppModule | Service + Deployment + ConfigMap |
| "New Database" | PostgreSQLClusterModule | CloudNativePG Cluster |
| "New Kafka Cluster" | KafkaClusterModule | Strimzi Kafka + topics |
| "New Redis Cache" | RedisModule | Redis standalone/cluster |
| "New Release" | `koncept init` | Complete factory structure |
| "Deploy to New Environment" | `koncept render` | Rendered manifests for target |

#### 10.3 Self-Service Workflows

1. Developer selects "New Web Application" template in Backstage
2. Fills form: name, port, resources, environment
3. Backstage scaffolder executes steps:
   - Creates KCL module file from template
   - Runs `koncept validate`
   - Opens PR to Git repository
4. Platform engineer reviews and merges
5. ArgoCD deploys, TeraSky Ingestor updates catalog

---

## 12. Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| **Backstage complexity** — large Node.js/React app | High setup cost | Medium | Start minimal: catalog + K8s plugin only. Add incrementally. |
| **Backstage maintenance** — frequent releases, breaking changes | Ongoing effort | High | Pin Backstage version, use LTS releases, consider Janus-IDP distribution |
| **TeraSky plugin maturity** — smaller community (69 stars) | Plugin bugs, slow fixes | Medium | TeraSky actively maintains (updated 4 days ago for Backstage 1.49.3). Contribute fixes upstream. |
| **Node.js/TypeScript learning curve** | Slower development of custom actions | Medium | Custom actions are small TypeScript functions; scaffold from examples |
| **Portal adoption** — developers may prefer CLI | Low portal usage | Low | Make portal the golden path for common tasks; CLI for power users |
| **KCL in Backstage** — no native integration | Custom action needed for every KCL operation | Medium | Wrap `koncept` CLI (Nushell); KCL doesn't need to run in Node.js |
| **Monorepo catalog management** — many entities in one repo | Catalog complexity | Low | Use Location entities with glob patterns; TeraSky Ingestor handles deployed resources |

---

## 13. Decision Record

### ADR-001: Adopt Backstage as Developer Portal

**Status**: Proposed

**Context**: idp-concept has completed 7 phases of evolution with 8 output formats, 268 tests, and a full CLI. The platform lacks a web UI, service catalog, and self-service capabilities. CNCF Platform Engineering Maturity Model indicates we're at Level 2, and Level 3 requires self-service interfaces.

**Decision**: Adopt Backstage (CNCF Incubation) as the developer portal.

**Rationale**:
1. Only viable free OSS developer portal with sufficient maturity
2. 33,000+ stars, 1,867 contributors, Apache-2.0 license
3. Plugins exist for every technology in our stack
4. TeraSky Kubernetes Ingestor auto-bridges K8s resources → catalog
5. Custom scaffolder actions enable wrapping our Nushell CLI
6. CNCF ecosystem alignment (Backstage, Crossplane, ArgoCD all CNCF)

**Consequences**:
- New technology requirement: Node.js + TypeScript + React
- New infrastructure: PostgreSQL for Backstage (already have template)
- New output procedure: `kcl_to_backstage`
- Ongoing Backstage version maintenance
- `koncept` CLI remains as the build tool; Backstage wraps it

### ADR-002: Keep Nushell CLI Alongside Portal

**Status**: Proposed

**Context**: With a web portal, should the Nushell CLI (`koncept`) be deprecated?

**Decision**: Keep `koncept` CLI as the primary build/render tool. Backstage wraps it via scaffolder actions.

**Rationale**:
1. CLI is the "compiler" — it transforms KCL into outputs. This is CI/CD critical.
2. Platform engineers prefer terminal workflows
3. Backstage scaffolder actions executing CLI commands is the standard Backstage pattern
4. CLI works offline, in CI/CD, and without Backstage infrastructure
5. Removing CLI would require reimplementing all rendering logic in TypeScript

**Consequences**:
- Two interfaces to maintain (CLI + portal)
- CLI commands must remain stable (portal depends on them)
- Need documentation for when to use which
