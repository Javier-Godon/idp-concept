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
| L2 lightweight apply | Built-in Kubernetes resources that reliably roll out in kind | `basic`, `webapp`, `database`, `webapp-service-account-rollout`, and `webapp-database-stack-rollout` apply and wait. |
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

### Current rollout fixtures

| Fixture | Template | What it proves |
|---|---|---|
| `dataprepper-rollout` | `DataPrepperModule` | Deployment + probes roll out without real Data Prepper JVM. |
| `opensearch-dashboards-rollout` | `OpenSearchDashboardsModule` | Deployment + probes roll out without a backing OpenSearch. |
| `elasticsearch-rollout` | Elastic v7 `ElasticsearchModule` | StatefulSet + TCP/HTTP probes roll out without a real cluster. |
| `kibana-rollout` | Elastic v7 `KibanaModule` | Deployment + probes roll out without a backing Elasticsearch. |
| `logstash-rollout` | Elastic v7 `LogstashModule` | Deployment + probes roll out without real Logstash JVM. |
| `fluentbit-native-rollout` | Fluent Bit native `FluentBitSingleInstanceModule` | Native ConfigMap + Service + Deployment render and roll out with a pinned Fluent Bit stdout pipeline. Also in APPLY_CASES. |
| `webapp-probes-rollout` | `WebAppModule` with all three probe types | HTTP probe specs (`livenessProbe`, `readinessProbe`, `startupProbe`) render correctly and pass against a Python server. ROLLOUT_CASES only (uses python image). |
| `webapp-service-account-rollout` | `WebAppModule` with `imagePullSecretName` | ServiceAccount generation + `serviceAccountName` wiring. `imagePullSecrets` patched empty for kind. Also in APPLY_CASES. |
| `webapp-database-stack-rollout` | **Mixture**: `WebAppModule` + `SingleDatabaseModule` via `render_stack` | Multi-module stack: two Deployments + PVC+PV roll out simultaneously. Proves `render_stack` in real rollout. Also in APPLY_CASES. ✓ kind verified |
| `elasticsearch-kibana-stack-rollout` | **Mixture**: `ElasticsearchModule` + `KibanaModule` (v7) via `render_stack` | StatefulSet + Deployment in same namespace. Proves mixed workload type mixed stack. Also in APPLY_CASES. ✓ kind verified |
| `elk-stack-rollout` | **Mixture**: `ElasticsearchModule` + `KibanaModule` + `LogstashModule` (v7) via `render_stack` | Full ELK trio: StatefulSet + two Deployments + all PDBs. Proves full search stack rollout. Also in APPLY_CASES. ✓ kind verified |
| `webapp-dataprepper-stack-rollout` | **Mixture**: `WebAppModule` + `DataPrepperModule` via `render_stack` | App + collector: two Deployments sharing a namespace. Proves app+sidecar pipeline stack. Also in APPLY_CASES. ✓ kind verified |
| `webapp-opensearch-dashboards-stack-rollout` | **Mixture**: `WebAppModule` + `OpenSearchDashboardsModule` via `render_stack` | App + visualization layer. OSD patched to Python server on 5601. Also in APPLY_CASES. ✓ kind verified |
| `webapp-elk-stack-rollout` | **Mixture**: `WebAppModule` + `ElasticsearchModule` + `KibanaModule` (v7) via `render_stack` | 3-component search-app stack. 2 Deployments + 1 StatefulSet + 3 PVCs. Also in APPLY_CASES. ✓ kind verified |
| `dataprepper-elk-stack-rollout` | **Mixture**: `DataPrepperModule` + `ElasticsearchModule` + `KibanaModule` (v7) via `render_stack` | Log-ingestion + search + visualization pipeline. 2 Deployments + 1 StatefulSet + 3 PVCs. Also in APPLY_CASES. ✓ kind verified |
| `webapp-dataprepper-elk-stack-rollout` | **Mixture**: `WebAppModule` + `DataPrepperModule` + `ElasticsearchModule` + `KibanaModule` (v7) via `render_stack` | Largest native mixture: 4 templates, 3 Deployments + 1 StatefulSet + 3 PVCs. Also in APPLY_CASES. ✓ kind verified |
| `webapp-database-dataprepper-stack-rollout` | **Mixture**: `WebAppModule` + `SingleDatabaseModule` + `DataPrepperModule` via `render_stack` | Three-tier app+persistence+collector: 3 Deployments + PVC+PV. Also in APPLY_CASES. ✓ kind verified |

### WebApp probe rollout pattern (use Python HTTP server to satisfy probes)

```kcl
_runtime_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 8080), H).serve_forever()\n"

_patch = lambda manifest: any -> any {
    manifest | {
        if manifest.kind == "Deployment":
            spec.template.spec.containers = [manifest.spec.template.spec.containers[0] | {
                image = "python:3.12.3-alpine3.20"
                command = ["python", "-c", _runtime_server]
                readinessProbe.initialDelaySeconds = 1
                readinessProbe.periodSeconds = 1
                livenessProbe.initialDelaySeconds = 5
                livenessProbe.periodSeconds = 5
                startupProbe.initialDelaySeconds = 1
                startupProbe.periodSeconds = 1
                volumeMounts = []
            }]
    }
}
```

### Multi-module mixture rollout pattern

```kcl
h.render_stack([_namespace], [_app_instance], [_db_instance])
```

Use `createLocalPersistentVolume = True` + `storageHostPath = "/tmp/idp-acceptance"` in the database module so PVC binds in kind without Longhorn/Ceph.
In `wait_case` (acceptance_runtime.sh) for mixture fixtures, wait for **all** Deployments individually then call `wait_all_pvcs_bound`.

### Multi-component search stack rollout pattern (ELK / mixed workload types)

When co-deploying templates that emit different workload types (e.g., `StatefulSet` for Elasticsearch + `Deployment` for Kibana), create one `wrap_component` per module and a separate `_patch_*` lambda per kind:

```kcl
_es_module = h.wrap_component("acceptance-elk-es", _namespace, [_patch_es(m) for m in _es_base.manifests], "7.10.2")
_kibana_module = h.wrap_component("acceptance-elk-kibana", _namespace, [_patch_kibana(m) for m in _kibana_base.manifests], "7.10.2")
h.render_stack([_namespace], [_es_module, _kibana_module], [])
```

`_patch_es` must match `manifest.kind == "StatefulSet"` (not `"Deployment"`). `_patch_kibana` matches `"Deployment"`.
`wait_all_rollouts` in `acceptance_runtime.sh` handles mixed types because it queries `kubectl get deploy,statefulset,daemonset`.
Python runtime servers must listen on the template's native port (ES: 9200; Kibana: 5601; Logstash: 9600; DataPrepper: 4900).
Also add explicit StatefulSet rollout waits in `wait_case` alongside Deployment waits.

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
