# Verification Matrix

This matrix defines the baseline verification steps contributors should run before opening a PR.

## Baseline Command

```bash
./scripts/verify.sh
```

The script runs scoped lint, acceptance fixture render checks, framework unit tests, and output render smoke checks.

## Step-by-Step Matrix

| Layer | Scope | Command | Expected Result |
|---|---|---|---|
| Lint | framework sources (excluding `framework/main.k`) | `cd framework && kcl lint builders/*.k models/*.k models/modules/*.k procedures/*.k templates/*.k assembly/*.k` | No errors |
| Acceptance fixture render | every `framework/tests/acceptance/cases/*_workload.k` fixture | `./scripts/verify.sh` | Every template fixture renders through the IDP path |
| Unit tests | full framework suite | `cd framework && kcl test ./...` | All tests pass |
| Render smoke | `erp_back` dev factory, all outputs | `cd projects/erp_back/pre_releases/manifests/dev/factory && kcl run render.k -D output=<mode>` | Command succeeds |
| Policy gate | rendered Tier-1 YAML | `koncept policy check --factory projects/erp_back/pre_releases/manifests/dev/factory` | No blocking security/ownership findings |
| Changelog fragments | `.changes/unreleased/*.yaml` | `koncept changelog check` | Release-note fragments are valid and owned |
| Golden drift | reference factories (`erp_back` dev/stg/release) | `./scripts/golden.sh check` | Rendered output matches committed `golden/` snapshots |
| Crossplane render smoke | generated Crossplane output | `cd projects/erp_back/pre_releases/manifests/dev/factory && kcl run render.k -D output=crossplane` | XRD, Composition, XR, and prerequisites render without errors |
| Acceptance smoke | optional kind cluster | `./scripts/acceptance_kind.sh --case basic` | Generated resources apply and Deployment rolls out |

Supported `<mode>` values for smoke checks:

- `yaml`
- `argocd`
- `helmfile`
- `helm`
- `kustomize`
- `timoni`
- `crossplane`
- `backstage`

## Optional Extended Checks

Use these when changing generated manifest shapes or adding new templates.

```bash
# Validate YAML output against Kubernetes schemas (requires kubeconform)
cd projects/erp_back/pre_releases/manifests/dev/factory
kcl run render.k -D output=yaml | kubeconform -summary -strict

# Run only template tests while iterating on templates
cd framework
kcl test ./tests/templates/...

# Check local kind acceptance prerequisites
./scripts/acceptance_kind.sh --preflight-only

# Deploy the lightweight generated workload into an ephemeral kind cluster
./scripts/acceptance_kind.sh --case basic

# Run additional lightweight template rollout checks
./scripts/acceptance_kind.sh \
  --case webapp \
  --case database \
  --case fluentbit-native-rollout \
  --case webapp-service-account-rollout \
  --case webapp-database-stack-rollout \
  --case elasticsearch-kibana-stack-rollout \
  --case elk-stack-rollout \
  --case webapp-dataprepper-stack-rollout \
  --case webapp-opensearch-dashboards-stack-rollout \
  --case webapp-elk-stack-rollout \
  --case dataprepper-elk-stack-rollout \
  --case webapp-dataprepper-elk-stack-rollout \
  --case webapp-database-dataprepper-stack-rollout

# Render/dry-run every template acceptance case
./scripts/acceptance_kind.sh --case templates

# Target new low-cost template fixtures
./scripts/acceptance_kind.sh --case data-admin --case release-notes

# Run policy with explicit, expiring waivers when temporary exceptions are needed
koncept policy check --factory <factory-dir> --exemptions policy-exemptions.yaml

# Crossplane v2 static render smoke
cd projects/erp_back/pre_releases/manifests/dev/factory
kcl run render.k -D output=crossplane

# Crossplane v2 composition preview once fixture files exist
crossplane render xr.yaml composition.yaml functions.yaml --include-function-results

# Required for supported Crossplane APIs: reconcile, update, delete, and revision rollback tests
# through the future `koncept crossplane test` wrapper or the project-specific kind/runtime script.

# Render the next platform release-note section from reviewed fragments
koncept changelog render --version v0.2.0 --file CHANGELOG.next.md

# Run grouped opt-in acceptance checks
./scripts/acceptance_kind.sh --case data
./scripts/acceptance_kind.sh --case search
./scripts/acceptance_kind.sh --case platform

# Run dependency-oriented integration dry-run checks
./scripts/acceptance_kind.sh --case integrations

# Dry-run the rollout fixture shapes
./scripts/acceptance_kind.sh --case rollouts

# Run real deployment checks for lightweight built-in Kubernetes fixtures
./scripts/acceptance_runtime.sh --case runtime-basic

# Run real rollout checks for native Deployment/StatefulSet template fixtures
# Existing 16 rollout cases verified on kind (kindest/node:v1.33.0);
# run fluentbit-native-rollout for the new Fluent Bit path:
# Single-template: dataprepper-rollout, opensearch-dashboards-rollout, elasticsearch-rollout,
#   kibana-rollout, logstash-rollout, fluentbit-native-rollout, webapp-probes-rollout, webapp-service-account-rollout
# 2-template mixtures: webapp-database-stack-rollout, elasticsearch-kibana-stack-rollout,
#   webapp-dataprepper-stack-rollout, webapp-opensearch-dashboards-stack-rollout
# 3-template mixtures: elk-stack-rollout, webapp-elk-stack-rollout,
#   dataprepper-elk-stack-rollout, webapp-database-dataprepper-stack-rollout
# 4-template mixture: webapp-dataprepper-elk-stack-rollout
./scripts/acceptance_runtime.sh --case runtime-rollouts --timeout 600s

# Run opt-in/nightly real deployment checks with pinned dependency installers
./scripts/acceptance_runtime.sh --case runtime-all --install-dependencies
```

See [ACCEPTANCE_DEPENDENCIES.md](ACCEPTANCE_DEPENDENCIES.md) for dependency requirements,
[ACCEPTANCE_RUNTIME.md](ACCEPTANCE_RUNTIME.md) for the real deployment acceptance layer,
[GOLDEN_OUTPUTS.md](GOLDEN_OUTPUTS.md) for snapshot review,
[POLICY_EXEMPTIONS.md](../operations/POLICY_EXEMPTIONS.md) for owned/time-bounded policy waivers,
[CHANGELOG_WORKFLOW.md](../operations/CHANGELOG_WORKFLOW.md) for platform release-note fragments,
and [CROSSPLANE_PATTERNS.md](../integrations/CROSSPLANE_PATTERNS.md) for the Crossplane v2 management
test bar.

## CI Recommendation

In CI, call the single script entrypoint:

```bash
./scripts/verify.sh
```

CI also runs the Go CLI policy gate and `./scripts/golden.sh check` in
`.github/workflows/validate.yml` so security findings and render drift are
visible before merge.
