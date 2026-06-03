# Helmfile + Helm Template Integration Testing

> Advanced guide for validating generated Helmfiles with real `helm template` execution in CI/CD pipelines

---

## Overview

The `koncept render helmfile` output is a valid Helmfile that references charts and versions. To fully validate Helmfile correctness before deployment, teams should integrate real `helm template` execution that:

1. **Resolves chart dependencies** using `helm dependency update`
2. **Templates charts** with generated values files
3. **Validates output manifests** against Kubernetes schemas (kubeval/kubeconform)
4. **Detects template injection errors** that YAML parsing alone can't catch
5. **Verifies chart availability** and version pinning correctness

---

## Prerequisites

```bash
# Install required tools
brew install helm kubeconform  # macOS
apt-get install helm kubeconform  # Ubuntu/Debian

# Verify installation
helm version --short
kubeconform -version
```

---

## Level 1: Basic Helmfile Validation (Dry-Run)

No helm binary required. Validates Helmfile syntax only:

```bash
# In your factory directory
helm diff secret

# Or using koncept:
koncept render helmfile --format helmfile
cat output/helmfile.yaml
```

**Use for**: Quick syntax checks, CI/CD gate before deploying to cluster

---

## Level 2: Chart Template Validation (Helm Template)

Requires `helm` binary. Validates that generated values can be templated:

```bash
#!/bin/bash
set -e

HELMFILE_PATH="output/helmfile.yaml"
CHARTS_DIR="output/charts"

# Step 1: Extract all chart references from helmfile
RELEASES=$(yq eval '.releases[].name' "$HELMFILE_PATH")

# Step 2: For each release, get chart and values
for release in $RELEASES; do
    echo "[INFO] Validating release: $release"
    
    # Extract chart repo/chart:version
    CHART=$(yq eval ".releases[] | select(.name == \"$release\") | .chart" "$HELMFILE_PATH")
    NAMESPACE=$(yq eval ".releases[] | select(.name == \"$release\") | .namespace" "$HELMFILE_PATH")
    
    # Create values file from release config
    RELEASE_VALUES="values-${release}.yaml"
    yq eval ".releases[] | select(.name == \"$release\") | .values" "$HELMFILE_PATH" > "$RELEASE_VALUES"
    
    # Step 3: Template the chart
    echo "  - Templating: helm template $release $CHART -n $NAMESPACE -f $RELEASE_VALUES"
    helm template "$release" "$CHART" \
        -n "$NAMESPACE" \
        -f "$RELEASE_VALUES" \
        > "output/templates-${release}.yaml" 2>&1 || {
            echo "[ERROR] Template failed for $release"
            exit 1
        }
    
    # Step 4: Validate templates
    echo "  - Validating: kubeconform output/templates-${release}.yaml"
    kubeconform -summary -output json "output/templates-${release}.yaml" || {
        echo "[ERROR] Validation failed for $release"
        exit 1
    }
done

echo "[SUCCESS] All charts templated and validated"
```

**Use for**: Catching template errors before cluster deployment

---

## Level 3: Full Helmfile Deployment Simulation

Requires helmfile binary + helm. Simulates real deployment:

```bash
#!/bin/bash
set -e

HELMFILE_PATH="output/helmfile.yaml"

# Option 1: Dry-run simulation
echo "[INFO] Simulating deployment with helmfile dry-run"
helmfile -f "$HELMFILE_PATH" --environment production sync --state delete --dry-run

# Option 2: Server-side dry-run against actual cluster
echo "[INFO] Server-side dry-run against cluster"
helmfile -f "$HELMFILE_PATH" --environment production apply --dry-run

# Option 3: Check what would be deployed
echo "[INFO] Helmfile diff (what would change)"
helmfile -f "$HELMFILE_PATH" --environment production diff
```

**Use for**: Pre-deployment validation against real clusters

---

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Validate Helmfile

on:
  pull_request:
    paths:
      - 'projects/*/pre_releases/**'
      - 'projects/*/releases/**'

jobs:
  helmfile-validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install tools
        run: |
          brew install helm kubeconform yq
          # Or for Linux: apt-get install...
      
      - name: Build KCL runtime
        run: |
          cd cmd/koncept && make build && cd ../..
      
      - name: Render helmfile from factory
        run: |
          cd projects/erp_back/pre_releases/manifests/dev
          /path/to/koncept render helmfile
      
      - name: Validate helmfile syntax
        run: |
          helm lint output/helmfile.yaml || true
          kubeconform -summary output/helmfile.yaml || true
      
      - name: Run helm template validation
        run: |
          bash scripts/helmfile_helm_integration_test.sh
      
      - name: Upload validation results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: helmfile-validation-results
          path: output/templates-*.yaml
```

### GitLab CI Example

```yaml
helmfile-validation:
  stage: validate
  image: golang:1.21-alpine
  before_script:
    - apk add helm kubeconform yq
  script:
    - cd projects/erp_back/pre_releases/manifests/dev
    - /path/to/koncept render helmfile
    - bash ../../../../../scripts/helmfile_helm_integration_test.sh
  artifacts:
    paths:
      - output/templates-*.yaml
    expire_in: 1 week
  allow_failure: false
