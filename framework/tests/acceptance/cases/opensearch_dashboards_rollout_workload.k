"""
Runtime rollout fixture: OpenSearchDashboardsModule-generated Deployment.

The standalone Dashboards template normally needs a backing OpenSearch cluster.
For rollout acceptance, keep the generated Kubernetes manifests and patch only
the container runtime to a tiny HTTP server that satisfies the template probes.
"""

import ._helpers as h
import templates.opensearch_dashboards as dashboards

_namespace = "idp-acceptance-opensearch-dashboards-rollout"
_runtime_image = "python:3.12.3-alpine3.20"
_runtime_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 5601), H).serve_forever()\n"

_base = dashboards.OpenSearchDashboardsModule {
    name = "acceptance-opensearch-dashboards-rollout"
    namespace = _namespace
    configurations = {}
    asset = {version = "2.17.0"}
    dependsOn = []
    replicas = 1
    opensearchHosts = ["http://opensearch-placeholder:9200"]
    resources = dashboards.OpenSearchDashboardsResources {
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
                readinessProbe.initialDelaySeconds = 1
                readinessProbe.periodSeconds = 1
                livenessProbe.initialDelaySeconds = 10
                livenessProbe.periodSeconds = 5
                volumeMounts = []
            }]
    }
}

_module = h.wrap_component("acceptance-opensearch-dashboards-rollout", _namespace, [_patch(manifest) for manifest in _base.manifests], "2.17.0")

h.render_component(_namespace, _module)

