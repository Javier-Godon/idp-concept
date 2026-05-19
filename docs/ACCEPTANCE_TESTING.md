# Acceptance Testing with kind

This project keeps fast KCL tests as the default verification path and adds optional Kubernetes acceptance tests for changes that affect generated manifest runtime behavior.

There are two cluster-oriented layers:

- `./scripts/acceptance_kind.sh` — render + server-side dry-run matrix, with real apply only for lightweight built-in Kubernetes cases.
- `./scripts/acceptance_runtime.sh` — opt-in real deployment layer that applies manifests without CRD stubs and waits for rollouts or operator Ready conditions.

Use `docs/ACCEPTANCE_RUNTIME.md` for the real deployment layer.

## Design borrowed from similar platform projects

Common patterns used by Kubernetes operators, Helm chart projects, Crossplane packages, and platform frameworks:

1. **Testing pyramid** — keep most tests as fast unit/contract tests; run cluster tests only for selected scenarios.
2. **Ephemeral cluster per run** — use `kind` or similar single-node clusters for isolation and reproducibility.
3. **Server-side dry-run before apply** — catch API/schema errors before creating resources.
4. **Curated smoke matrix** — do not deploy every infrastructure product on every PR; pick representative lightweight cases and run heavy cases on demand/nightly.
5. **Operator preflight** — CRD/operator-backed resources should be applied only when the relevant CRDs/operators are installed.
6. **Group tests when dependencies matter** — e.g. Keycloak + PostgreSQL, Data Prepper + OpenSearch, dashboards + OpenSearch.

## Script

```bash
./scripts/acceptance_kind.sh
```

Default behavior:

- creates a disposable `kind` cluster
- renders a KCL fixture to YAML
- runs `kubectl apply --dry-run=server`
- applies the manifest
- waits for rollout
- deletes the cluster on exit

The default case is intentionally small and deploys a generated `Namespace`, `ConfigMap`, `Deployment`, and `Service` using framework builders. Template cases render through `procedures.kcl_to_yaml.yaml_stream_stack`, so they exercise the same IDP stack-to-manifest path used by project factories.

When a group is selected, the runner processes cases one by one. It renders and validates one fixture, applies only the lightweight apply-capable cases, then deletes that case's resources before moving to the next fixture. This keeps `templates`, `integrations`, and `all` from deploying the whole catalog at once.

## Prerequisites

- Docker
- kind
- kubectl
- kcl

Check prerequisites without creating a cluster:

```bash
./scripts/acceptance_kind.sh --preflight-only
```

## Run the default lightweight case

```bash
./scripts/acceptance_kind.sh
```

## Run heavier opt-in cases

```bash
./scripts/acceptance_kind.sh --case dataprepper
```

Run every template acceptance case (all template families, mostly server-side dry-run):

```bash
./scripts/acceptance_kind.sh --case templates
```

Run dependency-oriented scenario cases such as Data Prepper + OpenSearch,
Keycloak + PostgreSQL, and persistence workloads against Longhorn/Ceph storage
classes:

```bash
./scripts/acceptance_kind.sh --case integrations
```

Run the rollout fixture shapes through render + server-side dry-run:

```bash
./scripts/acceptance_kind.sh --case rollouts
```

Run all cases, including the basic builder smoke and every template case:

```bash
./scripts/acceptance_kind.sh --case all
```

Keep the cluster for debugging:

```bash
./scripts/acceptance_kind.sh --case basic --keep-cluster
```

Keep case resources for debugging instead of deleting them after each successful case:

```bash
./scripts/acceptance_kind.sh --case webapp --keep-cluster --keep-case-resources
```

Reuse an existing cluster/context:

```bash
./scripts/acceptance_kind.sh --skip-create --case basic
```

## Current cases

`./scripts/verify.sh` renders every `framework/tests/acceptance/cases/*_workload.k` fixture as a fast compile/render gate. `./scripts/acceptance_kind.sh` adds Kubernetes server-side dry-run for selected cases and applies only the lightweight cases that can roll out without extra operators/controllers.

