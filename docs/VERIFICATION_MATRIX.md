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
./scripts/acceptance_kind.sh --case webapp --case database --case webapp-service-account-rollout --case webapp-database-stack-rollout --case elasticsearch-kibana-stack-rollout --case elk-stack-rollout --case webapp-dataprepper-stack-rollout

# Render/dry-run every template acceptance case
./scripts/acceptance_kind.sh --case templates

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
# Includes single-template rollouts (webapp-probes, webapp-sa, dataprepper, opensearch-dashboards,
# elasticsearch, kibana, logstash) and mixture stack rollouts (webapp+database, elasticsearch+kibana,
# full ELK, webapp+dataprepper)
./scripts/acceptance_runtime.sh --case runtime-rollouts --timeout 300s

# Run opt-in/nightly real deployment checks with pinned dependency installers
./scripts/acceptance_runtime.sh --case runtime-all --install-dependencies
```

See `docs/ACCEPTANCE_DEPENDENCIES.md` for dependency requirements and `docs/ACCEPTANCE_RUNTIME.md` for the real deployment acceptance layer.

## CI Recommendation

In CI, call the single script entrypoint:

```bash
./scripts/verify.sh
```

