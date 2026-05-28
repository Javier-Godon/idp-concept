"""
Runtime rollout fixture: WebAppModule + SingleDatabaseModule + DataPrepperModule in one stack.

Models a three-tier web application with persistent storage and structured log
collection: the webapp persists data via the database and emits log events that
Data Prepper collects. All three components are rendered through a single
RenderStack via render_stack.

- WebApp: pause image (no active probes), cross-module env: DB_HOST + LOG_ENDPOINT
- Database: pause image + local hostPath PersistentVolume (no external provisioner)
- DataPrepper: Python HTTP server on port 4900

The PVC binds using a local hostPath PV, matching the webapp-database-stack-rollout
pattern. Data Prepper is patched to a Python HTTP server so kind can prove the
generated Deployment rolls out without the real JVM process.

Covers:
- Three-component IDP stack: app + persistence + log-collector via render_stack
- Two Deployments + PVC/PV binding + DataPrepper Deployment in one namespace
- Cross-module env wiring: DB_HOST (app→database), LOG_ENDPOINT (app→DataPrepper)
- PDB resources alongside DataPrepper workload
"""

import ._helpers as h
import templates.webapp.v1_0_0.webapp as webapp
import templates.database.v1_0_0.database as database
import templates.opensearch.dataprepper.v2_10_2.dataprepper as dp

_namespace = "idp-acceptance-webapp-database-dataprepper-stack-rollout"
_runtime_image = "python:3.12.3-alpine3.20"
_dp_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 4900), H).serve_forever()\n"

_app_base = webapp.WebAppModule {
    name = "acceptance-app-3tier"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "server.port: 8080\ndb.host: acceptance-db-3tier\nlog.endpoint: http://acceptance-dp-3tier:4900/log/ingest\n"}
    env = [
        {name = "DB_HOST", value = "acceptance-db-3tier"}
        {name = "LOG_ENDPOINT", value = "http://acceptance-dp-3tier:4900/log/ingest"}
    ]
}.instance

_db_base = database.SingleDatabaseModule {
    name = "acceptance-db-3tier"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 5432
    dataPath = "/data"
    storageSize = "128Mi"
    storageClassName = ""
    createLocalPersistentVolume = True
    storageHostPath = "/tmp/idp-acceptance-3tier"
}.instance

_dp_base = dp.DataPrepperModule {
    name = "acceptance-dp-3tier"
    namespace = _namespace
    configurations = {}
    asset = {version = "2.10.2"}
    dependsOn = []
    replicas = 1
    pipelineConfig = "entry-pipeline:\n  source:\n    http:\n      path: /log/ingest\n  sink:\n    - stdout:\n"
    resources = dp.DataPrepperResources {
        cpuRequest = "50m"
        cpuLimit = "250m"
        memoryRequest = "128Mi"
        memoryLimit = "256Mi"
    }
}.instance

_patch_dp = lambda manifest: any -> any {
    manifest | {
        if manifest.kind == "Deployment":
            spec.template.spec.containers = [manifest.spec.template.spec.containers[0] | {
                image = _runtime_image
                command = ["python", "-c", _dp_server]
                args = []
                readinessProbe.initialDelaySeconds = 1
                readinessProbe.periodSeconds = 1
                livenessProbe.initialDelaySeconds = 10
                livenessProbe.periodSeconds = 5
                volumeMounts = []
            }]
    }
}

_app_module = h.wrap_component("acceptance-app-3tier", _namespace, _app_base.manifests, "3.10")
_dp_module = h.wrap_component("acceptance-dp-3tier", _namespace, [_patch_dp(manifest) for manifest in _dp_base.manifests], "2.10.2")

h.render_stack([_namespace], [_app_module, _dp_module], [_db_base])

