# Acceptance Testing Instructions

Use these rules when creating or modifying acceptance fixtures, `scripts/acceptance_kind.sh`, or acceptance documentation.

## Core Rule: Use the IDP Render Path

Acceptance fixtures must exercise the same path as project factories:

```text
template/module instance -> RenderStack -> procedures.kcl_to_yaml.yaml_stream_stack
```

Use helpers from `framework/tests/acceptance/cases/_helpers.k`:

- `render_component(namespace, module)` for one `ComponentInstance`
- `render_accessory(namespace, module)` for one `AccessoryInstance`
- `render_stack(namespaces, components, accessories)` for dependency scenarios with multiple modules
- `wrap_component(...)` for rollout fixtures that patch template-generated component manifests before rendering
- `wrap_accessory(...)` only when a template exposes build functions instead of a module schema

Do not bypass the IDP path with direct `manifests.yaml_stream([...])` in acceptance fixtures unless the fixture is intentionally testing a low-level builder outside the template acceptance matrix.

## Acceptance Levels

| Level | Use for | Runner behavior |
|---|---|---|
| L0 render | All fixtures | `./scripts/verify.sh` runs `kcl run` for every `*_workload.k`. |
| L1 server dry-run | Operator/Helm/heavy cases | `./scripts/acceptance_kind.sh` installs dry-run CRD stubs and runs `kubectl apply --dry-run=server`. |
| L2 lightweight apply | Built-in Kubernetes resources that reliably roll out in kind | Only `basic`, `webapp`, and `database` currently apply and wait. |
| L3/L4 runtime | Real operators/controllers and service behavior | Use `./scripts/acceptance_runtime.sh`; keep opt-in/nightly and out of default local verification. |

## Dependency-Aware Fixtures

Create scenario fixtures when modules are commonly deployed together or need each other for runtime behavior:

- `dataprepper-opensearch`: Data Prepper pipeline points at OpenSearch.
- `keycloak-postgresql`: Keycloak configured for PostgreSQL-backed persistence.
- `persistence-longhorn`: PVC-producing templates use a Longhorn StorageClass.
- `persistence-ceph`: PVC-producing templates use a Rook Ceph StorageClass.

Scenario fixtures should render all related modules in one `RenderStack` with `_helpers.render_stack` and should be registered in the `INTEGRATION_CASES` array in `scripts/acceptance_kind.sh`.

## Runtime Rollout Fixtures

Use `*-rollout` fixtures for native Kubernetes templates that emit Deployments or StatefulSets but need heavyweight runtimes or backing services for real product startup. These fixtures should:

- Instantiate the real template module first.
- Patch only the container runtime/image/command needed to satisfy generated probes in kind.
- Render through `_helpers.wrap_component` and `_helpers.render_component`.
- Be registered in `ROLLOUT_CASES` in `scripts/acceptance_kind.sh` and `RUNTIME_ROLLOUT_CASES` in `scripts/acceptance_runtime.sh`.
- Remain distinct from full product integration tests.

## Storage Rules

Persistent templates require a working Kubernetes StorageClass/provisioner for real reconciliation. They do not inherently require Longhorn or Ceph unless their StorageClass is selected.

- Use `createLocalPersistentVolume = True` only for lightweight kind rollout cases.
- Use named classes like `acceptance-longhorn` or `acceptance-ceph-block` in dry-run dependency scenarios.
- Document the storage provider and readiness requirements in `docs/ACCEPTANCE_DEPENDENCIES.md`.

## Security Rules

- Never hardcode credentials, tokens, passwords, or real endpoints.
- Use Secret references or operator-generated credentials; acceptance dry-run does not need real secret values.
- Pin every image/chart/operator version. Never use `latest`.
- Do not add privileged pods, `hostNetwork: true`, or broad RBAC to acceptance fixtures.

## Runner Rules

- Keep `APPLY_CASES` intentionally small and reliable.
- Group selections must run cases one by one and clean successful case resources before moving to the next fixture; do not deploy the full template catalog at once.
- Add operator/Helm/heavy fixtures to dry-run groups, not `APPLY_CASES`, unless a real controller install/wait path is implemented.
- Put real deployment checks in `scripts/acceptance_runtime.sh`, not in the dry-run runner.
- If a dry-run fixture emits a new custom resource kind, add a minimal CRD stub in `framework/tests/acceptance/crds/dry_run_crds.yaml`.
- Update `docs/ACCEPTANCE_TESTING.md`, `docs/ACCEPTANCE_DEPENDENCIES.md`, `docs/ACCEPTANCE_RUNTIME.md`, and `docs/VERIFICATION_MATRIX.md` when adding new groups or scenarios.

