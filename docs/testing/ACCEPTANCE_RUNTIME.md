# Runtime Acceptance Testing

This is the second acceptance layer beyond the fast render/dry-run matrix.

The existing `./scripts/acceptance_kind.sh` validates that fixtures render through the IDP path and that Kubernetes accepts their shapes with server-side dry-run. Runtime acceptance uses `./scripts/acceptance_runtime.sh` and is intentionally stricter:

```text
fixture -> IDP RenderStack render -> kubectl apply -> real controller/operator reconciliation -> rollout/Ready checks
```

No lightweight CRD stubs are installed in this layer. If a template emits a custom resource, the real CRD and controller must exist, otherwise the test fails. This is how we prove that deployments really work rather than only that manifests can be generated.

Runtime groups are intentionally **one-by-one**. The runner applies one fixture, waits for runtime readiness, then deletes that fixture's resources before moving to the next fixture. This avoids deploying the full template catalog at once and protects local hardware.

## Commands

Check local tools only:

```bash
./scripts/acceptance_runtime.sh --preflight-only
```

Run the lightweight runtime group:

```bash
./scripts/acceptance_runtime.sh --case runtime-basic
```

Run rollout-focused runtime checks for native Kubernetes search/ingestion
templates without installing heavy backing services:

```bash
./scripts/acceptance_runtime.sh --case runtime-rollouts --timeout 300s
```

Run a specific runtime case against an existing cluster that already has dependencies installed:

```bash
./scripts/acceptance_runtime.sh --skip-create --case postgresql
```

Ask the runner to install known real dependencies before applying cases:

```bash
./scripts/acceptance_runtime.sh --case runtime-cnpg --install-dependencies
```

Keep the kind cluster for debugging:

```bash
./scripts/acceptance_runtime.sh --case runtime-basic --keep-cluster
```

Keep each case's resources for debugging instead of cleaning them after success:

```bash
./scripts/acceptance_runtime.sh --case postgresql --keep-cluster --keep-case-resources
```

## Runtime groups

| Group | Cases | What it proves |
|---|---|---|
| `runtime-basic` | `basic`, `webapp`, `database` | Built-in Kubernetes resources apply and roll out in kind. |
| `runtime-rollouts` | `dataprepper-rollout`, `opensearch-dashboards-rollout`, `elasticsearch-rollout`, `kibana-rollout`, `logstash-rollout`, `fluentbit-native-rollout`, `webapp-probes-rollout`, `webapp-service-account-rollout`, `webapp-database-stack-rollout`, `elasticsearch-kibana-stack-rollout`, `elk-stack-rollout`, `webapp-dataprepper-stack-rollout`, `webapp-opensearch-dashboards-stack-rollout`, `webapp-elk-stack-rollout`, `dataprepper-elk-stack-rollout`, `webapp-dataprepper-elk-stack-rollout`, `webapp-database-dataprepper-stack-rollout` | Template-generated native `Deployment`/`StatefulSet` resources apply and roll out in kind. The search/ingestion/Fluent Bit fixtures use lightweight runtime containers or native images that satisfy generated probes. The webapp/mixture fixtures use `pause` or Python images to prove probe configuration, ServiceAccount wiring, and multi-module stack rollout without heavy backing services. Stack rollout fixtures co-deploy multiple native templates in a single `RenderStack` via `render_stack`. Existing 16 cases verified on kind (kindest/node:v1.33.0); run `fluentbit-native-rollout` to validate the new Fluent Bit native path. |
| `runtime-cnpg` | `postgresql` | CloudNativePG reconciles the PostgreSQL `Cluster` CR to Ready. |
| `runtime-keycloak-postgresql` | `keycloak-postgresql` | CloudNativePG and Keycloak Operator reconcile a persistent Keycloak stack. |
| `runtime-opensearch` | `opensearch` | OpenSearch Operator reconciles `OpenSearchCluster` to Ready. |
| `runtime-dataprepper-opensearch` | `dataprepper-opensearch` | OpenSearch is Ready and Data Prepper rolls out against a real runtime image. |
| `runtime-kafka` | `kafka` | Strimzi reconciles Kafka and topics. |
| `runtime-mongodb` | `mongodb` | MongoDB Community Operator reconciles `MongoDBCommunity`. |
| `runtime-rabbitmq` | `rabbitmq` | RabbitMQ Cluster Operator reconciles `RabbitmqCluster`. |
| `runtime-redis` | `redis`, `redis-cluster` | Redis Operator reconciles standalone and clustered Redis CRs. |
| `runtime-search` | OpenSearch, OpenSearch Dashboards, Data Prepper + OpenSearch, Elastic v7, Elastic v9 | Search-family workloads and operators are reconciled. |
| `runtime-data` | Database/data fixtures | Data services reconcile or roll out with real dependencies. |
| `runtime-platform` | Backstage, Observability, OpenTelemetry, Vault, Keycloak, OpenBao | Platform/security/observability templates reconcile with real dependencies. |
| `runtime-storage` | Longhorn, Ceph, persistence Longhorn/Ceph scenarios | Storage controllers/provisioners reconcile and PVC-producing workloads can bind. |
| `runtime-integrations` | Dependency scenarios including `questdb-superset-stack` | Multi-module IDP stacks apply and reconcile together. `questdb-superset-stack` also verifies TCP connectivity to QuestDB's PostgreSQL wire protocol port (8812) from within the cluster. |
| `runtime-all` | Every runtime case, executed sequentially with cleanup between successful cases | Full opt-in/nightly runtime acceptance matrix without deploying all templates at once. |

