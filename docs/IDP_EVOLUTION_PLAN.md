# IDP Evolution Plan

> Single-source-of-truth roadmap for **idp-concept** — evolving from a functional prototype into a production-grade, extensible Internal Developer Platform.

## Table of Contents

- [1. Vision & Principles](#1-vision--principles)
- [2. User Profiles](#2-user-profiles)
- [3. CNCF Platform Engineering Maturity Model Alignment](#3-cncf-platform-engineering-maturity-model-alignment)
- [4. Accomplished Phases (1–10) — Summary](#4-accomplished-phases-110--summary)
- [5. Phase 11 — Go CLI: Hybrid Architecture](#5-phase-11--go-cli-hybrid-architecture)
- [6. Phase 12 — CI/CD Integration & Validation Pipeline](#6-phase-12--cicd-integration--validation-pipeline)
- [7. Phase 13 — Framework Package Registry & Versioning](#7-phase-13--framework-package-registry--versioning)
- [8. Phase 14 — Configuration Extensibility & Plugin Architecture](#8-phase-14--configuration-extensibility--plugin-architecture)
- [9. Phase 15 — Policy-as-Code & Governance](#9-phase-15--policy-as-code--governance)
- [10. Phase 16 — Fleet Output & Multi-Cluster Strategy](#10-phase-16--fleet-output--multi-cluster-strategy)
- [11. Phase 17 — Score Spec Input Format](#11-phase-17--score-spec-input-format)
- [12. Phase 18 — Observability-Driven Platform](#12-phase-18--observability-driven-platform)
- [13. Strategic Roadmap Overview](#13-strategic-roadmap-overview)
- [14. Architecture Decision Records](#14-architecture-decision-records)
- [15. User Workflow Guides](#15-user-workflow-guides) — [Standalone: USER_WORKFLOW_GUIDES.md](./USER_WORKFLOW_GUIDES.md)
- [16. Work Matrix by User Profile](#16-work-matrix-by-user-profile) — [Standalone: WORK_MATRIX.md](./WORK_MATRIX.md)
- [17. Migration Guide: video_streaming → template pattern](#17-migration-guide-video_streaming--template-pattern) — [Standalone: MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)
- [Appendix A — Completed Implementation Progress](#appendix-a--completed-implementation-progress)
- [Appendix B — Reference Patterns & Competitive Positioning](#appendix-b--reference-patterns--competitive-positioning)

---

## 1. Vision & Principles

### Vision

A KCL-powered IDP where:
- **Developers** deploy and configure applications using only `koncept` commands or a Backstage portal — zero Kubernetes knowledge required
- **Platform Engineers (High-Level)** compose stacks, tenants, and sites using pre-built templates and schemas
- **Platform Engineers (Low-Level)** design framework internals, builders, templates, and output procedures

### Production-Readiness Goals

1. **Stateful services via operators** — Database, cache, and messaging clusters managed by Kubernetes operators (CloudNativePG, Redis Operator, Strimzi) instead of raw StatefulSets
2. **Third-party chart reuse** — Leverage production-hardened Helm charts (Bitnami, official operator charts) instead of building everything from scratch
3. **Multi-format ecosystem** — Support consuming and producing Kustomize, Jsonnet, OCI artifacts alongside Helm/Helmfile
4. **Observable infrastructure** — Prometheus metrics, Grafana dashboards, OpenTelemetry traces from day one
5. **Secret management** — Integration with external secret stores (Vault, AWS Secrets Manager) via ExternalSecrets operator
6. **Network security** — NetworkPolicies, PodSecurityStandards, mTLS via service mesh
7. **High availability** — PodDisruptionBudgets, topology spread constraints, anti-affinity rules
8. **Single-binary distribution** — Go CLI wrapping KCL Go SDK for zero-dependency deployment
9. **Policy governance** — Automated compliance checks via policy-as-code (OPA/Kyverno)
10. **Multi-cluster targeting** — Deploy to multiple clusters via Fleet or ArgoCD ApplicationSets

### Design Principles

1. **Single Source of Truth** — KCL models define everything; outputs (YAML, Helm, Helmfile, Kusion, ArgoCD, Kustomize, Timoni, Crossplane, Backstage, Fleet) are derived
2. **Progressive Disclosure** — Each user profile sees only the complexity appropriate to their role
3. **Type Safety at Compile Time** — Catch misconfigurations in KCL, not at Kubernetes deployment time
4. **Parameterized Outputs** — Generate Helm charts with configurable values, not flattened final manifests
5. **Secure by Default** — No hardcoded secrets, `IfNotPresent` image pull, least-privilege RBAC
6. **Configuration over Code** — Prefer declarative configuration; reserve Go/imperative code for tooling boundaries only
7. **Extensible without Forking** — Teams can add custom builders, templates, and output formats without modifying framework internals

### Technology Decision: KCL + Go Hybrid

> Based on the analysis in [PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md](./PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md).

**KCL** stays as the configuration and policy layer. **Go** is introduced only for the CLI/tooling layer via the [KCL Go SDK](https://www.kcl-lang.io/docs/reference/xlang-api/go-api). This is the same approach validated by KusionStack/kusion (1,287+ stars).

```
┌──────────────────────────────────────────────────┐
│                   Go CLI Layer                    │
│  (single binary, API access, scaffolding, CI)     │
├──────────────────────────────────────────────────┤
│              KCL Go SDK Bridge                    │
│  (Run, RunFiles, Validate, Test, FormatCode)      │
├──────────────────────────────────────────────────┤
│                KCL Config Layer                    │
│  (schemas, templates, builders, procedures)        │
│  (2,500+ lines of working, tested KCL)             │
└──────────────────────────────────────────────────┘
```

**Why not migrate entirely to Go?**
- KCL's union operator (`|`) for config merge has no Go equivalent — you'd write a custom deep-merge library
- Schema inheritance is natural in KCL, verbose in Go struct embedding
- Compile-time validation via `check:` blocks catches errors before rendering
- KCL is CNCF Sandbox with growing ecosystem — not a dead project
- 287+ passing tests validate the existing KCL foundation

---

## 2. User Profiles

### Profile 1: Developer

**Interaction**: `koncept` CLI commands or Backstage portal. Never edits `.k` files.

**Commands**:
- `koncept render argocd|helmfile|kusion|kustomize|timoni|crossplane|backstage`
- `koncept validate` — Validate configurations before rendering
- `koncept status` — Check current release status
- `koncept diff` — Show changes between current and previous render

**Configures**: Application-level settings via site/tenant YAML overrides (port, replicas, env vars, feature flags).

### Profile 2: Platform Engineer — High-Level

**Interaction**: KCL files in `projects/<name>/` directories (stacks, tenants, sites, modules using templates).

**Capabilities**: Define stacks, create tenants/sites, compose modules using framework templates (`WebAppModule`, `SingleDatabaseModule`, `KafkaClusterModule`, etc.), create pre-releases and releases.

### Profile 3: Platform Engineer — Low-Level

**Interaction**: KCL files in `framework/` directories.

**Capabilities**: Create/modify builders, design templates, implement output procedures, define core model schemas, design the factory pattern, maintain `kcl.mod` dependency graphs.

---

## 3. CNCF Platform Engineering Maturity Model Alignment

> Reference: [CNCF Platform Engineering Maturity Model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/)

### Current State Assessment

After completing Phases 1–10, idp-concept sits between **Level 2 (Operationalized)** and **Level 3 (Scalable)** across different aspects:

| Aspect | Current Level | Evidence | Target Level |
|---|---|---|---|
| **Investment** | L2 → L3 | Dedicated tooling (KCL + Nushell CLI), 287+ tests, 9 output formats, Backstage templates designed | L3 (Product) → L4 (Ecosystem) |
| **Adoption** | L2 (Extrinsic push) | CLI requires knowledge of factory structure; Backstage designed but not deployed | L3 (Intrinsic pull) |
| **Interfaces** | L2 → L3 | CLI + Backstage portal designed; need single-binary distribution | L3 (Self-service) → L4 (Integrated) |
| **Operations** | L2 (Centrally tracked) | Manual factory creation for each release; `koncept init` scaffolding exists | L3 (Centrally enabled) |
| **Measurement** | L1 (Ad hoc) | No metrics, no usage analytics, no feedback loops | L3 (Insights) |

### Level 3 Requirements (Target)

| Requirement | Phase | Implementation |
|---|---|---|
| Treat platform as product | 11–14 | Go CLI as distributable product, versioned framework packages |
| Self-service interfaces | 8–10 (done) + 11 | Backstage portal + single-binary CLI |
| Measurable adoption | 18 | OpenTelemetry metrics on render times, template usage, error rates |
| Tested user experiences | 12 | E2E validation pipelines, golden file tests |
| Published roadmap | This document | Phases 11–18 with clear owners and deliverables |
| Feature removal discipline | 14 | Plugin architecture — deprecate via version, not deletion |

### Level 4 Aspirations (Long-term)

| Aspiration | Phase | How |
|---|---|---|
| Enable specialists to extend | 14 | Plugin architecture for custom builders/templates/procedures |
| Organization-wide efficiency | 15–16 | Policy-as-code for compliance; multi-cluster for scale |
| Centralized governance | 15 | Automated policy gates in CI/CD pipeline |
| Ecosystem enablement | 13–14 | OCI registry for community-contributed modules |

---

## 4. Accomplished Phases (1–10) — Summary

> Full implementation details: [Appendix A](#appendix-a--completed-implementation-progress)

### Phase 1 — Foundation Hardening ✅

- Removed hardcoded credentials (replaced with `secretKeyRef`)
- Fixed `imagePullPolicy` defaults (`IfNotPresent`)
- Externalized Git repo URLs to `BaseConfigurations`
- Fixed code style inconsistencies

### Phase 2 — Helmfile Parameterization ✅

- Helm values extraction (`extract_helm_values` + `generate_chart` lambdas)
- Helmfile generation from Stack components
- Static Helm Go templates (deployment, service, configmap, serviceaccount, pvc, _helpers.tpl)
- Strategy B pipeline: KCL generates values.yaml; templates are static Go templates
- Validated: `helm lint` + `helm template` + `kubeconform` all passing

### Phase 3 — KCL Code Quality ✅

- `EnvVar` schema with `KeySelector`, `EnvVarSource` and validation
- `check` blocks on `DeploymentSpec`, `ServiceSpec`, `PersistentVolumeSpec`
- Documented all justified `any` types with `# framework-generic` comments
- **287 unit tests** in `framework/tests/` — all passing via `kcl test ./...`

### Phase 4 — Developer Experience ✅

- `koncept validate` — pre-render validation
- `koncept init` — scaffold new factory directories
- Configurable builder filenames via `koncept.yaml`
- Generic `render.k` pattern with `-D output=TYPE`
- `DEVELOPER_QUICKSTART.md` documentation

### Phase 5 — Advanced Platform Features ✅

- ArgoCD Application + AppProject generation from Stack
- NetworkPolicy builder (ingress/egress/deny-all)
- PodDisruptionBudget builder
- Secret management schemas (`SecretReference`, `ExternalSecret`, `build_external_secret`)

### Phase 6 — Production Infrastructure ✅

15 framework templates covering the full infrastructure catalog:

| Template | Operator/Chart | Tests |
|---|---|---|
| PostgreSQL | CloudNativePG (`cnpg.io/v1`) | 10 |
| MongoDB | MCK (`mongodbcommunity.mongodb.com/v1`) | 6 |
| Kafka | Strimzi | Template |
| RabbitMQ | cluster-operator (`rabbitmq.com/v1beta1`) | 7 |
| Redis | OT Operator (`redis.opstreelabs.in/v1beta2`) | 6 |
| Keycloak | Keycloak Operator (`k8s.keycloak.org/v2alpha1`) | 5 |
| OpenSearch | opensearch-k8s-operator (`opensearch.org/v1`) | 8 |
| Vault | VSO (`secrets.hashicorp.com/v1beta1`) ⚠️ BUSL-1.1 | 7 |
| QuestDB | Helm chart (no operator) | 4 |
| MinIO | Operator CRD + Bitnami Helm fallback | 8 |
| OpenTelemetry | OTel Operator (`opentelemetry.io/v1beta1`) | 13 |
| Observability | Prometheus + Grafana + ServiceMonitor | 8 |
| Backstage | Official Helm chart | 5 |

### Phase 7 — Multi-Format Output & Ecosystem ✅

**9 output formats** from a single KCL source:

| Format | Procedure | CLI | Tests |
|---|---|---|---|
| YAML (ArgoCD/GitOps) | `kcl_to_yaml` | `koncept render argocd` | 5 |
| ArgoCD Applications | `kcl_to_argocd` | `koncept render argocd` | 5 |
| Helm Charts | `kcl_to_helm` | `koncept render helmfile` | 5 |
| Helmfile | `kcl_to_helmfile` | `koncept render helmfile` | 5 |
| Kusion Spec | `kcl_to_kusion` | `koncept render kusion` | 8 |
| Kustomize | `kcl_to_kustomize` | `koncept render kustomize` | 8 |
| Timoni (experimental) | `kcl_to_timoni` | `koncept render timoni` | 11 |
| Crossplane XRD+Composition | `kcl_to_crossplane` | `koncept render crossplane` | 25 |
| Backstage Catalog | `kcl_to_backstage` | `koncept render backstage` | 14 |

### Phase 8 — Developer Portal: Backstage Catalog ✅

- `kcl_to_backstage` procedure (Domain → System → Component → Resource entities)
- Backstage annotations in K8s manifests
- TechDocs integration via `mkdocs.yml`
- Backstage Helm chart template

### Phase 9 — Developer Portal: Plugin Integration ✅

- Plugin guide: Kubernetes, TeraSky Ingestor, Crossplane Resources, ArgoCD, Catalog Graph
- Keycloak auth + RBAC configuration
- TechDocs setup; full `app-config.yaml` reference

### Phase 10 — Developer Portal: Self-Service Scaffolder ✅

- Custom TypeScript actions: `koncept:render`, `koncept:validate`, `koncept:init`, `koncept:publish`
- 8 Backstage Templates: Web Application, PostgreSQL, Kafka, Redis, MongoDB, RabbitMQ, New Release, Deploy to Environment
- End-to-end self-service workflow

### Current Architecture Diagram

```
                     DEVELOPER (nu commands / Backstage portal)
  koncept render <format> | koncept validate | koncept init | koncept publish
                              │
                              ▼
                     FACTORY (per release)
  factory_seed.k → FactorySeed auto-merges 4 config layers → instantiate stack
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
   Components            Accessories            ThirdParty
   WebAppModule          Operator CRDs          Helm Charts
   DatabaseModule        (CNPG, Redis,          (Bitnami,
   KafkaModule           Strimzi, MCK)          official)
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ▼
                   Output Procedures (9 formats)
              ┌──────────────────────────────────────┐
              │ kcl_to_yaml       kcl_to_argocd      │
              │ kcl_to_helm       kcl_to_helmfile     │
              │ kcl_to_kusion     kcl_to_kustomize    │
              │ kcl_to_timoni     kcl_to_crossplane   │
              │ kcl_to_backstage                      │
              └──────────────────────────────────────┘
```

### Test & Validation Summary

| Metric | Value |
|---|---|
| Unit tests | 287 passing |
| Output formats | 9 |
| Framework templates | 15 |
| Builder schemas | 8 |
| Projects validated | erp_back (dev/stg/prod), video_streaming (dev) |
| Kubeconform | 29/29 valid, 0 invalid |

---

## 5. Phase 11 — Go CLI: Hybrid Architecture

**Owner**: Platform Engineer (Low-Level)
**CNCF Target**: L2 → L3 (Self-service solutions via single-binary distribution)
**Priority**: P0 — Highest impact for adoption

### 5.1 Problem Statement

The current CLI requires two runtime dependencies: **Nushell** (`nu`) and **KCL** (`kcl`). This creates adoption friction:
- Developers must install two niche tools before they can use the platform
- CI/CD pipelines need custom container images with both runtimes
- Version drift between `nu`/`kcl` versions across team members breaks reproducibility
- Error messages from Nushell are unfamiliar to most engineers

### 5.2 Target Architecture

A single Go binary (`koncept`) that embeds the KCL runtime via the [KCL Go SDK](https://www.kcl-lang.io/docs/reference/xlang-api/go-api):

```
┌───────────────────────────────────────────────────────────────────┐
│                      koncept (Go binary)                          │
│                                                                   │
│  ┌──────────┐  ┌───────────┐  ┌───────────┐  ┌───────────────┐  │
│  │ cmd/     │  │ internal/ │  │ internal/ │  │ internal/     │  │
│  │ render   │  │ factory/  │  │ validate/ │  │ scaffold/     │  │
│  │ validate │  │ discover  │  │ kubecon-  │  │ project/      │  │
│  │ init     │  │ seed      │  │ form      │  │ release/      │  │
│  │ publish  │  │ render    │  │ policy    │  │ module/       │  │
│  │ diff     │  │           │  │           │  │               │  │
│  │ status   │  │           │  │           │  │               │  │
│  └──────┬───┘  └─────┬─────┘  └─────┬─────┘  └───────┬───────┘  │
│         │            │              │                │            │
│         └────────────┼──────────────┼────────────────┘            │
│                      ▼                                            │
│              ┌──────────────────┐                                 │
│              │   KCL Go SDK     │                                 │
│              │  kcl.RunFiles()  │                                 │
│              │  kcl.Validate()  │                                 │
│              │  kcl.Test()      │                                 │
│              │  kcl.FormatCode()│                                 │
│              └──────────────────┘                                 │
│                      │                                            │
│              ┌──────────────────┐                                 │
│              │   KCL Config     │                                 │
│              │   Layer (as-is)  │                                 │
│              │   framework/     │                                 │
│              │   projects/      │                                 │
│              └──────────────────┘                                 │
└───────────────────────────────────────────────────────────────────┘
```

### 5.3 Go CLI Design Principles

1. **Zero runtime dependencies** — Single binary, `go install` or download from releases
2. **Backward-compatible** — Same commands as the Nushell CLI (`koncept render argocd`, `koncept validate`, etc.)
3. **KCL stays untouched** — The Go CLI calls `kcl.RunFiles()` on existing KCL code; no KCL rewriting
4. **Progressive migration** — Nushell CLI continues to work; Go CLI is the recommended path for new adopters
5. **Configurable** — YAML config file (`koncept.yaml`) at project root for project-specific settings

### 5.4 Go Project Structure

```
cmd/koncept/
├── main.go                          # CLI entry point (cobra)
├── cmd/
│   ├── render.go                    # koncept render <format>
│   ├── validate.go                  # koncept validate
│   ├── init.go                      # koncept init
│   ├── publish.go                   # koncept publish
│   ├── diff.go                      # koncept diff (NEW)
│   ├── status.go                    # koncept status (NEW)
│   ├── test.go                      # koncept test (NEW — wraps kcl test)
│   └── fmt.go                       # koncept fmt (NEW — wraps kcl fmt)
├── internal/
│   ├── factory/
│   │   ├── discover.go              # Auto-discover factory dirs + render.k
│   │   ├── seed.go                  # Parse factory_seed.k outputs
│   │   └── render.go                # Call kcl.RunFiles() with -D options
│   ├── validate/
│   │   ├── kcl.go                   # KCL compilation validation
│   │   ├── kubeconform.go           # K8s manifest validation
│   │   └── policy.go                # Policy-as-code validation (Phase 15)
│   ├── scaffold/
│   │   ├── project.go               # Scaffold new project structure
│   │   ├── release.go               # Scaffold new release/pre-release
│   │   ├── module.go                # Scaffold new module from template
│   │   └── templates/               # Embedded Go templates for scaffolding
│   │       ├── factory_seed.k.tmpl
│   │       ├── render.k.tmpl
│   │       └── kcl.mod.tmpl
│   ├── output/
│   │   ├── writer.go                # Write render output to disk
│   │   ├── helm.go                  # Copy static Helm templates
│   │   └── kustomize.go             # Write Kustomize overlay structure
│   └── config/
│       └── koncept.go               # Parse koncept.yaml project config
├── go.mod
├── go.sum
└── Makefile                          # Cross-platform build targets
```

### 5.5 koncept.yaml — Project Configuration

Each project root can have a `koncept.yaml` that configures the Go CLI:

```yaml
# koncept.yaml — project-level configuration
apiVersion: koncept.bluesolution.es/v1
kind: ProjectConfig

metadata:
  name: erp-back
  version: "1.0.0"

spec:
  # Framework location (default: auto-discover from kcl.mod dependencies)
  frameworkPath: "../../framework"

  # Default output format when running `koncept render` without arguments
  defaultOutput: argocd

  # Factory pattern configuration
  factory:
    seedFile: factory_seed.k       # Default: factory_seed.k
    renderFile: render.k           # Default: render.k

  # Validation pipeline (Phase 12)
  validation:
    kubeconform:
      enabled: true
      kubernetesVersion: "1.31.0"
      strict: true
      additionalSchemas: []        # Extra CRD schemas
    policy:
      enabled: false               # Phase 15
      engine: "conftest"           # "conftest" (OPA) | "kyverno-cli"
      policyPath: "policies/"

  # Output settings
  output:
    defaultDir: "output"
    helmTemplatesDir: "framework/templates/helm"

  # Backstage integration
  backstage:
    owner: "platform-team"
    lifecycle: "production"
    techdocsRef: "dir:."
```

### 5.6 KCL Go SDK Integration Pattern

```go
package factory

import (
    "fmt"
    "path/filepath"

    kcl "kcl-lang.io/kcl-go"
)

// Render executes a KCL render with the given output format
func Render(factoryDir string, outputFormat string) (*kcl.KCLResultList, error) {
    renderFile := filepath.Join(factoryDir, "render.k")

    result, err := kcl.RunFiles([]string{renderFile},
        kcl.WithWorkDir(factoryDir),
        kcl.WithOptions("output="+outputFormat),
        kcl.WithSortKeys(true),
    )
    if err != nil {
        return nil, fmt.Errorf("KCL render failed: %w", err)
    }
    return result, nil
}

// Validate compiles factory_seed.k without rendering
func Validate(factoryDir string) error {
    seedFile := filepath.Join(factoryDir, "factory_seed.k")
    _, err := kcl.RunFiles([]string{seedFile},
        kcl.WithWorkDir(factoryDir),
    )
    return err
}

// Test runs the KCL test suite
func Test(testDir string) (*kcl.TestResult, error) {
    result, err := kcl.Test(&kcl.TestOptions{
        PkgList: []string{testDir + "/..."},
    })
    return &result, err
}
```

### 5.7 New Commands (Go CLI Only)

| Command | Description | Implementation |
|---|---|---|
| `koncept diff` | Show YAML diff between current render and last committed output | `kcl.RunFiles()` → YAML → `diff` against `output/` |
| `koncept status` | Show factory state, output formats configured, last render timestamp | Parse `koncept.yaml` + check `output/` metadata |
| `koncept test` | Run `kcl test ./...` on framework or project tests | `kcl.Test()` with formatted output |
| `koncept fmt` | Format all KCL files in the project | `kcl.FormatPath()` recursively |
| `koncept lint` | Lint KCL files for common issues | `kcl.LintPath()` + custom rules |
| `koncept deps` | Show dependency tree from `kcl.mod` | `kcl.ListDepFiles()` + tree visualization |

### 5.8 Distribution Strategy

| Channel | Method | Users |
|---|---|---|
| **GitHub Releases** | Cross-compiled binaries (linux/amd64, darwin/arm64, windows) | All |
| **Homebrew** | `brew install koncept` | macOS/Linux |
| **Go install** | `go install github.com/org/koncept/cmd/koncept@latest` | Go developers |
| **Container image** | `ghcr.io/org/koncept:v1.0.0` (for CI/CD) | Pipelines |

### 5.9 Migration Path (Nushell → Go)

1. **Coexistence phase**: Both `platform_cli/koncept` (Nushell) and `cmd/koncept/` (Go) work side by side
2. **Feature parity**: Go CLI reaches feature parity with Nushell CLI
3. **Deprecation**: Mark Nushell CLI as "legacy" in docs; new features only in Go CLI
4. **Removal**: Remove Nushell CLI from `platform_cli/` after 2 release cycles

### 5.10 Deliverables

- [x] `cmd/koncept/` Go project with `go.mod`
- [x] `koncept render <format>` — all 9 output formats via `kcl.RunFiles()`
- [x] `koncept validate` — KCL compilation + kubeconform validation
- [x] `koncept init` — scaffold project/release/module
- [x] `koncept publish` — OCI push via KCL Go SDK
- [x] `koncept diff` — YAML diff against committed output
- [x] `koncept test` — run KCL tests with formatted output
- [x] `koncept fmt` — format KCL files
- [x] `koncept.yaml` config file support
- [x] GitHub Actions workflow: build + test + release binaries
- [ ] Homebrew formula
- [ ] Container image published to GHCR

---

## 6. Phase 12 — CI/CD Integration & Validation Pipeline

**Owner**: Platform Engineer (Low-Level)
**CNCF Target**: L2 → L3 (Operations: Centrally enabled)
**Priority**: P0 — Required for production confidence

### 6.1 Problem Statement

Currently, validation is manual: run `koncept validate`, visually inspect output, run `kubeconform`. There is no automated pipeline to catch regressions, enforce policies, or validate configuration changes in PRs.

### 6.2 Validation Pipeline Architecture

```
Developer pushes KCL change
           │
           ▼
┌──────────────────────────────────────────────────────┐
│                   CI Pipeline                         │
│                                                       │
│  Step 1: kcl test ./...                              │
│  ├─ Run 287+ unit tests                              │
│  └─ FAIL → Block PR                                  │
│                                                       │
│  Step 2: koncept validate                             │
│  ├─ Compile all factory_seed.k files                 │
│  └─ FAIL → Block PR                                  │
│                                                       │
│  Step 3: koncept render argocd                        │
│  ├─ Render manifests for all projects/environments   │
│  └─ FAIL → Block PR                                  │
│                                                       │
│  Step 4: kubeconform --strict                         │
│  ├─ Validate all rendered manifests against K8s 1.31 │
│  ├─ Include CRD schemas for operators                │
│  └─ FAIL → Block PR                                  │
│                                                       │
│  Step 5: Policy check (Phase 15)                      │
│  ├─ OPA/Kyverno policy evaluation                    │
│  └─ FAIL → Block PR                                  │
│                                                       │
│  Step 6: Golden file diff                             │
│  ├─ Compare rendered output against committed golden │
│  │   files to detect unintended drift                │
│  └─ WARN → Annotate PR with diff                     │
│                                                       │
│  Step 7: Helm lint + template                         │
│  ├─ For helmfile output: lint charts, template dry-   │
│  │   run, validate produced YAML                     │
│  └─ FAIL → Block PR                                  │
│                                                       │
│  ALL PASS → PR ready for review                       │
└──────────────────────────────────────────────────────┘
```

### 6.3 GitHub Actions Workflow

```yaml
# .github/workflows/validate.yml
name: Validate KCL Configurations
on:
  pull_request:
    paths:
      - 'framework/**'
      - 'projects/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install KCL
        uses: kcl-lang/setup-kcl@v0.2.1
        with:
          kcl-version: "0.10.0"

      - name: Run KCL tests
        run: cd framework && kcl test ./...

      - name: Validate all factories
        run: |
          for factory in $(find projects -name "factory_seed.k" -path "*/factory/*"); do
            dir=$(dirname "$factory")
            echo "Validating $dir..."
            kcl run "$dir/factory_seed.k" --output json > /dev/null
          done

      - name: Render and validate manifests
        run: |
          for factory in $(find projects -name "render.k" -path "*/factory/*"); do
            dir=$(dirname "$factory")
            echo "Rendering $dir..."
            kcl run "$factory" -D output=yaml | kubeconform -strict -summary \
              -kubernetes-version 1.31.0 \
              -schema-location default \
              -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
          done

      - name: Helm lint (if helmfile output exists)
        run: |
          for chart in $(find projects -name "Chart.yaml" -path "*/output/*"); do
            dir=$(dirname "$chart")
            echo "Linting $dir..."
            helm lint "$dir"
            helm template test "$dir" | kubeconform -strict -summary
          done
```

### 6.4 Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: kcl-fmt
        name: Format KCL files
        entry: kcl fmt
        language: system
        files: '\.k$'
        exclude: 'kcl\.mod'

      - id: kcl-lint
        name: Lint KCL files
        entry: kcl lint
        language: system
        files: '\.k$'
        exclude: 'kcl\.mod|tests/'

      - id: kcl-test
        name: Run KCL tests
        entry: bash -c 'cd framework && kcl test ./...'
        language: system
        pass_filenames: false
        files: 'framework/.*\.k$'
```

### 6.5 Golden File Testing

For each project/environment, maintain "golden" output files that represent the expected correct render. Changes to golden files require explicit approval:

```
projects/erp_back/pre_releases/manifests/dev/
├── factory/
│   ├── factory_seed.k
│   └── render.k
├── output/                          # Rendered output (gitignored)
└── golden/                          # Expected output (committed)
    ├── argocd/
    │   └── manifests.yaml           # Expected YAML output
    ├── helmfile/
    │   └── helmfile.yaml            # Expected helmfile
    └── backstage/
        └── catalog-info.yaml        # Expected catalog entities
```

CI validates: `koncept render argocd | diff - golden/argocd/manifests.yaml`

### 6.6 Deliverables

- [x] `.github/workflows/validate.yml` — Full CI pipeline (7 jobs: kcl-test, validate-factories, render-and-validate, golden-file-check, helm-lint, go-cli-build)
- [x] `.pre-commit-config.yaml` — Pre-commit hooks (kcl-fmt, kcl-lint, kcl-test)
- [ ] Golden file structure for erp_back (dev, stg, prod) — requires working KCL render
- [x] `koncept golden update` command — regenerate golden files after intentional changes
- [ ] CRD schema catalog for kubeconform (CNPG, Strimzi, etc.)
- [x] CI badge in README.md

---

## 7. Phase 13 — Framework Package Registry & Versioning

**Owner**: Platform Engineer (Low-Level)
**CNCF Target**: L3 (Operations: Centrally enabled)
**Priority**: P1

### 7.1 Problem Statement

Currently, all projects depend on the framework via local paths in `kcl.mod`:

```toml
[dependencies]
framework = { path = "../../framework" }
```

This means: every project must live in the same monorepo, no version isolation, and upgrading the framework is all-or-nothing.

### 7.2 OCI Registry Strategy

Publish the framework as versioned OCI artifacts:

```
ghcr.io/org/idp-concept/framework:1.0.0
ghcr.io/org/idp-concept/framework:1.1.0
ghcr.io/org/idp-concept/framework:2.0.0
```

Projects consume via version pins:

```toml
# kcl.mod — version-pinned consumption
[dependencies]
framework = "1.0.0"           # From OCI registry
# OR
framework = { git = "https://github.com/org/idp-concept.git", tag = "framework-v1.0.0" }
```

### 7.3 Semantic Versioning Contract

| Change Type | Version Bump | Example |
|---|---|---|
| New builder/template/procedure | Minor (1.x.0) | Add `framework/templates/elasticache.k` |
| New field in schema (optional) | Minor (1.x.0) | Add `topologySpreadConstraints?: [any]` to `DeploymentSpec` |
| Bug fix in builder output | Patch (1.0.x) | Fix label selector mismatch |
| Remove/rename field | Major (x.0.0) | Rename `serviceType` to `type` in `ServiceSpec` |
| Change schema inheritance | Major (x.0.0) | Restructure `Component` schema hierarchy |
| Change render contract | Major (x.0.0) | Modify FactorySeed exported variables |

### 7.4 Compatibility Metadata

Inspired by k0rdent's TemplateChain pattern — add compatibility metadata to stacks:

```kcl
schema StackMetadata:
    """Declares framework compatibility for a stack version."""
    name: str
    version: str
    frameworkVersion: str              # Minimum framework version required
    kclVersion: str = "0.10.0"        # KCL language version
    k8sVersion: str = "1.31.0"        # Target Kubernetes version
    upgradeFrom?: [str]               # Stack versions this can upgrade from
    deprecatedBy?: str                 # If non-empty, points to successor version

    check:
        frameworkVersion, "frameworkVersion is required"
```

### 7.5 Multi-Repo Support

With registry-based consumption, teams can have their own repos:

```
team-alpha-repo/
├── kcl.mod                          # depends on framework = "1.0.0"
├── modules/
├── stacks/
├── tenants/
├── sites/
└── pre_releases/

idp-concept (framework repo)/
├── framework/                       # published as OCI
└── .github/workflows/publish.yml    # Auto-publish on tag
```

### 7.6 Release Pipeline

```yaml
# .github/workflows/publish-framework.yml
name: Publish Framework
on:
  push:
    tags:
      - 'framework-v*'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: kcl-lang/setup-kcl@v0.2.1

      - name: Run tests
        run: cd framework && kcl test ./...

      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/framework-v}" >> $GITHUB_OUTPUT

      - name: Publish to OCI
        run: |
          cd framework
          kcl mod push oci://ghcr.io/${{ github.repository }}/framework \
            --tag ${{ steps.version.outputs.VERSION }}
```

### 7.7 Deliverables

- [ ] Semantic versioning policy documented in `CONTRIBUTING.md`
- [ ] `StackMetadata` schema with compatibility fields
- [ ] GitHub Actions workflow to publish framework on tag
- [ ] Migration guide: local path → OCI registry consumption
- [ ] Changelog generation (conventional commits → CHANGELOG.md)
- [ ] `koncept deps` command — visualize dependency tree

---

## 8. Phase 14 — Configuration Extensibility & Plugin Architecture

**Owner**: Platform Engineer (Low-Level)
**CNCF Target**: L3 → L4 (Enabled ecosystem)
**Priority**: P1

### 8.1 Problem Statement

Currently, adding a new output format, builder, or template **requires modifying framework internals** (editing `render.k`, adding test files, updating the CLI). Teams cannot extend the platform without contributing to the core repository.

### 8.2 Extension Points

#### 8.2.1 Custom Output Procedures (Plugins)

Allow external packages to register new output formats without modifying `render.k`:

```kcl
# In an external package: my_org/fleet_output/fleet.k
import framework.models.manifests.renderstack as rs

generate_fleet = lambda stack: rs.RenderStack, project_name: str, git_repo_url: str -> [any] {
    _gitrepo = {
        apiVersion = "fleet.cattle.io/v1alpha1"
        kind = "GitRepo"
        metadata.name = project_name
        spec = {
            repo = git_repo_url
            paths = [m.name for m in stack.modules]
        }
    }
    [_gitrepo]
}
```

```kcl
# In project's render.k — register the custom output
import my_org.fleet_output.fleet as fleet_plugin

if _output == "fleet":
    _manifests = fleet_plugin.generate_fleet(_stack, _project_name, _git_repo_url)
```

#### 8.2.2 Custom Builder Registration

Allow projects to register custom builders that templates can use:

```kcl
# my_org/custom_builders/istio_virtual_service.k
schema VirtualServiceSpec:
    name: str
    namespace: str
    hosts: [str]
    httpRoutes: [any]

    check:
        len(hosts) > 0, "at least one host is required"

build_virtual_service = lambda spec: VirtualServiceSpec -> any {
    {
        apiVersion = "networking.istio.io/v1"
        kind = "VirtualService"
        metadata = { name = spec.name, namespace = spec.namespace }
        spec = { hosts = spec.hosts, http = spec.httpRoutes }
    }
}
```

#### 8.2.3 Custom Template Mixins

Allow templates to compose behavior from multiple sources:

```kcl
# Mixin that adds Istio sidecar injection to any component
schema IstioMixin:
    istioEnabled: bool = True
    istioVersion?: str
    _istio_annotations = {
        "sidecar.istio.io/inject" = "true" if istioEnabled else "false"
    } | ({"sidecar.istio.io/proxyImage" = "docker.io/istio/proxyv2:${istioVersion}"} if istioVersion else {})
```

### 8.3 Framework Extension Registry

A `koncept.yaml` section for declaring extensions:

```yaml
spec:
  extensions:
    outputFormats:
      fleet:
        package: "my_org.fleet_output.fleet"
        function: "generate_fleet"
    builders:
      virtualService:
        package: "my_org.custom_builders.istio_virtual_service"
    policies:
      - package: "my_org.policies.security"
      - package: "my_org.policies.naming_conventions"
```

### 8.4 Deliverables

- [ ] Extension point design document
- [ ] `koncept.yaml` extension registry schema
- [ ] Example external output format plugin (Fleet)
- [ ] Example custom builder plugin (Istio VirtualService)
- [ ] Example template mixin pattern
- [ ] Go CLI support for discovering and loading extensions
- [ ] Documentation: "How to create a koncept plugin"

---

## 9. Phase 15 — Policy-as-Code & Governance

**Owner**: Platform Engineer (Low-Level)
**CNCF Target**: L3 → L4 (Governance and compliance)
**Priority**: P1

### 9.1 Policy Layers

```
                              Strictness
                        ─────────────────────▶

  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
  │  Layer 1: KCL    │  │  Layer 2: Local   │  │  Layer 3: Cluster│
  │  check: blocks   │  │  Policy Engine    │  │  Admission Ctrl  │
  │  (compile time)  │  │  (pre-deploy)     │  │  (runtime)       │
  │                  │  │                  │  │                  │
  │  Schema val-     │  │  OPA Rego /       │  │  Kyverno /       │
  │  idation,        │  │  Kyverno policies │  │  Gatekeeper      │
  │  type checking   │  │  on rendered YAML │  │  live in cluster │
  └──────────────────┘  └──────────────────┘  └──────────────────┘
          ▲                      ▲                      ▲
       Already               This phase             Out of scope
       done ✅               (CI gate)              (cluster ops)
```

### 9.2 KCL-Native Policy Catalog

```kcl
# framework/policies/security.k

validate_no_privileged = lambda manifest: any -> bool {
    if manifest.kind == "Deployment":
        _containers = manifest.spec?.template?.spec?.containers or []
        all c in _containers {
            not c.securityContext?.privileged
        }
    else:
        True
}

validate_resource_limits = lambda manifest: any -> bool {
    if manifest.kind == "Deployment":
        _containers = manifest.spec?.template?.spec?.containers or []
        all c in _containers {
            c.resources?.limits?.memory and c.resources?.limits?.cpu
        }
    else:
        True
}

validate_image_tag_not_latest = lambda manifest: any -> bool {
    if manifest.kind == "Deployment":
        _containers = manifest.spec?.template?.spec?.containers or []
        all c in _containers {
            ":" in c.image and not c.image.endswith(":latest")
        }
    else:
        True
}
```

### 9.3 External Policy Engine Integration (OPA/Conftest)

```rego
# policies/security/no_privileged.rego
package main

deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.privileged == true
    msg := sprintf("Privileged container not allowed: %s", [container.name])
}

deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits.memory
    msg := sprintf("Memory limit required for container: %s", [container.name])
}
```

### 9.4 Built-in Policy Catalog

| Policy | Severity | Rule |
|---|---|---|
| No privileged containers | DENY | `securityContext.privileged != true` |
| Resource limits required | DENY | All containers must have `resources.limits` |
| No latest tags | DENY | Image tags must be pinned, not `:latest` |
| Naming conventions | DENY | Kebab-case names, 3-63 chars |
| Label requirements | WARN | `app.kubernetes.io/name`, `app.kubernetes.io/managed-by` |
| Replica minimum | WARN | Production deployments should have `replicas >= 2` |
| Network policy present | WARN | Every namespace should have a default deny NetworkPolicy |
| PDB present | WARN | Deployments with `replicas >= 2` should have a PDB |
| Secret references only | DENY | No `env[].value` containing passwords; use `valueFrom.secretKeyRef` |

### 9.5 koncept.yaml Policy Configuration

```yaml
spec:
  validation:
    policy:
      enabled: true
      engine: "conftest"
      policyPath: "policies/"
      severity:
        deny: error                     # Block CI
        warn: warning                   # Annotate PR, don't block
      exclusions:
        - path: "test_to_delete/**"
        - policy: "naming/conventions"
          path: "projects/video_streaming/**"
```

### 9.6 Deliverables

- [ ] `framework/policies/` directory with KCL-native validation lambdas
- [ ] `policies/` directory with OPA Rego policies
- [ ] `koncept validate --policy` flag
- [ ] CI pipeline step for policy checks
- [ ] `koncept.yaml` policy configuration schema
- [ ] Built-in policy catalog (9+ policies)
- [ ] Documentation: "Writing custom policies"

---

## 10. Phase 16 — Fleet Output & Multi-Cluster Strategy

**Owner**: Platform Engineer (Low-Level)
**CNCF Target**: L3 → L4 (Scale: multi-cluster operations)
**Priority**: P2

### 10.1 Context

> Based on analysis in [PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md](./PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md) §3.

Rancher Fleet (1,700+ stars, CNCF) provides GitOps at scale across many clusters. Adding Fleet as a 10th output format enables idp-concept to serve as the **configuration source** for Fleet-managed multi-cluster deployments.

### 10.2 Fleet Output Procedure

```kcl
# framework/procedures/kcl_to_fleet.k

schema FleetConfig:
    namespace: str
    dependsOn?: [FleetDependency]
    helm?: FleetHelmConfig
    targetCustomizations?: [FleetTarget]

schema FleetTarget:
    name?: str
    clusterSelector?: {str:str}          # Label selector for target clusters
    helm?: {str:any}                     # Helm value overrides per cluster group

generate_fleet_from_stack = lambda stack: rs.RenderStack, project_name: str -> {str:any} {
    # Generate fleet.yaml per component with dependency ordering
    # and per-cluster customizations from site configurations
}
```

### 10.3 Multi-Cluster Site Configuration

Extend the existing site model:

```kcl
schema MultiClusterSite(site_model.Site):
    clusters: [ClusterTarget]

schema ClusterTarget:
    name: str
    labels: {str:str}                    # Cluster labels for Fleet targeting
    valueOverrides?: {str:any}           # Per-cluster config overrides
```

### 10.4 ArgoCD ApplicationSet for Multi-Cluster

Alternative multi-cluster approach using ArgoCD:

```kcl
generate_application_set = lambda stack: rs.RenderStack, clusters: [ClusterTarget] -> any {
    {
        apiVersion = "argoproj.io/v1alpha1"
        kind = "ApplicationSet"
        metadata.name = stack.name
        spec = {
            goTemplate = True
            generators = [{
                clusters = {
                    selector.matchLabels = { tier = "production" }
                }
            }]
            template = { /* ... template for each matched cluster */ }
        }
    }
}
```

### 10.5 Deliverables

- [ ] `framework/procedures/kcl_to_fleet.k` — Fleet output procedure
- [ ] `framework/tests/procedures/fleet_test.k` — Tests
- [ ] `render.k` updated with `-D output=fleet` branch
- [ ] `MultiClusterSite` schema extension
- [ ] ArgoCD ApplicationSet generation
- [ ] CLI: `koncept render fleet`

---

## 11. Phase 17 — Score Spec Input Format

**Owner**: Platform Engineer (Low-Level)
**CNCF Target**: L4 (Ecosystem: accept standard input formats)
**Priority**: P3

### 11.1 Context

[Score](https://score.dev/) (8,000+ stars, CNCF) defines a platform-agnostic workload specification. Supporting Score as an **input format** lets developers describe workloads without KCL knowledge.

### 11.2 Score Resource Type Mapping

| Score `type` | KCL Template | Output |
|---|---|---|
| `postgres` | `PostgreSQLClusterModule` | CloudNativePG Cluster |
| `redis` | `RedisModule` | OT Redis Operator |
| `mongodb` | `MongoDBCommunityModule` | MCK MongoDBCommunity |
| `kafka-topic` | `KafkaClusterModule` | Strimzi KafkaTopic |
| `rabbitmq` | `RabbitMQClusterModule` | RabbitMQ Cluster |
| `s3` | `MinIOHelmSpec` | MinIO Bitnami Helm |
| `environment` | (configmap/secret) | ConfigMap or Secret |

### 11.3 Deliverables

- [ ] `koncept import score <file>` — Parse score.yaml → generate KCL module
- [ ] Score resource type → KCL template mapping catalog
- [ ] Tests for Score-to-KCL translation
- [ ] Documentation: "Using Score with idp-concept"

---

## 12. Phase 18 — Observability-Driven Platform

**Owner**: Platform Engineer (Low-Level)
**CNCF Target**: L3 (Measurement: Insights)
**Priority**: P2

### 12.1 Problem Statement

The CNCF Maturity Model requires **measurement** at Level 3. Currently, the platform has zero observability into its own usage.

### 12.2 Platform Telemetry

Instrument the Go CLI to emit OpenTelemetry metrics:

| Metric | Type | Attributes |
|---|---|---|
| `koncept.render.duration` | Histogram | `output.format`, `project.name` |
| `koncept.render.count` | Counter | `output.format`, `project.name` |
| `koncept.render.errors` | Counter | `error.type`, `project.name` |
| `koncept.validate.count` | Counter | `project.name` |
| `koncept.validate.errors` | Counter | `error.type` |
| `koncept.test.count` | Counter | `project.name` |
| `koncept.test.failures` | Counter | `project.name` |
| `koncept.scaffold.count` | Counter | `template.name` |

### 12.3 Configuration Drift Detection

```
koncept drift check
├─ Render current configuration
├─ Compare against last committed output (golden files)
├─ Compare against live cluster state (if k8s access available)
└─ Report:
   ├─ Configuration drift (KCL source changed, output not re-rendered)
   ├─ Deployment drift (rendered output differs from live state)
   └─ Dependency drift (framework version changed, output not updated)
```

### 12.4 Privacy & Opt-in

- Telemetry is **opt-in** via `koncept.yaml`: `spec.telemetry.enabled: true`
- No PII collected — only aggregate metrics
- Data stays within the organization's own OTLP collector
- CLI works fully offline with telemetry disabled

### 12.5 Deliverables

- [ ] OpenTelemetry instrumentation in Go CLI
- [ ] `koncept drift check` command
- [ ] Grafana dashboard templates for platform metrics
- [ ] `koncept.yaml` telemetry configuration
- [ ] Privacy policy and opt-in documentation

---

## 13. Strategic Roadmap Overview

### Phase Priority Matrix

| Phase | Priority | Owner | CNCF Target | Dependencies |
|---|---|---|---|---|
| **11: Go CLI Hybrid** | P0 | Low-Level PE | L3 Interfaces | None |
| **12: CI/CD Pipeline** | P0 | Low-Level PE | L3 Operations | None (can start with Nushell) |
| **13: Package Registry** | P1 | Low-Level PE | L3 Operations | Phase 11 (publish command) |
| **14: Plugin Architecture** | P1 | Low-Level PE | L4 Ecosystem | Phase 13 (registry for plugins) |
| **15: Policy-as-Code** | P1 | Low-Level PE | L3-L4 Governance | Phase 12 (CI integration) |
| **16: Fleet + Multi-Cluster** | P2 | Low-Level PE | L4 Scale | Phase 14 (extension point) |
| **17: Score Input** | P3 | Low-Level PE | L4 Ecosystem | Phase 11 (Go CLI for parser) |
| **18: Observability** | P2 | Low-Level PE | L3 Measurement | Phase 11 (Go CLI for metrics) |

### Execution Order (Recommended)

```
                     ┌───────────────────────────────────────────────────────────┐
                     │                   Parallel Workstreams                     │
                     ├───────────────────────────────────────────────────────────┤
                     │                                                           │
 Stream A (Tooling)  │  Phase 11 ──▶ Phase 13 ──▶ Phase 14 ──▶ Phase 17        │
                     │  Go CLI       Registry     Plugins      Score Input       │
                     │                                                           │
 Stream B (Quality)  │  Phase 12 ──▶ Phase 15 ──▶ Phase 18                      │
                     │  CI/CD        Policy       Observability                  │
                     │                                                           │
 Stream C (Scale)    │              Phase 16                                     │
                     │              Fleet + Multi-Cluster                        │
                     │              (can start after Phase 14)                   │
                     └───────────────────────────────────────────────────────────┘
```

Streams A and B can be executed **in parallel** since they have no cross-dependencies until Phase 14.

### CNCF Maturity Progression

```
Current State (Phases 1-10 complete)
├── Investment: L2-L3 (dedicated tooling, product-like development)
├── Adoption: L2 (CLI requires factory knowledge)
├── Interfaces: L2-L3 (CLI + Backstage designed)
├── Operations: L2 (manual factory creation)
└── Measurement: L1 (no metrics)

After Phases 11-12 (Go CLI + CI/CD)
├── Investment: L3 (distributable product)
├── Adoption: L3 (zero-dependency CLI, validated pipelines)
├── Interfaces: L3 (self-service single binary)
├── Operations: L3 (automated validation, golden files)
└── Measurement: L2 (CI success/failure tracking)

After Phases 13-15 (Registry + Plugins + Policy)
├── Investment: L3-L4 (ecosystem enablement)
├── Adoption: L3 (teams consume published packages)
├── Interfaces: L3-L4 (extensible via plugins)
├── Operations: L3 (centrally enabled, policy gates)
└── Measurement: L2-L3 (policy violation tracking)

After Phases 16-18 (Fleet + Score + Observability)
├── Investment: L4 (enabled ecosystem)
├── Adoption: L3-L4 (standard input formats, multi-repo)
├── Interfaces: L4 (integrated services, multiple input/output)
├── Operations: L4 (managed services, drift detection)
└── Measurement: L3 (insights-driven decisions)
```

---

## 14. Architecture Decision Records

### ADR-001: Keep KCL, Strengthen Go Tooling

**Status**: Accepted
**Context**: Most IDP tools use Go. Should we migrate from KCL to Go?
**Decision**: Keep KCL for configuration; use Go only for CLI/tooling via KCL Go SDK.
**Rationale**: See [PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md §4](./PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md).
**Consequences**: Must maintain expertise in both KCL and Go. Benefit: best-of-both-worlds.

### ADR-002: Strategy B for Helm Templates

**Status**: Accepted
**Context**: Should KCL generate Go template strings (Strategy A) or only values.yaml with static templates (Strategy B)?
**Decision**: Strategy B — KCL generates values.yaml; templates are static Go templates.
**Rationale**: Simpler KCL code, standard Helm workflow, templates reviewable by Helm users.

### ADR-003: Conftest (OPA) for Policy-as-Code

**Status**: Proposed (Phase 15)
**Context**: Which policy engine to use for pre-deploy validation?
**Decision**: Conftest (OPA Rego) for CI gate; Kyverno for cluster admission.
**Rationale**: OPA is CNCF Graduated (most mature), Conftest works client-side, Rego is well-documented.

### ADR-004: OCI Registry for Framework Distribution

**Status**: Proposed (Phase 13)
**Context**: How to distribute the framework to multi-repo consumers?
**Decision**: Publish framework as OCI artifacts to GHCR.
**Rationale**: KCL natively supports `kcl mod push` to OCI. OCI is the standard. Version pinning via tags.

### ADR-005: OpenTelemetry for Platform Metrics

**Status**: Proposed (Phase 18)
**Context**: How to measure platform adoption and performance?
**Decision**: Instrument Go CLI with OpenTelemetry, export to OTLP collector.
**Rationale**: OpenTelemetry is CNCF Graduated, vendor-agnostic, already in our stack (Phase 6 template). Opt-in.

---

## 15. User Workflow Guides

> **→ Standalone: [USER_WORKFLOW_GUIDES.md](./USER_WORKFLOW_GUIDES.md)**

---

## 16. Work Matrix by User Profile

> **→ Standalone: [WORK_MATRIX.md](./WORK_MATRIX.md)**

### Extended Work Matrix (Phases 11–18)

#### Developer

| Phase | Task | Input | Output |
|---|---|---|---|
| 11 | Use `koncept` Go binary — zero install dependencies | Download binary | All existing commands work |
| 11 | Use `koncept diff` to see what changed | CLI command | YAML diff output |
| 12 | CI pipeline validates PRs automatically | Push to Git | Green/red pipeline status |
| 17 | Write `score.yaml` instead of KCL (optional) | Score spec | Auto-generated KCL modules |

#### Platform Engineer — High-Level

| Phase | Task | Input | Output |
|---|---|---|---|
| 13 | Consume framework via version pin | `kcl.mod` version | Isolated, versioned dependencies |
| 14 | Register custom output formats | `koncept.yaml` extensions | New render targets |
| 16 | Define multi-cluster sites | `MultiClusterSite` schema | Per-cluster deployment configs |

#### Platform Engineer — Low-Level

| Phase | Task | Input | Output |
|---|---|---|---|
| 11 | Build Go CLI with KCL Go SDK | Go code | Single distributable binary |
| 12 | Configure CI/CD validation pipeline | GitHub Actions | Automated quality gates |
| 13 | Publish framework to OCI registry | `kcl mod push` | Versioned framework packages |
| 14 | Design plugin architecture | KCL extension points | Extensible framework |
| 15 | Write OPA policies | Rego files | Governance rules |
| 16 | Implement Fleet output procedure | KCL procedure | 10th output format |
| 17 | Implement Score-to-KCL translation | Go parser | Score input support |
| 18 | Instrument Go CLI with OpenTelemetry | Go metrics | Platform observability |

---

## 17. Migration Guide: video_streaming → template pattern

> **→ Standalone: [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)**

### Priority Order

| Module | Type | Template Target | Estimated Effort |
|---|---|---|---|
| `kafka_video_consumer_mongodb_python` | APPLICATION | `WebAppModule` | 1-2 hours |
| `mongodb_single_instance` | INFRASTRUCTURE | `MongoDBCommunityModule` | 1 hour |
| `kafka_strimzi` | CRD | `KafkaClusterModule` | 1 hour |

---

## Appendix A — Completed Implementation Progress

### Testing Infrastructure

**287 unit tests** across 40+ test files, all passing via `kcl test ./...`.

<details>
<summary>Full test matrix (click to expand)</summary>

| Layer | Test File | Tests | Status |
|---|---|---|---|
| **Builders** | `tests/builders/deployment_test.k` | 23 | PASS |
| **Builders** | `tests/builders/service_test.k` | 9 | PASS |
| **Builders** | `tests/builders/configmap_test.k` | 2 | PASS |
| **Builders** | `tests/builders/storage_test.k` | 5 | PASS |
| **Builders** | `tests/builders/service_account_test.k` | 2 | PASS |
| **Builders** | `tests/builders/leader_test.k` | 3 | PASS |
| **Builders** | `tests/builders/network_policy_test.k` | 4 | PASS |
| **Builders** | `tests/builders/pdb_test.k` | 4 | PASS |
| **Models** | `tests/models/configurations_test.k` | 4 | PASS |
| **Models** | `tests/models/configurations_git_test.k` | 4 | PASS |
| **Models** | `tests/models/modules/k8snamespace_test.k` | 4 | PASS |
| **Models** | `tests/models/modules/common_test.k` | 7 | PASS |
| **Models** | `tests/models/modules/secrets_test.k` | 6 | PASS |
| **Models** | `tests/models/modules/thirdparty_helm_test.k` | 5 | PASS |
| **Assembly** | `tests/assembly/helpers_test.k` | 3 | PASS |
| **Procedures** | `tests/procedures/helper_test.k` | 3 | PASS |
| **Procedures** | `tests/procedures/kusion_test.k` | 8 | PASS |
| **Procedures** | `tests/procedures/yaml_test.k` | 5 | PASS |
| **Procedures** | `tests/procedures/helm_values_test.k` | 5 | PASS |
| **Procedures** | `tests/procedures/helmfile_test.k` | 5 | PASS |
| **Procedures** | `tests/procedures/helm_test.k` | 5 | PASS |
| **Procedures** | `tests/procedures/argocd_test.k` | 5 | PASS |
| **Procedures** | `tests/procedures/kustomize_test.k` | 8 | PASS |
| **Procedures** | `tests/procedures/timoni_test.k` | 11 | PASS |
| **Procedures** | `tests/procedures/crossplane_test.k` | 25 | PASS |
| **Procedures** | `tests/procedures/backstage_test.k` | 14 | PASS |
| **Templates** | `tests/templates/webapp_test.k` | 8 | PASS |
| **Templates** | `tests/templates/database_test.k` | 8 | PASS |
| **Templates** | `tests/templates/postgresql_test.k` | 10 | PASS |
| **Templates** | `tests/templates/mongodb_test.k` | 6 | PASS |
| **Templates** | `tests/templates/rabbitmq_test.k` | 7 | PASS |
| **Templates** | `tests/templates/redis_test.k` | 6 | PASS |
| **Templates** | `tests/templates/keycloak_test.k` | 5 | PASS |
| **Templates** | `tests/templates/opensearch_test.k` | 8 | PASS |
| **Templates** | `tests/templates/vault_test.k` | 7 | PASS |
| **Templates** | `tests/templates/questdb_test.k` | 4 | PASS |
| **Templates** | `tests/templates/minio_test.k` | 8 | PASS |
| **Templates** | `tests/templates/opentelemetry_test.k` | 13 | PASS |
| **Templates** | `tests/templates/observability_test.k` | 8 | PASS |
| **Templates** | `tests/templates/backstage_test.k` | 5 | PASS |

</details>

#### Known Limitation: `kcl test` + Schema Instance Bug

Template schemas cannot be directly instantiated in `kcl test` lambdas due to a KCL bug with auto-computed `instance` fields. **Workaround**: Template tests validate individual builder outputs. Full integration validated via `kcl run` + `kubeconform`.

### Phase Completion Summary

| Phase | Items | Status |
|---|---|---|
| 1 — Foundation Hardening | 5 | ✅ |
| 2 — Helmfile Parameterization | 11 | ✅ |
| 3 — KCL Code Quality | 4 | ✅ |
| 4 — Developer Experience | 7 | ✅ |
| 5 — Advanced Platform Features | 9 | ✅ |
| Architecture Restructuring | 6 | ✅ |
| 6 — Production Infrastructure | 18 | ✅ |
| 7 — Multi-Format Output | 13 | ✅ |
| 8 — Backstage Catalog | 10 | ✅ |
| 9 — Plugin Integration | 6 | ✅ |
| 10 — Self-Service Scaffolder | 10 | ✅ |

### Kubeconform Validation

| Project | Manifests | Valid | Invalid |
|---|---|---|---|
| erp_back (dev) | 8 | 8 | 0 |
| erp_back (stg) | 8 | 8 | 0 |
| erp_back (release v1.0.0) | 8 | 8 | 0 |
| video_streaming (dev) | 5 | 5 | 0 |

---

## Appendix B — Reference Patterns & Competitive Positioning

### Competitive Positioning

| Platform | Language | Scope | Our Advantage |
|---|---|---|---|
| **k0rdent** | Go | Multi-cluster lifecycle | KCL schemas > JSON Schema; no cluster-side controller |
| **Fleet** | Go | Multi-cluster GitOps | Multiple formats from one source; Fleet converts all to Helm |
| **Kusion** | Go + KCL | Platform orchestrator | Most aligned. We focus on multi-format output |
| **Crossplane** | Go | Infrastructure provisioning | Complementary — we generate Crossplane output |
| **Kratix** | Go | Platform-as-a-Product | Promises ≈ our Stack + Templates |
| **Score** | Go | Workload specification | Future input format (Phase 17) |
| **Timoni** | Go + CUE | K8s package manager | We generate Timoni modules from KCL |

**Unique Value**: No other tool offers **9+ output formats from a single KCL source** with compile-time validation, extensible plugin architecture, and zero-dependency binary distribution.

### Industry Patterns Applied

| Source | Pattern | How We Use It |
|---|---|---|
| k0rdent | TemplateChain (versioned upgrade paths) | `StackMetadata.upgradeFrom` (Phase 13) |
| k0rdent | DryRun with auto-defaults | `koncept validate` + FactorySeed auto-computation |
| Fleet | fleet.yaml per-path config | Per-component output config (Phase 16) |
| Kusion | Go CLI + KCL config (hybrid) | Phase 11 — same validated approach |
| Score | Platform-agnostic workload spec | Phase 17 — accept Score as input |
| CNCF Maturity Model | Level 3: Self-service, measured | Phases 11-18 target each aspect |

### Reference Documentation

- Testing strategy: [TESTING_STRATEGY.md](./TESTING_STRATEGY.md)
- Security policy: [SECURITY.md](./SECURITY.md)
- Platform comparison: [PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md](./PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md)
- Backstage analysis: [BACKSTAGE_ADOPTION_ANALYSIS.md](./BACKSTAGE_ADOPTION_ANALYSIS.md)
- Developer guide: [DEVELOPER_GUIDE.md](./DEVELOPER_GUIDE.md)
