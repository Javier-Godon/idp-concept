# Testing Strategy

> Comprehensive testing approach for **idp-concept** — covering KCL unit tests, K8s manifest validation, Helm chart linting, and integration testing.

## Table of Contents

- [1. Testing Layers](#1-testing-layers)
- [2. KCL Unit Tests (`kcl test`)](#2-kcl-unit-tests-kcl-test)
- [3. K8s Manifest Validation (`kubeconform`)](#3-k8s-manifest-validation-kubeconform)
- [4. Helm Chart Linting (`helm lint`)](#4-helm-chart-linting-helm-lint)
- [5. Integration Tests (End-to-End Render Pipeline)](#5-integration-tests-end-to-end-render-pipeline)
- [5.3 Crossplane V2 Composition and Management Tests](#53-crossplane-v2-composition-and-management-tests)
- [6. Test Organization](#6-test-organization)
- [7. Running Tests](#7-running-tests)
- [8. CI/CD Integration](#8-cicd-integration)

---

## 1. Testing Layers

| Layer | Tool | What It Tests | Speed |
|---|---|---|---|
| **Unit** | `kcl test` | Builder lambdas, schema validation, check blocks, merge logic | Fast (<1s per file) |
| **Schema Validation** | `kcl vet` | Configuration data against KCL schemas | Fast |
| **K8s Compliance** | `kubeconform` | Generated YAML against K8s OpenAPI schemas | Fast |
| **Chart Linting** | `helm lint` | Generated Helm chart structure and values | Fast |
| **Integration** | `kcl run` + `kubeconform` | Full render pipeline → valid K8s manifests | Medium |
| **Crossplane composition** | `crossplane render` + optional Go tests | XRD/Composition/XR/function output and function results | Medium |
| **Acceptance** | `kind` + `kubectl` | Curated generated workloads really apply and roll out in Kubernetes | Slow / opt-in |

### Testing Pyramid

```
         ┌──────────────┐
         │ Acceptance   │  ← kind + kubectl, curated deployability checks
         ├──────────────┤
         │ Crossplane   │  ← crossplane render + reconcile/update/delete checks
         ├──────────────┤
         │ Integration  │  ← Full render pipeline (kcl run → kubeconform)
         ├──────────────┤
         │  K8s Schema  │  ← kubeconform validates generated YAML
         ├──────────────┤
         │  KCL Units   │  ← kcl test: builders, templates, models, procedures
         └──────────────┘
```

---

## 2. KCL Unit Tests (`kcl test`)

### How It Works

- Test files must match the pattern `*_test.k`
- Test functions are lambdas prefixed with `test_`
- Assertions use the `assert` keyword
- Error testing uses `import runtime` and `runtime.catch(lambda)` to capture check block errors
- Run with `kcl test` (current directory) or `kcl test ./...` (recursive)

### Test File Convention

```kcl
# framework/tests/builders/deployment_test.k
import builders.deployment as deploy

test_build_deployment_minimal = lambda {
    _spec = deploy.DeploymentSpec {
        name = "test-app"
        namespace = "default"
        image = "test/image"
        version = "1.0.0"
    }
    _result = deploy.build_deployment(_spec)
    assert _result.metadata.name == "test-app"
    assert _result.kind == "Deployment"
}
```

### What to Test

| Target | Tests |
|---|---|
| **Builders** | Correct manifest structure, default values, conditional fields, ConfigMap auto-wiring |
| **Templates** | Auto-generated manifests (deployment + service + configmap), optional resources |
| **Models** | Schema check blocks (port range, replicas >= 1), merge_configurations union order |
| **Procedures** | Kusion ID format, YAML stream flattening, helper extraction |
| **Assembly** | Namespace creation, config-based namespace lookup |

### Testing Check Blocks

```kcl
import runtime

test_port_range_validation = lambda {
    _err = runtime.catch(lambda {
        deploy.DeploymentSpec {
            name = "bad"
            namespace = "ns"
            image = "img"
            version = "1.0"
            port = 99999  # Invalid
        }
    })
    assert _err == "port must be 1-65535"
}
```

---

## 3. K8s Manifest Validation (`kubeconform`)

### Installation

```bash
go install github.com/yannh/kubeconform/cmd/kubeconform@v0.7.0
```

### Usage

```bash
# Validate a single rendered output
kcl run factory/yaml_builder.k | kubeconform -summary -strict

# Validate with CRD schemas (for Strimzi, Crossplane, etc.)
kubeconform -summary -strict \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  output.yaml
```

### Output Formats

- `-output text` (default): human-readable
- `-output json`: machine-readable
- `-output junit`: for CI systems
- `-output tap`: TAP format

### What It Catches

- Invalid K8s API versions
- Missing required fields
- Wrong field types
- Unknown fields (with `-strict`)
- Deprecated API versions

---

## 4. Helm Chart Linting (`helm lint`)

### Usage

```bash
# Lint a generated chart
helm lint output/charts/my-app/

# Lint with custom values
helm lint output/charts/my-app/ -f custom-values.yaml
```

### What It Catches

- Malformed Chart.yaml
- Invalid template syntax
- Missing required chart metadata
- Template rendering errors

---

## 5. Integration Tests (End-to-End Render Pipeline)

### Approach

Run full KCL render pipelines on existing projects and validate the output:

```bash
# 1. Render YAML from erp_back pre-release
cd projects/erp_back/pre_releases
kcl run manifests/dev/factory/yaml_builder.k > /tmp/output.yaml

# 2. Validate with kubeconform
kubeconform -summary -strict /tmp/output.yaml

# 3. Render Kusion format and check structure
kcl run manifests/dev/factory/kusion_builder.k > /tmp/kusion.yaml
# Verify Kusion resource IDs follow expected format
```

---

## 5.1 Acceptance Tests (Ephemeral Kubernetes)

Acceptance cluster tests live outside the default `./scripts/verify.sh` path because they require Docker, kind, image pulls, and more time. The default verification script still renders every acceptance fixture to keep all template examples compiling through the IDP render path.

The optional runner is:

```bash
./scripts/acceptance_kind.sh
```

Current cases and groups:

| Case / Group | Scope | Command |
|---|---|---|
| `basic` | lightweight core workload generated by framework builders | `./scripts/acceptance_kind.sh --case basic` |
| `webapp` | `WebAppModule` Deployment/Service/ConfigMap rollout with a tiny image | `./scripts/acceptance_kind.sh --case webapp` |
| `database` | `SingleDatabaseModule` Deployment/Service/PV/PVC rollout with a local PV | `./scripts/acceptance_kind.sh --case database` |
| `dataprepper` | standalone Data Prepper workload, server-side dry-run | `./scripts/acceptance_kind.sh --case dataprepper` |
| `search` | OpenSearch, OpenSearch Dashboards, Elastic v7 OSS, and Elastic v9 ECK fixtures | `./scripts/acceptance_kind.sh --case search` |
| `data` | Kafka, PostgreSQL, MongoDB, RabbitMQ, Redis, MinIO, QuestDB, Valkey, plus database | `./scripts/acceptance_kind.sh --case data` |
| `platform` | Backstage, Observability, OpenTelemetry, Vault, Keycloak, Ceph, Longhorn, OpenBao | `./scripts/acceptance_kind.sh --case platform` |
| `templates` | every framework template acceptance fixture through `kcl_to_yaml` | `./scripts/acceptance_kind.sh --case templates` |
| `integrations` | dependency scenarios: Data Prepper + OpenSearch, Keycloak + PostgreSQL, persistence + Longhorn/Ceph | `./scripts/acceptance_kind.sh --case integrations` |
| `rollouts` | rollout-specific fixture shapes for native Kubernetes search/ingestion templates | `./scripts/acceptance_kind.sh --case rollouts` |
| `all` | `basic` plus the full template, integration, and rollout matrix | `./scripts/acceptance_kind.sh --case all` |

`basic`, `webapp`, and `database` apply resources and wait for rollout. Operator-backed, Helm-backed, heavyweight, and dependency scenario cases render through the IDP `RenderStack` path and run server-side dry-run with lightweight CRD stubs from `framework/tests/acceptance/crds/dry_run_crds.yaml`.

For real rollout checks beyond `webapp`/`database`, use the opt-in runtime layer:

```bash
./scripts/acceptance_runtime.sh --case runtime-rollouts --timeout 300s
```

That group proves the template-generated native `Deployment`/`StatefulSet`
resources roll out in kind while still avoiding full product dependencies.

Preflight only:

```bash
./scripts/acceptance_kind.sh --preflight-only
```

The acceptance approach follows common Kubernetes platform/operator testing practices:

- create an isolated `kind` cluster per run
- render manifests from KCL fixtures
- run `kubectl apply --dry-run=server` before creating resources
- apply resources and wait for rollout/Ready status
- keep heavy/operator-backed cases opt-in or nightly

See `docs/ACCEPTANCE_TESTING.md` for runner details and `docs/ACCEPTANCE_DEPENDENCIES.md` for the dependency matrix covering scenarios such as `keycloak-postgresql`, `dataprepper-opensearch`, `persistence-longhorn`, `persistence-ceph`, and future runtime groups like `elastic-eck-v9`.

### 5.2 Runtime Acceptance Tests (Real Deployments)

The dry-run runner proves that manifests render and Kubernetes accepts their shapes. Runtime acceptance proves that resources are actually applied and become ready.

Use the runtime runner for real deployment checks:

```bash
./scripts/acceptance_runtime.sh --case runtime-basic
```

Runtime acceptance does **not** install dry-run CRD stubs. Operator-backed templates require real operators/controllers. For disposable kind/nightly runs, the runner can attempt to install pinned dependencies:

```bash
./scripts/acceptance_runtime.sh --case runtime-cnpg --install-dependencies
./scripts/acceptance_runtime.sh --case runtime-keycloak-postgresql --install-dependencies
./scripts/acceptance_runtime.sh --case runtime-all --install-dependencies
```

See `docs/ACCEPTANCE_RUNTIME.md` for runtime groups and readiness semantics.

### 5.3 Crossplane V2 Composition and Management Tests

Crossplane tests must prove the platform API is manageable after deployment, not only that YAML renders.

Required levels for supported Crossplane APIs:

| Level | Tooling | Expected proof |
|---|---|---|
| Static render | `koncept render crossplane` or `kcl run ... -D output=crossplane` | XRD, Composition, XR, Provider/Function prerequisites render deterministically. |
| Local composition preview | `crossplane render xr.yaml composition.yaml functions.yaml --include-function-results` | Function pipeline returns the expected desired resources and no fatal function results. |
| Function unit tests | `go test` for custom `function-sdk-go` functions; KCL tests for shared KCL helpers | Composition logic is tested independently from a cluster. |
| Reconciliation | kind or real cluster with pinned Crossplane providers/functions | XR/Claim reaches Synced/Ready and expected composed resources exist. |
| Management lifecycle | kubectl/Go helper updates and deletes the XR/Claim | Updates propagate to composed resources; deletion cleans up or intentionally orphans resources according to policy. |
| Upgrade/rollback | composition revisions or pinned `compositionRevisionRef` | Existing XRs can be safely upgraded or rolled back. |

Recommended future Go tooling: add `koncept crossplane test` as the single supported wrapper for static render, policy checks, `crossplane render`, and optional reconciliation/update/delete checks. This keeps Crossplane validation in the same CLI surface as render, policy, golden, and changelog workflows.

---

## 6. Test Organization

Test files are organized in a dedicated `tests/` directory that mirrors the source structure:

```
framework/
├── builders/
│   ├── deployment.k
│   ├── service.k
│   ├── configmap.k
│   ├── storage.k
│   ├── service_account.k
│   └── leader.k
├── models/
│   ├── configurations.k
│   └── modules/
│       ├── k8snamespace.k
│       └── common.k
├── assembly/
│   └── helpers.k
├── procedures/
│   ├── helper.k
│   ├── kcl_to_kusion.k
│   └── kcl_to_yaml.k
├── templates/
│   ├── webapp.k
│   └── database.k
└── tests/                              ← All tests grouped here
    ├── builders/
    │   ├── deployment_test.k           ← 23 tests
    │   ├── service_test.k              ← 9 tests
    │   ├── configmap_test.k            ← 2 tests
    │   ├── storage_test.k              ← 5 tests
    │   ├── service_account_test.k      ← 2 tests
    │   ├── leader_test.k               ← 3 tests
    │   ├── network_policy_test.k       ← 4 tests
    │   └── pdb_test.k                  ← 4 tests
    ├── models/
    │   ├── configurations_test.k       ← 4 tests
    │   ├── configurations_git_test.k   ← 4 tests
    │   ├── secrets_test.k              ← 6 tests
    │   └── modules/
    │       ├── common_test.k           ← 7 tests
    │       ├── k8snamespace_test.k     ← 4 tests
    │       └── thirdparty_helm_test.k  ← 5 tests
    ├── assembly/
    │   └── helpers_test.k              ← 3 tests
    ├── procedures/
    │   ├── helper_test.k               ← 3 tests
    │   ├── kusion_test.k               ← 8 tests
    │   ├── yaml_test.k                 ← 5 tests
    │   ├── helm_values_test.k          ← 8 tests
    │   ├── helmfile_test.k             ← 5 tests
    │   ├── helm_test.k                 ← 5 tests
    │   ├── argocd_test.k               ← 5 tests
    │   └── kustomize_test.k            ← 8 tests
    └── templates/
        ├── webapp_test.k               ← 8 tests
        ├── database_test.k             ← 8 tests
        ├── postgresql_test.k           ← 10 tests (CloudNativePG)
        ├── mongodb_test.k              ← 6 tests (Community Operator)
        ├── rabbitmq_test.k             ← 7 tests (Cluster Operator)
        ├── redis_test.k                ← 6 tests (OT Redis)
        ├── keycloak_test.k             ← 5 tests (Keycloak Operator)
        ├── opensearch_test.k           ← 8 tests (k8s-operator)
        ├── vault_test.k                ← 7 tests (VSO)
        ├── questdb_test.k              ← 4 tests (Helm chart)
        ├── minio_test.k                ← 8 tests (Operator + Bitnami)
        ├── observability_test.k        ← 8 tests (Prometheus + Grafana + ServiceMonitor)
        ├── valkey_test.k               ← 4 tests (Helm chart)
        ├── openbao_test.k              ← 4 tests (Helm chart)
        └── ceph_test.k                 ← 4 tests (Helm chart)
```

Test files are in a dedicated `tests/` directory mirroring the source tree. Imports use package-relative paths (e.g., `import builders.deployment as deploy`) which resolve from the `framework` package root regardless of the test file's location.

### Known Limitation: `kcl test` + Auto-Computed `instance` Fields

Schemas with auto-computed `instance` fields (like `Component` and `Accessory`) cannot be directly instantiated in `kcl test` lambdas. When the parent schema's `instance` field default tries to evaluate `manifests` (which depends on builder lambda results), `kcl test` evaluates `instance` before the child schema's private computed fields are resolved, causing `UndefinedType` errors. This works correctly with `kcl run`.

**Workaround**: Template tests validate the individual builder outputs that templates compose, rather than instantiating the full template schema. Integration testing via `kcl run` + `kubeconform` validates the complete pipeline.

### Current Test Count

| Category | Tests |
|---|---|
| Framework suite total | See latest `./scripts/verify.sh` output |
| Latest verified count in this branch | 386 |
| Notes | Includes builders, models, assembly, procedures, templates, and factory convention tests |

---

## 7. Running Tests

### Run All Framework Tests

```bash
cd framework && kcl test ./...
```

### Run Tests in a Specific Directory

```bash
cd framework && kcl test ./builders/...
```

### Run a Specific Test

```bash
cd framework && kcl test --run "test_build_deployment_minimal"
```

### Run with Fail-Fast

```bash
cd framework && kcl test ./... --fail-fast
```

### Full Validation Pipeline

```bash
# 0. Canonical one-command verification
./scripts/verify.sh

# 1. KCL unit tests
cd framework && kcl test ./...

# 2. Integration: render + validate
cd projects/erp_back/pre_releases
kcl run manifests/dev/factory/render.k -D output=yaml | kubeconform -summary -strict

# 3. Helm lint
cd projects/erp_back/pre_releases
kcl run manifests/dev/factory/render.k -D output=helm

# 4. Optional acceptance smoke in kind
./scripts/acceptance_kind.sh --case basic
```

---

## 8. CI/CD Integration

### GitHub Actions Example

```yaml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: kcl-lang/setup-kcl@v0.2.0
        with:
          kcl-version: "0.11.3"
      - name: Install kubeconform
        run: go install github.com/yannh/kubeconform/cmd/kubeconform@v0.7.0
      - name: KCL Unit Tests
        run: cd framework && kcl test ./...
      - name: Render & Validate (erp_back)
        run: |
          cd projects/erp_back/pre_releases
          kcl run manifests/dev/factory/render.k -D output=yaml | kubeconform -summary -strict
```

### Test Coverage Targets

| Layer | Goal |
|---|---|
| Builder lambdas | 100% — every builder tested with minimal + full specs |
| Schema check blocks | 100% — every check block tested with valid + invalid input |
| Templates | 100% — every template tested for manifest count and structure |
| Procedures | 80% — working procedures tested; empty ones tracked |
| Integration | Per-project — every pre_release renders valid K8s YAML |
| Acceptance | Curated smoke coverage for deployability; heavy infrastructure groups run opt-in/nightly |
