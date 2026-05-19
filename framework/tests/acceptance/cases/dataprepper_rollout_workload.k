"""
Runtime rollout fixture: DataPrepperModule-generated Deployment.

This keeps the template-generated ConfigMap/Service/Deployment shape, then patches
only the container runtime so kind can prove the generated Deployment rolls out
without requiring the full Data Prepper JVM process or OpenSearch.
"""

import ._helpers as h
import templates.dataprepper as dp

_namespace = "idp-acceptance-dataprepper-rollout"
_runtime_image = "python:3.12.3-alpine3.20"
_runtime_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 4900), H).serve_forever()\n"

_base = dp.DataPrepperModule {
    name = "acceptance-dataprepper-rollout"
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

_patch = lambda manifest: any -> any {
    manifest | {
        if manifest.kind == "Deployment":
            spec.template.spec.containers = [manifest.spec.template.spec.containers[0] | {
                image = _runtime_image
                command = ["python", "-c", _runtime_server]
                args = []
                readinessProbe.initialDelaySeconds = 1
                readinessProbe.periodSeconds = 1
                livenessProbe.initialDelaySeconds = 10
                livenessProbe.periodSeconds = 5
                volumeMounts = []
            }]
    }
}

_module = h.wrap_component("acceptance-dataprepper-rollout", _namespace, [_patch(manifest) for manifest in _base.manifests], "2.10.2")

h.render_component(_namespace, _module)