```

---

## Advanced: Storage Class Validation

When using persistent storage, validate that storage classes are available:

```bash
#!/bin/bash

HELMFILE_PATH="output/helmfile.yaml"

# Extract storage class references
STORAGE_CLASSES=$(yq eval '.values.storageClassName' "$HELMFILE_PATH" | sort -u)

echo "[INFO] Checking storage class requirements:"
for sc in $STORAGE_CLASSES; do
    if [ -z "$sc" ] || [ "$sc" = "null" ]; then
        echo "  [warn] Undefined storage class (will use cluster default)"
        continue
    fi
    
    echo "  - Required storage class: $sc"
    
    # Check availability in cluster
    kubectl get storageclass "$sc" > /dev/null 2>&1 || {
        echo "  [ERROR] Storage class $sc not found in cluster"
        exit 1
    }
done

echo "[SUCCESS] All storage classes verified"
```

---

## Troubleshooting

### Chart Not Found

```
Error: UPGRADE FAILED: chart /path/to/chart not found
```

**Solution**:
```bash
# Update chart dependencies
helm dependency update

# Verify chart is available
helm search repo <chart-name>
```

### Template Injection Error

```
error parsing the template... undefined variable
```

**Solution**:
```bash
# Check values file format
cat values-<release>.yaml | head -20

# Validate YAML structure
yq eval . values-<release>.yaml

# Check chart's values schema
helm show values <chart-name>
```

### Schema Validation Failure

```
unable to validate the schema
```

**Solution**:
```bash
# Use kubeconform with schema skip for custom resources
kubeconform -skip CustomResourceDefinition,MyCustomKind output.yaml

# Or validate only standard K8s resources
kubeconform -kubernetes-version 1.31 output.yaml
```

---

## Integration Testing Acceptance Criteria

| Criterion | Description | Validation |
|-----------|-------------|-----------|
| **Helmfile Syntax** | Valid YAML structure | `helm lint` passes |
| **Chart Resolution** | All referenced charts exist and are accessible | `helm dependency list` succeeds |
| **Template Correctness** | Charts template without errors | `helm template` produces valid manifests |
| **Manifest Validation** | Generated manifests pass schema validation | `kubeconform` passes on all manifests |
| **Dependency Ordering** | Release `needs` entries are resolvable | Manual review of `needs` entries |
| **Storage Classes** | All referenced storage classes exist in target cluster | `kubectl get storageclass $SC` succeeds (optional) |

---

## Best Practices

### 1. Template Caching

Store templated output for visibility:

```bash
# Template once
helm template release mychart > templated.yaml

# Review before deployment
diff -u expected.yaml templated.yaml | less

# Use for further validation
kubeconform templated.yaml
```

### 2. Per-Environment Validation

Test each environment's values separately:

```bash
for ENV in dev staging production; do
    echo "[Testing] Environment: $ENV"
    helmfile -l environment=$ENV template > env-$ENV-full.yaml
    kubeconform env-$ENV-full.yaml
done
```

### 3. Incremental Rollout Validation

When releasing new versions:

```bash
# Generate manifests for current version
NEW_VERSION=$(yq eval '.metadata.version' stack_def.k)

# Template with new version
helm template release mychart-$NEW_VERSION > new.yaml

# Compare against current
kubectl diff -f new.yaml | head -50
```

### 4. Integration Test Matrix

Different environments warrant different validation depths:

```bash
# Development: Fast validation
helm template --dry-run quick

# Staging: Full validation
helmfile sync --dry-run
kubeconform full.yaml

# Production: Comprehensive pre-flight
helmfile diff
helm get values <release>
kubectl describe node
```

---

## Performance Tuning

### Parallel Template Validation

```bash
# Template multiple charts in parallel for faster CI
for release in $(yq eval '.releases[].name' helmfile.yaml); do
    (
        helm template "$release" "$CHART" -f values-$release.yaml \
            > output/templates-$release.yaml
    ) &
done
wait

# Then validate all in sequence
find output -name "templates-*.yaml" -exec kubeconform {} \;
```

### Caching Dependencies

```yaml
# GitHub Actions caching for helm dependency downloads
- uses: actions/cache@v3
  with:
    path: ~/.cache/helm
    key: helm-dependencies-${{ hashFiles('**/Chart.lock') }}
```

---

## Next Steps

Once Helmfile validation is integrated into CI/CD:

1. **Add to PR gates** — Require validation before merge
2. **Expand to Crossplane** — Similar template validation for compositions
3. **Monitor template drift** — Alert when generated templates diverge from expected
4. **Performance optimization** — Cache chart sources, parallelize validation

---

## Reference

- [Helm Template Documentation](https://helm.sh/docs/helm/helm_template/)
- [Helmfile GitHub](https://github.com/roboll/helmfile)
- [Kubeconform GitHub](https://github.com/yannh/kubeconform)
- [PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md - Helmfile Output Excellence](./PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md)

