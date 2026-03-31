# Testing Strategy

> Comprehensive testing approach for **idp-concept** — covering KCL unit tests, K8s manifest validation, Helm chart linting, and integration testing.

## Table of Contents

- [1. Testing Layers](#1-testing-layers)
- [2. KCL Unit Tests (`kcl test`)](#2-kcl-unit-tests-kcl-test)
- [3. K8s Manifest Validation (`kubeconform`)](#3-k8s-manifest-validation-kubeconform)
- [4. Helm Chart Linting (`helm lint`)](#4-helm-chart-linting-helm-lint)
- [5. Integration Tests (End-to-End Render Pipeline)](#5-integration-tests-end-to-end-render-pipeline)
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

### Testing Pyramid

```
         ┌──────────────┐
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
kcl run gitops/dev/factory/yaml_builder.k > /tmp/output.yaml

# 2. Validate with kubeconform
kubeconform -summary -strict /tmp/output.yaml

# 3. Render Kusion format and check structure
kcl run gitops/dev/factory/kusion_builder.k > /tmp/kusion.yaml
# Verify Kusion resource IDs follow expected format
```

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
    │   └── leader_test.k               ← 3 tests
    ├── models/
    │   ├── configurations_test.k       ← 4 tests
    │   └── modules/
    │       ├── common_test.k           ← 7 tests
    │       └── k8snamespace_test.k     ← 4 tests
    ├── assembly/
    │   └── helpers_test.k              ← 3 tests
    ├── procedures/
    │   ├── helper_test.k               ← 3 tests
    │   ├── kusion_test.k               ← 8 tests
    │   └── yaml_test.k                 ← 5 tests
    └── templates/
        ├── webapp_test.k               ← 8 tests
        └── database_test.k             ← 8 tests
```

Test files are in a dedicated `tests/` directory mirroring the source tree. Imports use package-relative paths (e.g., `import builders.deployment as deploy`) which resolve from the `framework` package root regardless of the test file's location.

### Known Limitation: `kcl test` + Auto-Computed `instance` Fields

Schemas with auto-computed `instance` fields (like `Component` and `Accessory`) cannot be directly instantiated in `kcl test` lambdas. When the parent schema's `instance` field default tries to evaluate `manifests` (which depends on builder lambda results), `kcl test` evaluates `instance` before the child schema's private computed fields are resolved, causing `UndefinedType` errors. This works correctly with `kcl run`.

**Workaround**: Template tests validate the individual builder outputs that templates compose, rather than instantiating the full template schema. Integration testing via `kcl run` + `kubeconform` validates the complete pipeline.

### Current Test Count: 116 tests (all PASS)

| Category | Tests |
|---|---|
| Builder lambdas | 44 |
| Model schemas | 19 |
| Assembly helpers | 3 |
| Procedures | 36 |
| Template builders | 16 |
| **Total** | **116** |

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
# 1. KCL unit tests
cd framework && kcl test ./...

# 2. Integration: render + validate
cd projects/erp_back/pre_releases
kcl run gitops/dev/factory/yaml_builder.k | kubeconform -summary -strict

# 3. Helm lint (when Helm output is implemented)
# helm lint output/charts/*/
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
          kcl run gitops/dev/factory/yaml_builder.k | kubeconform -summary -strict
```

### Test Coverage Targets

| Layer | Goal |
|---|---|
| Builder lambdas | 100% — every builder tested with minimal + full specs |
| Schema check blocks | 100% — every check block tested with valid + invalid input |
| Templates | 100% — every template tested for manifest count and structure |
| Procedures | 80% — working procedures tested; empty ones tracked |
| Integration | Per-project — every pre_release renders valid K8s YAML |
