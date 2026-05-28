# Template Acceptance Dependencies

This document records the runtime dependencies discovered while expanding acceptance coverage for framework templates. All fixtures in `framework/tests/acceptance/cases/*_workload.k` render through the IDP path:

```text
template/module instance(s) -> RenderStack -> procedures.kcl_to_yaml.yaml_stream_stack
```

## Acceptance levels

| Level | What it proves | Command path | Notes |
|---|---|---|---|
| L0 render | KCL compiles and the IDP render path emits YAML | `./scripts/verify.sh` | Runs for every `*_workload.k` fixture. No Kubernetes API involved. |
| L1 server dry-run | Kubernetes API accepts built-in resources and CR shapes when CRDs exist | `./scripts/acceptance_kind.sh --case <case>` | Dry-run-only cases install lightweight CRD stubs from `framework/tests/acceptance/crds/dry_run_crds.yaml`. Stubs do not reconcile. |
| L2 lightweight apply | Built-in Kubernetes resources roll out in kind | `basic`, `webapp`, `database` | No external operators required. `database` uses a local PV for kind. |
| L3 operator-backed apply | Real operators/controllers reconcile custom resources | `./scripts/acceptance_runtime.sh --case <runtime-group>` | Requires installing real operators, waiting for Ready conditions, and often more CPU/memory/time. |
| L4 integration behavior | Dependent services exchange traffic successfully | `./scripts/acceptance_runtime.sh --case runtime-integrations` | Example: send an event to Data Prepper and query OpenSearch, or log into Keycloak backed by PostgreSQL. |

See `docs/ACCEPTANCE_RUNTIME.md` for the real deployment runner and runtime groups.

## Important dependency findings

### Data Prepper and OpenSearch

- `DataPrepperModule` generates native Kubernetes `ConfigMap`, `Service`, `Deployment`, and optional `PodDisruptionBudget` resources. It does **not** require an operator.
- Data Prepper can render and start with pipelines that do not use OpenSearch, for example a `stdout` sink.
- A useful ingestion pipeline commonly needs a reachable OpenSearch endpoint. The `dataprepper-opensearch` fixture wires a Data Prepper pipeline to `http://acceptance-opensearch:9200` and includes an `OpenSearchClusterModule` in the same `RenderStack`.
- Real L3/L4 validation requires the OpenSearch Kubernetes Operator to reconcile `OpenSearchCluster`, the cluster to become healthy, and Data Prepper probes to pass against the real Data Prepper runtime.
- Because the Data Prepper template has real HTTP probes on its metrics port, replacing the image with `pause` is not a reliable rollout test. Keep Data Prepper dry-run-only unless the actual runtime is used.

### Fluent Bit deployment modes

- `FluentBitSingleInstanceModule` and `FluentBitDaemonSetModule` generate native Kubernetes `ConfigMap`, `Service`, and `Deployment`/`DaemonSet` resources. They do not require Helm or an operator for L2 rollout.
- `FluentBitHelmSpec` emits a Flux `HelmRelease` for the official Fluent Bit chart and needs Flux/Helm reconciliation for real runtime testing.
- `FluentBitOperatorModule` emits a Flux `HelmRelease` for Fluent Operator plus Fluent Operator CRs (`FluentBit`, `ClusterFluentBitConfig`, `ClusterInput`, `ClusterOutput`). Runtime testing needs Flux and the Fluent Operator CRDs/controller.
- `fluentbit-native-rollout` validates the native single-instance path with the pinned Fluent Bit image and a stdout pipeline; it avoids Helm/operator dependencies.

### Keycloak and PostgreSQL

- `KeycloakModule` generates Keycloak Operator CRs (`Keycloak`, and optionally `KeycloakRealmImport`). The module can render without database fields, but persistent production-style deployments should use an external database.
- When `databaseVendor = "postgres"` is configured, Keycloak needs:
  - a reachable PostgreSQL host/port,
  - a database name,
  - a Secret with `username` and `password` keys referenced by `databaseSecretName`,
  - the Keycloak Operator to reconcile the `Keycloak` CR.
