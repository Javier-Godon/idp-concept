"""
Runtime rollout fixture: KibanaModule-generated Deployment.

This validates the Kubernetes-native Kibana manifest shape with a real rollout
while avoiding a heavyweight Elasticsearch dependency for this specific smoke.
"""

import ._helpers as h
import templates.kibana as kibana

_namespace = "idp-acceptance-kibana-rollout"
_runtime_image = "python:3.12.3-alpine3.20"
_runtime_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 5601), H).serve_forever()\n"

_base = kibana.KibanaModule {
    name = "acceptance-kibana-rollout"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.10.2"}
    dependsOn = []
    replicas = 1
    elasticsearchHosts = ["http://elasticsearch-placeholder:9200"]
    resources = kibana.KibanaResources {
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

_module = h.wrap_component("acceptance-kibana-rollout", _namespace, [_patch(manifest) for manifest in _base.manifests], "7.10.2")

h.render_component(_namespace, _module)

