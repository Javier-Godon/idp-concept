# Acceptance Testing with kind

This project keeps fast KCL tests as the default verification path and adds optional Kubernetes acceptance tests for changes that affect generated manifest runtime behavior.

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

The default case is intentionally small and deploys a generated `Namespace`, `ConfigMap`, `Deployment`, and `Service` using framework builders.

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

Run all currently defined cases:

```bash
./scripts/acceptance_kind.sh --case all
```

Run only the search-family dry-run cases:

```bash
./scripts/acceptance_kind.sh --case search
```

Keep the cluster for debugging:

```bash
./scripts/acceptance_kind.sh --case basic --keep-cluster
```

Reuse an existing cluster/context:

```bash
./scripts/acceptance_kind.sh --skip-create --case basic
```

## Current cases

| Case | Fixture | What it proves | Applies resources? | Default? |
|---|---|---|---|---|
| `basic` | `framework/tests/acceptance/cases/basic_workload.k` | Framework-generated core Kubernetes resources can be created and a Deployment rolls out | Yes | Yes |
| `webapp` | `framework/tests/acceptance/cases/webapp_workload.k` | `WebAppModule` root import renders Deployment, Service, and ConfigMap and rolls out with a tiny image | Yes | No |
| `database` | `framework/tests/acceptance/cases/database_workload.k` | `SingleDatabaseModule` root import renders Deployment, Service, PV, and PVC and rolls out with a local PV | Yes | No |
| `dataprepper` | `framework/tests/acceptance/cases/dataprepper_workload.k` | Data Prepper standalone generated resources can be applied and rolled out | Yes | No |
| `opensearch-dashboards` | `framework/tests/acceptance/cases/opensearch_dashboards_workload.k` | OpenSearch Dashboards standalone manifests pass server-side dry-run | Dry-run only | No |
| `elasticsearch` | `framework/tests/acceptance/cases/elasticsearch_workload.k` | Elasticsearch OSS StatefulSet/Service/ConfigMap/PDB manifests pass server-side dry-run | Dry-run only | No |
| `kibana` | `framework/tests/acceptance/cases/kibana_workload.k` | Kibana OSS Deployment/Service/ConfigMap/PDB manifests pass server-side dry-run | Dry-run only | No |
| `logstash` | `framework/tests/acceptance/cases/logstash_workload.k` | Logstash OSS Deployment/Service/ConfigMap/PDB manifests pass server-side dry-run | Dry-run only | No |

Dry-run-only cases still render the KCL fixture, create the namespace, and run
`kubectl apply --dry-run=server`; they skip the final apply because those images
are heavier or expect backing services.

## Suggested future acceptance groups

These are intentionally not default because they require CRDs, operators, more memory, or longer pull/startup times.

| Group | Prerequisites | Suggested checks |
|---|---|---|
| `opensearch-operator` | OpenSearch operator installed | Apply `OpenSearchCluster`, wait for health/Ready condition |
| `dataprepper-opensearch` | OpenSearch operator + OpenSearch cluster | Apply Data Prepper pipeline pointing at OpenSearch, send sample event, query index |
| `postgres-keycloak` | CloudNativePG + Keycloak operators | Deploy PostgreSQL + Keycloak, wait for both Ready |
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
- run heavier cases in nightly CI or before releases