Individual fixture names can also be passed directly, for example:

```bash
./scripts/acceptance_runtime.sh --case kafka
./scripts/acceptance_runtime.sh --case keycloak-postgresql
./scripts/acceptance_runtime.sh --case persistence-longhorn
```

## Dependency installation mode

By default, runtime acceptance assumes dependencies are already installed in the target cluster. This is safer for shared or pre-provisioned clusters.

With `--install-dependencies`, the script attempts to install pinned, mainstream operators/controllers needed by selected cases. Installation is best suited for disposable kind clusters and should be treated as an opt-in/nightly path.

The installer hooks are intentionally explicit and pinned. Do not replace them with `latest` URLs or floating chart versions.

| Dependency | Used by | Installer behavior |
|---|---|---|
| CloudNativePG | `postgresql`, `keycloak-postgresql`, persistence scenarios | Applies pinned CNPG install manifest and waits for controller rollout. |
| Keycloak Operator | `keycloak`, `keycloak-postgresql` | Applies pinned Keycloak operator resources and waits for controller rollout. |
| OpenSearch Operator | `opensearch`, `dataprepper-opensearch` | Installs pinned operator chart and waits for controller rollout. |
| Strimzi | `kafka` | Installs pinned Strimzi Helm chart and waits for controller rollout. |
| MongoDB Community Operator | `mongodb` | Applies pinned Kustomize install and waits for controller rollout. |
| RabbitMQ Cluster Operator | `rabbitmq` | Applies pinned release manifest and waits for controller rollout. |
| Redis Operator | `redis`, `redis-cluster` | Installs pinned Redis Operator chart and waits for controller rollout. |
| ECK | `elasticsearch-v9`, `kibana-v9`, `logstash-v9` | Applies pinned ECK CRDs/operator and waits for operator rollout. |
| Flux controllers | HelmRelease-backed templates | Installs pinned Flux controller manifests. |
| OpenTelemetry Operator | `opentelemetry` | Installs pinned OpenTelemetry operator chart. |
| Fluent Operator | `fluentbit-operator` | Installs pinned Fluent Operator chart. |
| Longhorn | `longhorn`, `persistence-longhorn` | Installs pinned Longhorn chart in disposable clusters. |
| Rook/Ceph | `ceph`, `persistence-ceph` | Requires a real Rook/Ceph-capable environment; local single-node kind can be insufficient. |

## Known constraints

Some templates emit `HelmRelease` resources through this project's `ThirdPartyHelmSpec`. Runtime tests apply those resources as real resources and wait for `HelmRelease` Ready. That means a real Helm controller must be installed and the generated manifest must match the controller's API expectations. If a HelmRelease-backed case fails validation or reconciliation, the runtime test is correctly exposing a gap that the dry-run layer cannot catch.

Storage suites are the heaviest cases. Longhorn and Ceph need kernel modules, node privileges, disk paths, CSI sidecars, and enough memory. They are not intended for every local developer run.

The `*-rollout` fixtures are intentionally not full product runtime tests. They
render the real template manifests, then patch only the container runtime to a
pinned lightweight HTTP process or use the `pause` image so Kubernetes can prove
rollout/probe behavior without requiring OpenSearch, Kibana, Logstash, or Data
Prepper JVM startup. WebApp-family rollout fixtures (`webapp-probes-rollout`,
`webapp-service-account-rollout`) test specific WebAppModule features — probe
configuration and ServiceAccount generation — using the same patch approach.