- `PostgreSQLClusterModule` generates CloudNativePG CRs (`Cluster`, optional `ScheduledBackup`, optional `Pooler`). It needs the CloudNativePG operator and a usable StorageClass for real persistence.
- The `keycloak-postgresql` fixture renders both modules in one `RenderStack` and points Keycloak at the CloudNativePG read/write service name pattern (`<clusterName>-rw`). It is dry-run-only until real CNPG and Keycloak operators are installed.
- Do not hardcode database passwords in fixtures. Runtime tests should create credentials through a secret-management flow or let the database operator generate them when supported.

### Persistent workloads and storage providers

Persistent templates need a Kubernetes storage provisioner when they create PVCs or operator CRs that create PVCs. They do **not** specifically require Longhorn or Ceph unless their StorageClass is selected.

| Template | Persistence field(s) | Storage requirement for real L3 apply |
|---|---|---|
| `SingleDatabaseModule` | `storageClassName`, `createLocalPersistentVolume` | Can use local PV for dev/kind (`createLocalPersistentVolume = True`), or any dynamic StorageClass when local PV is disabled. Defaults to `rook-ceph-block` if no config override is provided. |
| `PostgreSQLClusterModule` | `storageClass`, `walStorageClass` | CloudNativePG operator plus a default or named StorageClass. |
| `MongoDBCommunityModule` | `storageClassName` | MongoDB Community Operator plus a default or named StorageClass. |
| `RabbitMQClusterModule` | `storageClassName` | RabbitMQ Cluster Operator plus a default or named StorageClass. |
| `RedisModule` / `RedisClusterModule` | `storageClassName` | Redis Operator plus a default or named StorageClass. |
| `MinIOTenantSpec` | `storageClassName` | MinIO Tenant CRD/operator plus a default or named StorageClass. |
| `MinIOHelmSpec` | `storageClassName` | Flux/Helm controller plus a default or named StorageClass. |
| `ValkeyModule` | `storageClassName` | Flux/Helm controller plus a default or named StorageClass. Defaults to `rook-ceph-block`. |

### Longhorn-backed persistence

- `LonghornModule` renders a Flux `HelmRelease` and a `StorageClass` using provisioner `driver.longhorn.io`.
- Real Longhorn-backed persistence requires:
  - Flux/Helm reconciliation for `HelmRelease`, or equivalent Helm installation,
  - Longhorn components and CSI driver ready,
  - nodes/directories compatible with Longhorn storage requirements,
  - the generated StorageClass present before dependent PVCs bind.
- The `persistence-longhorn` fixture renders Longhorn plus representative persistent workloads using the Longhorn StorageClass. It proves the IDP composition and Kubernetes API shape via dry-run, not actual volume provisioning.

### Ceph/Rook-backed persistence

- `CephModule` renders a Flux `HelmRelease`, `CephCluster`, `CephBlockPool`, and `StorageClass` using provisioner `rook-ceph.rbd.csi.ceph.com`.
- Real Ceph-backed persistence requires:
  - Flux/Helm reconciliation for the Rook operator,
  - Rook CRDs and operator ready,
  - a healthy `CephCluster`, monitor/mgr pods, CSI sidecars, and required secrets,
  - a ready `CephBlockPool` and generated StorageClass before dependent PVCs bind.
- The `persistence-ceph` fixture renders Ceph plus representative persistent workloads using the Ceph StorageClass. It is dry-run-only because a real Ceph cluster is too heavy for default local acceptance.

## Scenario fixtures

