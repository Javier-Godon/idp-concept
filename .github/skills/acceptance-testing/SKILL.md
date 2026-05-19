---
name: acceptance-testing
description: "Acceptance testing patterns for idp-concept. Use when adding or modifying acceptance fixtures, kind runner groups, dry-run CRD stubs, or dependency scenarios for framework templates."
---

# Acceptance Testing Skill for idp-concept

## When to Use

- Adding or modifying files under `framework/tests/acceptance/`
- Changing `scripts/acceptance_kind.sh` or acceptance-related verification
- Creating dependency scenarios such as Data Prepper + OpenSearch or Keycloak + PostgreSQL
- Deciding whether a fixture should be rendered, server-side dry-run, or fully applied in kind
- Documenting runtime prerequisites for template deployments

## Mental Model

Acceptance coverage has four practical levels:

1. **Render through IDP (L0)** — every fixture must compile and render through `RenderStack` and `kcl_to_yaml`.
2. **Server-side dry-run (L1)** — Kubernetes API validates the resource shapes. Custom resources need lightweight CRD stubs.
3. **Lightweight apply (L2)** — only simple built-in Kubernetes workloads apply and wait in kind.
4. **Real runtime/integration (L3/L4)** — real operators, storage providers, and service behavior checks with `scripts/acceptance_runtime.sh`. Keep these opt-in/nightly.

## Required IDP Render Path

Use `framework/tests/acceptance/cases/_helpers.k`:

```kcl
import ._helpers as h

h.render_component(namespace, component_instance)
h.render_accessory(namespace, accessory_instance)
h.render_stack([namespace], [component_instance], [accessory_instance])
```

Avoid direct `manifests.yaml_stream([...])` in template acceptance fixtures.

## Current Groups

| Group | Purpose |
|---|---|
| `basic` | Tiny builder smoke, applies by default. |
| `search` | OpenSearch, OpenSearch Dashboards, Elastic v7, Elastic v9 ECK dry-run cases. |
| `data` | Kafka, PostgreSQL, MongoDB, RabbitMQ, Redis, MinIO, QuestDB, Valkey, plus `database`. |
| `platform` | Backstage, Observability, OpenTelemetry, Vault, Keycloak, Ceph, Longhorn, OpenBao. |
| `templates` | Every individual template fixture. |
| `integrations` | Multi-module dependency scenarios. |
| `rollouts` | Dry-run validation for runtime rollout fixtures. |
| `all` | Basic + templates + integrations + rollouts. |

Only `basic`, `webapp`, and `database` are apply cases. Keep operator/Helm/storage-heavy scenarios dry-run-only unless real controller installation and readiness checks are implemented.

Runtime groups live in `scripts/acceptance_runtime.sh` and use names like `runtime-basic`, `runtime-rollouts`, `runtime-cnpg`, `runtime-keycloak-postgresql`, `runtime-opensearch`, `runtime-dataprepper-opensearch`, `runtime-kafka`, `runtime-mongodb`, `runtime-rabbitmq`, `runtime-redis`, `runtime-search`, `runtime-data`, `runtime-platform`, `runtime-storage`, `runtime-integrations`, and `runtime-all`.

Both dry-run groups and runtime groups must execute selected fixtures one by one and clean successful case resources before continuing. Do not deploy the full template catalog at once; use `--keep-case-resources` only for targeted debugging.

## Dependency Findings

### Data Prepper

- Native Kubernetes resources; no operator.
- Realistic pipelines usually need OpenSearch or another sink.
- Probes require the real Data Prepper runtime, so `pause` images are not valid rollout substitutes.
- Use `dataprepper-opensearch` for IDP-level dependency rendering and future runtime promotion.

### Native controller rollout fixtures

- Use `*-rollout` cases when a template emits native Kubernetes controllers but the real product needs heavyweight startup or backing services.
- Instantiate the real template, then patch only the container runtime/image/command to satisfy generated probes.
- Render patched component resources through `_helpers.wrap_component` and `_helpers.render_component`.
- Register dry-run coverage in `ROLLOUT_CASES` and real rollout coverage in `RUNTIME_ROLLOUT_CASES`.

### Keycloak

- Requires the Keycloak Operator for real reconciliation.
- External PostgreSQL mode also requires a reachable DB and a Secret containing `username` and `password` keys.
- Use `keycloak-postgresql` to validate the rendered relationship with CloudNativePG.

### Persistence and Storage

- Persistent templates need a working StorageClass/provisioner; they do not specifically require Longhorn or Ceph unless configured to use their classes.
- `SingleDatabaseModule` can use local PVs for lightweight kind rollout.
- Longhorn and Ceph fixtures validate StorageClass wiring, not real provisioning.

## Dry-Run CRD Stubs

`framework/tests/acceptance/crds/dry_run_crds.yaml` contains minimal CRDs with `x-kubernetes-preserve-unknown-fields: true` so server-side dry-run can accept custom resources without installing real operators.

When adding a new custom resource kind:

1. Add a minimal CRD stub.
2. Keep the scope/version/plural/group consistent with the generated manifest.
3. Do not treat the stub as production CRD documentation.
4. Validate with `./scripts/acceptance_kind.sh --case <case>`.

## Implementation Checklist

1. Add or modify the KCL fixture in `framework/tests/acceptance/cases/`.
2. Use `.instance` for module schemas.
3. Use `_helpers.render_stack` for multi-module scenarios or `_helpers.wrap_component` for rollout fixtures that patch generated component manifests.
4. Register the case/group in `scripts/acceptance_kind.sh`.
5. Register real deployment checks in `scripts/acceptance_runtime.sh` with an explicit rollout or Ready wait rule.
6. Keep it out of `APPLY_CASES` unless it is a reliable built-in Kubernetes rollout.
7. Update acceptance docs, dependency docs, and runtime docs.
8. Run:

```bash
./scripts/verify.sh
./scripts/acceptance_kind.sh --preflight-only
./scripts/acceptance_kind.sh --case <case-or-group>
./scripts/acceptance_runtime.sh --preflight-only
./scripts/acceptance_runtime.sh --case runtime-basic
```

If Docker/kind is not available, at minimum run `./scripts/verify.sh` and document that cluster acceptance was not executed.