`fluentbit-native-rollout` uses the pinned Fluent Bit image with a generated stdout pipeline to prove the native ConfigMap/Service/Deployment path without a Helm controller or Fluent Operator.

**Mixture rollout fixtures** co-deploy multiple native templates in a single `RenderStack`:

| Fixture | Templates | What it proves |
|---|---|---|
| `webapp-database-stack-rollout` | `WebAppModule` + `SingleDatabaseModule` | Two Deployments + PVC/PV bind in one namespace. Cross-module env wiring (DB_HOST). ✓ kind verified |
| `elasticsearch-kibana-stack-rollout` | `ElasticsearchModule` + `KibanaModule` (v7) | StatefulSet + Deployment in same namespace. Kibana's `elasticsearchHosts` wires to the ES Service. ✓ kind verified |
| `elk-stack-rollout` | `ElasticsearchModule` + `KibanaModule` + `LogstashModule` (v7) | Full ELK trio: StatefulSet + two Deployments + all PDBs. Logstash pipeline config points at ES. ✓ kind verified |
| `webapp-dataprepper-stack-rollout` | `WebAppModule` + `DataPrepperModule` | App + collector pattern: two Deployments sharing a namespace. Webapp env wires LOG_ENDPOINT to Data Prepper. ✓ kind verified |
| `webapp-opensearch-dashboards-stack-rollout` | `WebAppModule` + `OpenSearchDashboardsModule` | App + visualization layer. OpenSearch Dashboards patched to Python server on 5601. ✓ kind verified |
| `webapp-elk-stack-rollout` | `WebAppModule` + `ElasticsearchModule` + `KibanaModule` (v7) | App + search-backend + visualization. Mixed: 2 Deployments + 1 StatefulSet + 3 PVCs. ✓ kind verified |
| `dataprepper-elk-stack-rollout` | `DataPrepperModule` + `ElasticsearchModule` + `KibanaModule` (v7) | Log-ingestion pipeline + search + visualization. Mixed: 2 Deployments + 1 StatefulSet. ✓ kind verified |
| `webapp-dataprepper-elk-stack-rollout` | `WebAppModule` + `DataPrepperModule` + `ElasticsearchModule` + `KibanaModule` (v7) | Full 4-component stack: 3 Deployments + 1 StatefulSet. Largest native mixture. ✓ kind verified |
| `webapp-database-dataprepper-stack-rollout` | `WebAppModule` + `SingleDatabaseModule` + `DataPrepperModule` | Three-tier app: 3 Deployments + PVC/PV. Cross-module DB_HOST + LOG_ENDPOINT wiring. ✓ kind verified |

Use the non-`*-rollout` runtime cases for real product/operator reconciliation.

## Promotion rule

A fixture is considered truly runtime-covered only when it has:

1. A runtime case in `scripts/acceptance_runtime.sh`.
2. Real `kubectl apply` without dry-run CRD stubs.
3. A rollout or Ready wait that proves a controller reconciled the resource.
4. Documentation of required operators/storage providers in this file or [ACCEPTANCE_DEPENDENCIES.md](ACCEPTANCE_DEPENDENCIES.md).

## Recommended workflow

Fast local validation:

```bash
./scripts/verify.sh
./scripts/acceptance_kind.sh --case templates
```

Runtime validation for built-in workloads:

```bash
./scripts/acceptance_runtime.sh --case runtime-basic
```

Runtime rollout validation for native template controllers:

```bash
./scripts/acceptance_runtime.sh --case runtime-rollouts --timeout 300s
```

Nightly or release validation, still one case at a time:

```bash
./scripts/acceptance_runtime.sh --case runtime-all --install-dependencies
```

## CI: scheduled runtime workflow

Runtime acceptance runs outside the fast PR gate so the default developer loop
stays fast. `.github/workflows/runtime.yml` provides:

- a **nightly schedule** (02:30 UTC) that runs the `runtime-rollouts` group on a
  disposable kind cluster, and
- a **manual `workflow_dispatch`** with a `group` selector (e.g. `runtime-cnpg`,
  `runtime-kafka`, `runtime-keycloak-postgresql`) and an `install_dependencies`
  toggle for cases that need pinned operators/controllers.

The workflow installs a pinned `kind` and the pinned KCL toolchain, then calls
`./scripts/acceptance_runtime.sh --case <group>`. Because it performs real
`kubectl apply` plus rollout/Ready waits, it is kept separate from the dry-run
matrix in `validate.yml` and never gates ordinary pull requests.