| Case | What it renders | Real prerequisites beyond L1 dry-run |
|---|---|---|
| `dataprepper-opensearch` | `DataPrepperModule` + `OpenSearchClusterModule` | OpenSearch operator, healthy OpenSearch cluster, real Data Prepper image/runtime. |
| `keycloak-postgresql` | `KeycloakModule` + `PostgreSQLClusterModule` | Keycloak Operator, CloudNativePG, DB credentials Secret, working StorageClass. |
| `persistence-longhorn` | Longhorn + representative PVC-producing templates | Flux/Helm controller or Helm install, Longhorn CSI/provisioner, Longhorn StorageClass ready. |
| `persistence-ceph` | Rook Ceph + representative PVC-producing templates | Flux/Helm controller or Helm install, Rook/Ceph ready, CephBlockPool/CSI secrets/StorageClass ready. |
| `webapp-postgresql-stack` | `WebAppModule` + `PostgreSQLClusterModule` | CloudNativePG operator plus working StorageClass. Dry-run-only without operator. |
| `webapp-kafka-stack` | `WebAppModule` + `KafkaClusterModule` | Strimzi Kafka operator plus working StorageClass. Dry-run-only without operator. |
| `webapp-rabbitmq-stack` | `WebAppModule` + `RabbitMQClusterModule` | RabbitMQ Cluster operator plus working StorageClass. Dry-run-only without operator. |
| `webapp-redis-stack` | `WebAppModule` + `RedisModule` | OT Redis operator plus working StorageClass. Dry-run-only without operator. |
| `webapp-mongodb-stack` | `WebAppModule` + `MongoDBCommunityModule` | MongoDB Community operator plus working StorageClass. Dry-run-only without operator. |
| `fluentbit-native` | `FluentBitSingleInstanceModule` native resources | None beyond built-in Kubernetes resources; use `fluentbit-native-rollout` for L2 rollout. |
| `fluentbit-helm` | `FluentBitHelmSpec` HelmRelease | Flux/Helm controller. |
| `fluentbit-operator` | `FluentBitOperatorModule` + Fluent Operator CRs | Flux/Helm controller plus Fluent Operator CRDs/controller. |

## Runtime rollout fixtures

The `*-rollout` fixtures are a targeted L2/L3 bridge for native Kubernetes
controllers. They keep the template-generated resource set and probes, but patch
only the workload container to a pinned lightweight HTTP runtime so kind can
prove the generated `Deployment`/`StatefulSet` rolls out without installing the
full backing product stack.

