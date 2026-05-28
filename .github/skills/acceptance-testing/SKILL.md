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
| `platform` | Backstage, Observability, OpenTelemetry, Fluent Bit, Vault, Keycloak, Ceph, Longhorn, OpenBao. |
| `templates` | Every individual template fixture. |
| `integrations` | Multi-module dependency scenarios. |
| `rollouts` | Dry-run + selective apply for runtime rollout fixtures. Includes 17 rollout cases: single-template (`dataprepper-rollout`, `opensearch-dashboards-rollout`, `elasticsearch-rollout`, `kibana-rollout`, `logstash-rollout`, `fluentbit-native-rollout`, `webapp-probes-rollout`, `webapp-service-account-rollout`) and mixture stacks (`webapp-database-stack-rollout`, `elasticsearch-kibana-stack-rollout`, `elk-stack-rollout`, `webapp-dataprepper-stack-rollout`, `webapp-opensearch-dashboards-stack-rollout`, `webapp-elk-stack-rollout`, `dataprepper-elk-stack-rollout`, `webapp-dataprepper-elk-stack-rollout`, `webapp-database-dataprepper-stack-rollout`). |
| `all` | Basic + templates + integrations + rollouts. |

Apply-capable cases (`APPLY_CASES`): `basic`, `webapp`, `database`, `webapp-service-account-rollout`, `webapp-database-stack-rollout`, `elasticsearch-kibana-stack-rollout`, `elk-stack-rollout`, `webapp-dataprepper-stack-rollout`, `webapp-opensearch-dashboards-stack-rollout`, `webapp-elk-stack-rollout`, `dataprepper-elk-stack-rollout`, `webapp-dataprepper-elk-stack-rollout`, `webapp-database-dataprepper-stack-rollout`, `fluentbit-native-rollout`. Keep operator/Helm/storage-heavy scenarios dry-run-only unless real controller installation and readiness checks are implemented.

Runtime groups live in `scripts/acceptance_runtime.sh` and use names like `runtime-basic`, `runtime-rollouts`, `runtime-cnpg`, `runtime-keycloak-postgresql`, `runtime-opensearch`, `runtime-dataprepper-opensearch`, `runtime-kafka`, `runtime-mongodb`, `runtime-rabbitmq`, `runtime-redis`, `runtime-search`, `runtime-data`, `runtime-platform`, `runtime-storage`, `runtime-integrations`, `runtime-webapp-stacks`, and `runtime-all`.

`runtime-rollouts` covers 17 rollout cases (existing 16 verified on kind kindest/node:v1.33.0; run `fluentbit-native-rollout` for the new Fluent Bit path):
- Single-template: `dataprepper-rollout`, `opensearch-dashboards-rollout`, `elasticsearch-rollout`, `kibana-rollout`, `logstash-rollout`, `fluentbit-native-rollout`, `webapp-probes-rollout`, `webapp-service-account-rollout`
- 2-template mixtures: `webapp-database-stack-rollout`, `elasticsearch-kibana-stack-rollout`, `webapp-dataprepper-stack-rollout`, `webapp-opensearch-dashboards-stack-rollout`
- 3-template mixtures: `elk-stack-rollout`, `webapp-elk-stack-rollout`, `dataprepper-elk-stack-rollout`, `webapp-database-dataprepper-stack-rollout`
- 4-template mixture: `webapp-dataprepper-elk-stack-rollout`

`runtime-integrations` covers webapp-operator stack integration cases: `webapp-postgresql-stack`, `webapp-kafka-stack`, `webapp-rabbitmq-stack`, `webapp-redis-stack`, `webapp-mongodb-stack`.

Both dry-run groups and runtime groups must execute selected fixtures one by one and clean successful case resources before continuing. Do not deploy the full template catalog at once; use `--keep-case-resources` only for targeted debugging.

## Dependency Findings

### Data Prepper

- Native Kubernetes resources; no operator.
- Realistic pipelines usually need OpenSearch or another sink.
- Probes require the real Data Prepper runtime, so `pause` images are not valid rollout substitutes.
- Use `dataprepper-opensearch` for IDP-level dependency rendering and future runtime promotion.

### Fluent Bit

- Native mode (`fluentbit-native`, `fluentbit-native-rollout`) renders built-in Kubernetes resources only and can be promoted to lightweight apply without Helm or operator dependencies.
- Helm mode (`fluentbit-helm`) requires Flux/Helm reconciliation for runtime tests.
- Operator mode (`fluentbit-operator`) requires Flux plus Fluent Operator CRDs/controller.
- Use `templates.observability.v1_0_0.telemetry_config.LogPipelineSpec` to keep pipeline shape consistent across Fluent Bit, Data Prepper, and OpenTelemetry fixtures.

### WebApp probe rollout (`webapp-probes-rollout`)

- `WebAppModule` supports `livenessProbe`, `readinessProbe`, and `startupProbe` fields of type `ProbeSpec`.
- For kind-based rollouts set `probeType = "http"` and use a Python `BaseHTTPRequestHandler` that serves all probe paths; patch the generated Deployment container via `_patch` + `wrap_component`.
- Adjust `initialDelaySeconds`/`periodSeconds` downward in the patch so the lightweight server is probed quickly.
- **Do not** rely on the `pause` image for probe-based rollouts; `pause` does not start an HTTP or TCP listener.

