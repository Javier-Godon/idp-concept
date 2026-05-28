"""
Runtime rollout fixture: WebAppModule + ElasticsearchModule + KibanaModule in one stack.

Models a search-capable web application deployed alongside its full Elasticsearch
index and Kibana visualization layer. All three components are rendered through a
single RenderStack via render_stack.

The webapp uses the pause image (no active probes). Elasticsearch is patched to a
Python HTTP server on ports 9200 (HTTP) and 9300 (TCP transport). Kibana is
patched to a Python HTTP server on port 5601. Kind proves all three roll out
without requiring JVM processes or real ES/Kibana data.

Covers:
- Application + search-backend + visualization IDP stack via render_stack
- Mixed workload types: Deployment (webapp, Kibana) + StatefulSet (Elasticsearch)
- Cross-module config wiring: webapp env ES_HOST, Kibana elasticsearchHosts
- PDB resources rendered alongside all workloads
"""

import ._helpers as h
import templates.webapp.v1_0_0.webapp as webapp
import templates.elastic.v7_10_2.elasticsearch as elasticsearch
import templates.elastic.v7_10_2.kibana as kibana

_namespace = "idp-acceptance-webapp-elk-stack-rollout"
_runtime_image = "python:3.12.3-alpine3.20"

# Elasticsearch: HTTP on 9200, TCP transport on 9300
_es_server = "import http.server,socketserver,threading\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'{\\\"status\\\":\\\"green\\\"}')\n    def log_message(self,*args):\n        pass\nclass T(socketserver.BaseRequestHandler):\n    def handle(self):\n        pass\nthreading.Thread(target=socketserver.TCPServer(('', 9300), T).serve_forever, daemon=True).start()\nsocketserver.TCPServer(('', 9200), H).serve_forever()\n"

# Kibana: HTTP on 5601
_kibana_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 5601), H).serve_forever()\n"

_app_base = webapp.WebAppModule {
    name = "acceptance-webapp-elk"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "server.port: 8080\nes.host: http://acceptance-elk-es:9200\n"}
    env = [
        {name = "ES_HOST", value = "http://acceptance-elk-es:9200"}
        {name = "KIBANA_HOST", value = "http://acceptance-elk-kibana:5601"}
    ]
}.instance

_es_base = elasticsearch.ElasticsearchModule {
    name = "acceptance-elk-es"
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
    elasticsearchHosts = ["http://acceptance-elk-es:9200"]
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

_app_module = h.wrap_component("acceptance-webapp-elk", _namespace, _app_base.manifests, "3.10")
_es_module = h.wrap_component("acceptance-elk-es", _namespace, [_patch_es(manifest) for manifest in _es_base.manifests], "7.10.2")
_kibana_module = h.wrap_component("acceptance-elk-kibana", _namespace, [_patch_kibana(manifest) for manifest in _kibana_base.manifests], "7.10.2")

h.render_stack([_namespace], [_app_module, _es_module, _kibana_module], [])