| Case | Template resource under test | Runtime dependency avoided |
|---|---|---|
| `dataprepper-rollout` | `DataPrepperModule` `Deployment` | Full Data Prepper JVM startup and downstream sink. |
| `opensearch-dashboards-rollout` | `OpenSearchDashboardsModule` `Deployment` | Backing OpenSearch endpoint. |
| `elasticsearch-rollout` | Elastic v7 `ElasticsearchModule` `StatefulSet` | Full Elasticsearch cluster runtime while still testing StatefulSet/PVC rollout shape. |
| `kibana-rollout` | Elastic v7 `KibanaModule` `Deployment` | Backing Elasticsearch endpoint. |
| `logstash-rollout` | Elastic v7 `LogstashModule` `Deployment` | Full Logstash JVM startup and upstream/downstream services. |
| `fluentbit-native-rollout` | Fluent Bit native `FluentBitSingleInstanceModule` `Deployment` | Helm controller and Fluent Operator; uses generated stdout pipeline with the pinned Fluent Bit runtime. |
| `webapp-probes-rollout` | `WebAppModule` `Deployment` with HTTP liveness, readiness, and startup probes | Real application runtime. Uses a Python HTTP server to satisfy all three generated probe paths on port 8080. Proves that probe configuration fields (`livenessProbe`, `readinessProbe`, `startupProbe`) render into valid Kubernetes probe specs and that the generated container can pass them. |
| `webapp-service-account-rollout` | `WebAppModule` `Deployment` + `ServiceAccount` generated via `imagePullSecretName` | A real registry and pull secret. `imagePullSecrets` is patched to an empty list so the rollout proceeds with the `pause` image while keeping the `serviceAccountName` binding. Proves: ServiceAccount generation, SA-to-Deployment wiring, and imagePullSecrets patching pattern. |
| `webapp-database-stack-rollout` | **Mixture**: `WebAppModule` `Deployment` + `SingleDatabaseModule` `Deployment` + `PVC` in one `RenderStack` | External storage provisioner. Uses a local hostPath `PersistentVolume` so the PVC binds without Longhorn or Ceph. Proves: multi-module IDP stack rendering via `render_stack`, two co-deployed Deployments rolling out simultaneously, and PVC binding alongside a webapp in the same namespace. ✓ kind verified |
| `elasticsearch-kibana-stack-rollout` | **Mixture**: `ElasticsearchModule` `StatefulSet` + `KibanaModule` `Deployment` (v7) | External storage provisioner for ES PVCs — kind default provisioner works. Proves: mixed workload-type stack (StatefulSet+Deployment) in one namespace. ✓ kind verified |
| `elk-stack-rollout` | **Mixture**: `ElasticsearchModule` + `KibanaModule` + `LogstashModule` (v7) | Same as above, plus Logstash Deployment. Proves 3-component search stack. ✓ kind verified |
| `webapp-dataprepper-stack-rollout` | **Mixture**: `WebAppModule` + `DataPrepperModule` | No operator needed. Proves app + collector stack pattern. ✓ kind verified |
| `webapp-opensearch-dashboards-stack-rollout` | **Mixture**: `WebAppModule` + `OpenSearchDashboardsModule` | No operator needed. Proves app + visualization layer stack without backing OpenSearch. ✓ kind verified |
| `webapp-elk-stack-rollout` | **Mixture**: `WebAppModule` + `ElasticsearchModule` + `KibanaModule` (v7) | ES PVCs — kind default provisioner works. 3-component: app + backend + visualization. ✓ kind verified |
| `dataprepper-elk-stack-rollout` | **Mixture**: `DataPrepperModule` + `ElasticsearchModule` + `KibanaModule` (v7) | ES PVCs — kind default provisioner works. Log-ingestion + search + visualization pipeline. ✓ kind verified |
| `webapp-dataprepper-elk-stack-rollout` | **Mixture**: `WebAppModule` + `DataPrepperModule` + `ElasticsearchModule` + `KibanaModule` (v7) | ES PVCs — kind default provisioner works. Largest native mixture: 4 components, 3 Deployments + 1 StatefulSet. ✓ kind verified |
| `webapp-database-dataprepper-stack-rollout` | **Mixture**: `WebAppModule` + `SingleDatabaseModule` + `DataPrepperModule` | Local hostPath PV for DB PVC. Three-tier app: persistence + log-collection. ✓ kind verified |

Run the real rollout group with:

```bash
./scripts/acceptance_runtime.sh --case runtime-rollouts --timeout 600s
```

These fixtures do not replace full product integration tests. Use non-rollout
runtime cases with real operators/controllers for end-to-end behavior.

Run all dependency-oriented scenario fixtures with:

```bash
./scripts/acceptance_kind.sh --case integrations
```

Run one scenario while iterating:

```bash
./scripts/acceptance_kind.sh --case dataprepper-opensearch
./scripts/acceptance_kind.sh --case keycloak-postgresql
./scripts/acceptance_kind.sh --case persistence-longhorn
./scripts/acceptance_kind.sh --case persistence-ceph
```

## Rules for future acceptance fixtures

1. Keep every fixture on the IDP render path by using `_helpers.render_component`, `_helpers.render_accessory`, or `_helpers.render_stack`.
2. Prefer L0/L1/L2 checks for default developer workflows; put real operator-backed L3/L4 checks behind opt-in/nightly jobs.
3. Do not hardcode credentials. Use Secret references, generated operator credentials, or external secret-management fixtures.
4. If a fixture references custom resources, add only minimal dry-run CRD stubs for L1 validation; do not treat stubs as production CRDs.
5. If a fixture uses a named StorageClass, include or document the storage provider that must create it before PVCs can bind.
6. Use pinned versions for images, charts, and operator CRs. Never use `latest`.

