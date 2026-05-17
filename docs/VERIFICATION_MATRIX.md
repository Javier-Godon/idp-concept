# Verification Matrix

This matrix defines the baseline verification steps contributors should run before opening a PR.

## Baseline Command

```bash
./scripts/verify.sh
```

The script runs scoped lint, framework unit tests, and output render smoke checks.

## Step-by-Step Matrix

| Layer | Scope | Command | Expected Result |
|---|---|---|---|
| Lint | framework sources (excluding `framework/main.k`) | `cd framework && kcl lint builders/*.k models/*.k models/modules/*.k procedures/*.k templates/*.k assembly/*.k` | No errors |
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
./scripts/acceptance_kind.sh --case webapp --case database

# Run heavier or dry-run-only acceptance smoke cases explicitly
./scripts/acceptance_kind.sh --case dataprepper
./scripts/acceptance_kind.sh --case search
```

## CI Recommendation

In CI, call the single script entrypoint:

```bash
./scripts/verify.sh
```