### WebApp ServiceAccount rollout (`webapp-service-account-rollout`)

- Setting `imagePullSecretName` on `WebAppModule` auto-generates a `ServiceAccount` with an `imagePullSecrets` entry and wires it to the Deployment via `serviceAccountName`.
- For kind-based acceptance without a real registry secret, patch `imagePullSecrets = []` on both the `ServiceAccount` and the pod spec (`spec.template.spec.imagePullSecrets`).
- The `serviceAccountName` binding is preserved so the feature is still exercised under rollout.
- The `pause` image works here because no HTTP probes are configured.

### Multi-module mixture rollout (`webapp-database-stack-rollout`)

- Use `_helpers.render_stack([_namespace], [component_instance], [accessory_instance])` to assemble a multi-module IDP stack into one manifest.
- The mixture fixture co-deploys `WebAppModule` and `SingleDatabaseModule` in the same namespace.
- The database uses `createLocalPersistentVolume = True` + `storageHostPath = "/tmp/idp-acceptance"` so the PVC binds in kind without Longhorn or Ceph.
- `wait_case` for this fixture must wait for **both** Deployments (`acceptance-stack-webapp` and `acceptance-stack-db`) and then `wait_all_pvcs_bound`.
- The webapp passes `env = [{name = "DB_HOST", value = "<db-service-name>"}]` to document cross-module wiring without creating a real network dependency.

### ELK / search stack mixture rollouts

Multi-template search-stack rollouts use `render_stack` with multiple `ComponentInstance` objects assembled via `wrap_component`. All produce real native Kubernetes manifests without operator dependencies.

| Fixture | Templates | Workload types | Key points |
|---|---|---|---|
| `elasticsearch-kibana-stack-rollout` | `ElasticsearchModule` + `KibanaModule` (v7) | `StatefulSet` + `Deployment` in same namespace | Kibana `elasticsearchHosts` wired to ES Service name. ✓ kind verified |
| `elk-stack-rollout` | `ElasticsearchModule` + `KibanaModule` + `LogstashModule` (v7) | `StatefulSet` + two `Deployment`s + all PDBs | Logstash pipeline points at ES; full ELK trio in one namespace. ✓ kind verified |
| `webapp-elk-stack-rollout` | `WebAppModule` + `ElasticsearchModule` + `KibanaModule` (v7) | `Deployment` + `StatefulSet` + `Deployment` | App + search-backend + visualization. ES PVCs bound via kind default provisioner. ✓ kind verified |
| `dataprepper-elk-stack-rollout` | `DataPrepperModule` + `ElasticsearchModule` + `KibanaModule` (v7) | `Deployment` + `StatefulSet` + `Deployment` | Log-ingestion + search + visualization pipeline. ✓ kind verified |
| `webapp-dataprepper-elk-stack-rollout` | `WebAppModule` + `DataPrepperModule` + `ElasticsearchModule` + `KibanaModule` (v7) | 3 `Deployment`s + 1 `StatefulSet` | Largest native mixture: 4 templates, 4 workloads, 3 PVCs. ✓ kind verified |

Python runtime servers used on native ports: ES 9200 (HTTP) + 9300 (TCP), Kibana 5601, Logstash 9600, DataPrepper 4900.
`_patch_es` patches `StatefulSet`; `_patch_kibana`/`_patch_logstash`/`_patch_dp` patch `Deployment`s.
`wait_all_rollouts` handles mixed WorkloadTypes via `kubectl get deploy,statefulset,daemonset`.

### App + collector pipeline mixture rollout (`webapp-dataprepper-stack-rollout`)

- Co-deploys `WebAppModule` + `DataPrepperModule` in one namespace via `render_stack`.
- The webapp uses the `pause` image (no live probes); Data Prepper is patched to a Python HTTP server.
- Cross-module wiring: webapp env `LOG_ENDPOINT` points at the Data Prepper Service.
- Tests the app + sidecar/collector IDP stack pattern — two `Deployment`s, no storage dependencies.

### App + visualization stack mixture rollout (`webapp-opensearch-dashboards-stack-rollout`)

- Co-deploys `WebAppModule` + `OpenSearchDashboardsModule` in one namespace via `render_stack`.
- OpenSearch Dashboards patched to a Python HTTP server on port 5601.
- No real Dashboards process or backing OpenSearch required for rollout proof.
- Cross-module wiring: webapp env `SEARCH_UI` points at the Dashboards Service.

### Three-tier app mixture rollout (`webapp-database-dataprepper-stack-rollout`)

- Co-deploys `WebAppModule` + `SingleDatabaseModule` + `DataPrepperModule` in one namespace.
- Database uses `createLocalPersistentVolume = True` + `storageHostPath = "/tmp/idp-acceptance"` for PVC binding.
- Data Prepper patched to Python HTTP server on port 4900.
- Cross-module env: `DB_HOST` (app → DB service), `LOG_ENDPOINT` (app → DataPrepper service).
- `wait_case` must wait for all three Deployments plus `wait_all_pvcs_bound`.

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

