"""
Runtime rollout fixture: ElasticsearchModule-generated StatefulSet.

The Elasticsearch template intentionally requires three replicas. This fixture
keeps that StatefulSet/Service/ConfigMap/PDB shape and patches only the runtime
container to a small Python process that satisfies the HTTP and TCP probes.
"""

import ._helpers as h
import templates.elastic.v7_10_2.elasticsearch as elasticsearch

_namespace = "idp-acceptance-elasticsearch-rollout"
_runtime_image = "python:3.12.3-alpine3.20"
_runtime_server = "import http.server,socketserver,threading\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'{\\\"status\\\":\\\"green\\\"}')\n    def log_message(self,*args):\n        pass\nclass T(socketserver.BaseRequestHandler):\n    def handle(self):\n        pass\nthreading.Thread(target=socketserver.TCPServer(('', 9300), T).serve_forever, daemon=True).start()\nsocketserver.TCPServer(('', 9200), H).serve_forever()\n"

_base = elasticsearch.ElasticsearchModule {
    name = "acceptance-elasticsearch-rollout"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.10.2"}
    dependsOn = []
    replicas = 3
    storageSize = "128Mi"
    storageClassName = "standard"
    javaOpts = "-Xms128m -Xmx128m"
    resources = elasticsearch.ElasticsearchResources {
        cpuRequest = "50m"
        cpuLimit = "250m"
        memoryRequest = "128Mi"
        memoryLimit = "256Mi"
    }
}.instance

_patch = lambda manifest: any -> any {
    manifest | {
        if manifest.kind == "StatefulSet":
            spec.template.spec.terminationGracePeriodSeconds = 5
            spec.template.spec.containers = [manifest.spec.template.spec.containers[0] | {
                image = _runtime_image
                command = ["python", "-c", _runtime_server]
                env = []
                readinessProbe.initialDelaySeconds = 1
                readinessProbe.periodSeconds = 1
                livenessProbe.initialDelaySeconds = 10
                livenessProbe.periodSeconds = 5
                volumeMounts = []
            }]
    }
}

_module = h.wrap_component("acceptance-elasticsearch-rollout", _namespace, [_patch(manifest) for manifest in _base.manifests], "7.10.2")

h.render_component(_namespace, _module)