| Group / Case | Scope | Applies resources? | Notes |
|---|---|---|---|
| `basic` | Builder-generated Namespace/ConfigMap/Deployment/Service | Yes | Default smoke case |
| `webapp` | `WebAppModule` | Yes | Tiny pause image rollout |
| `database` | `SingleDatabaseModule` | Yes | Local PV/PVC + tiny pause image rollout |
| `dataprepper` | `DataPrepperModule` | Dry-run only | Probes require the real Data Prepper runtime; run full runtime tests with backing dependencies separately |
| `search` | `opensearch`, `opensearch-dashboards`, Elastic v7 `elasticsearch`/`kibana`/`logstash`, Elastic v9 ECK CRs | Dry-run only | Uses CRD stubs for operator-backed v9/OpenSearch CRs |
| `data` | `database`, `postgresql`, `mongodb`, `rabbitmq`, `redis`, `redis-cluster`, `kafka`, `minio-tenant`, `minio-helm`, `questdb`, `valkey` | Mixed | `database` applies; operator/Helm-backed cases dry-run only |
| `platform` | `backstage`, `observability`, `opentelemetry`, `vault`, `keycloak`, `ceph`, `longhorn`, `openbao` | Dry-run only | Requires Helm/Flux, CRDs, or operators for real reconciliation |
| `templates` | Every template acceptance fixture | Mixed | Full template coverage through the IDP render path |
| `integrations` | `dataprepper-opensearch`, `keycloak-postgresql`, `persistence-longhorn`, `persistence-ceph` | Dry-run only | Dependency scenarios that include related modules in one `RenderStack` |
| `rollouts` | `dataprepper-rollout`, `opensearch-dashboards-rollout`, `elasticsearch-rollout`, `kibana-rollout`, `logstash-rollout` | Dry-run only in this runner | Runtime-rollout fixtures for native Kubernetes controllers; use `./scripts/acceptance_runtime.sh --case runtime-rollouts` for real rollout checks |
| `all` | `basic` + `templates` + `integrations` + `rollouts` | Mixed | Complete local acceptance matrix |

Individual cases can also be selected with repeated `--case`, for example:

```bash
./scripts/acceptance_kind.sh --case kafka --case postgresql --case opentelemetry
```

Dry-run-only cases install lightweight acceptance CRD stubs from `framework/tests/acceptance/crds/dry_run_crds.yaml` so `kubectl apply --dry-run=server` can validate generated custom resources without requiring the real operators. These stubs are only for acceptance validation; they are not production CRDs and do not reconcile workloads.

See `docs/ACCEPTANCE_DEPENDENCIES.md` for the dependency matrix behind these cases, including when Data Prepper needs OpenSearch, when Keycloak needs PostgreSQL, and when persistent templates require Longhorn, Ceph, or another StorageClass provider.

## Suggested future acceptance groups

These are intentionally not default because they require CRDs, operators, more memory, or longer pull/startup times.

| Group | Prerequisites | Suggested checks |
|---|---|---|
| `opensearch-operator` | OpenSearch operator installed | Apply `OpenSearchCluster`, wait for health/Ready condition |
| `dataprepper-opensearch-runtime` | OpenSearch operator + OpenSearch cluster | Apply Data Prepper pipeline pointing at OpenSearch, send sample event, query index |
| `postgres-keycloak-runtime` | CloudNativePG + Keycloak operators | Deploy PostgreSQL + Keycloak, wait for both Ready |
| `elastic-eck-v9` | ECK installed and license accepted | Apply Elasticsearch/Kibana/Logstash v9.4.1 CRs, wait for Ready |
| `helm-storage` | Flux/Helm provider or Helm CLI, storage class | Deploy a Helm-backed storage/cache template and validate PVC binding |

## Why not deploy everything on every run?

Many infrastructure systems are expensive in CI:

- image pulls can be large
- operators require CRDs and controllers
- databases/search clusters need memory and time
- readiness can be slow or environment-dependent

The recommended approach is:

- run `./scripts/verify.sh` on every PR
- run `./scripts/acceptance_kind.sh --case basic` for manifest-runtime changes
- run `./scripts/acceptance_runtime.sh --case runtime-basic` when you need to prove real lightweight deployments still roll out
- run `./scripts/acceptance_runtime.sh --case runtime-rollouts --timeout 300s` when changing native Deployment/StatefulSet templates such as Data Prepper, OpenSearch Dashboards, Elasticsearch v7, Kibana v7, or Logstash v7
- run heavier cases in nightly CI or before releases

For true operator-backed deployment verification, use `./scripts/acceptance_runtime.sh --case <runtime-group>` against a cluster with real operators/controllers installed, or pass `--install-dependencies` for disposable kind/nightly runs where the runner should install known pinned dependencies.

