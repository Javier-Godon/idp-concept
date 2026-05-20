"""
Runtime rollout fixture: ElasticsearchModule + KibanaModule co-deployed in one stack.

Both the ElasticSearch StatefulSet and the Kibana Deployment are rendered through
a single RenderStack via render_stack, exercising the full multi-component IDP
stack path with mixed workload types (StatefulSet + Deployment) in the same namespace.

The Python runtime servers satisfy the generated HTTP/TCP probes so kind can
prove both services roll out without requiring the real Elasticsearch or Kibana
JVM processes.

Covers:
- Multi-module IDP stack assembled via render_stack
- StatefulSet (Elasticsearch) + Deployment (Kibana) in the same namespace
- Cross-module config wiring (Kibana points at Elasticsearch URL)
- Both PDB resources rendered alongside their workloads
"""

import ._helpers as h
import templates.elasticsearch as elasticsearch
import templates.kibana as kibana

_namespace = "idp-acceptance-elasticsearch-kibana-stack-rollout"
_runtime_image = "python:3.12.3-alpine3.20"

# Elasticsearch: HTTP on 9200, TCP transport on 9300
_es_server = "import http.server,socketserver,threading\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'{\\\"status\\\":\\\"green\\\"}')\n    def log_message(self,*args):\n        pass\nclass T(socketserver.BaseRequestHandler):\n    def handle(self):\n        pass\nthreading.Thread(target=socketserver.TCPServer(('', 9300), T).serve_forever, daemon=True).start()\nsocketserver.TCPServer(('', 9200), H).serve_forever()\n"

# Kibana: HTTP on 5601
_kibana_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 5601), H).serve_forever()\n"

_es_base = elasticsearch.ElasticsearchModule {
    name = "acceptance-elk-elasticsearch"
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

_kibana_base = kibana.KibanaModule {
    name = "acceptance-elk-kibana"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.10.2"}
    dependsOn = []
    replicas = 1
    elasticsearchHosts = ["http://acceptance-elk-elasticsearch:9200"]
    resources = kibana.KibanaResources {
        cpuRequest = "50m"
        cpuLimit = "250m"
        memoryRequest = "128Mi"
        memoryLimit = "256Mi"
    }
}.instance

_patch_es = lambda manifest: any -> any {
    manifest | {
        if manifest.kind == "StatefulSet":
            spec.template.spec.terminationGracePeriodSeconds = 5
            spec.template.spec.containers = [manifest.spec.template.spec.containers[0] | {
                image = _runtime_image
                command = ["python", "-c", _es_server]
                env = []
                readinessProbe.initialDelaySeconds = 1
                readinessProbe.periodSeconds = 1
                livenessProbe.initialDelaySeconds = 10
                livenessProbe.periodSeconds = 5
                volumeMounts = []
            }]
    }
}

_patch_kibana = lambda manifest: any -> any {
    manifest | {
        if manifest.kind == "Deployment":
            spec.template.spec.containers = [manifest.spec.template.spec.containers[0] | {
                image = _runtime_image
                command = ["python", "-c", _kibana_server]
                readinessProbe.initialDelaySeconds = 1
                readinessProbe.periodSeconds = 1
                livenessProbe.initialDelaySeconds = 10
                livenessProbe.periodSeconds = 5
                volumeMounts = []
            }]
    }
}

_es_module = h.wrap_component("acceptance-elk-elasticsearch", _namespace, [_patch_es(manifest) for manifest in _es_base.manifests], "7.10.2")
_kibana_module = h.wrap_component("acceptance-elk-kibana", _namespace, [_patch_kibana(manifest) for manifest in _kibana_base.manifests], "7.10.2")

h.render_stack([_namespace], [_es_module, _kibana_module], [])

