"""
Runtime rollout fixture: DataPrepperModule + ElasticsearchModule + KibanaModule in one stack.

Models a full log ingestion and search visualization pipeline without a web
application: Data Prepper collects log events and indexes them into Elasticsearch;
Kibana provides the visualization layer. All three components are rendered through
a single RenderStack via render_stack.

Elasticsearch is patched to a Python HTTP server on 9200+9300. Kibana is patched
to a Python HTTP server on 5601. Data Prepper is patched to a Python HTTP server
on 4900 (health/metrics port). Kind proves the full pipeline stack rolls out
without JVM processes or real data.

Covers:
- Log-ingestion + search-backend + visualization IDP stack via render_stack
- Mixed workload types: Deployment (DataPrepper, Kibana) + StatefulSet (Elasticsearch)
- DataPrepper pipeline configuration wired to Elasticsearch output endpoint
- Kibana elasticsearchHosts wired to Elasticsearch Service
- PDB resources rendered alongside all workloads
"""

import ._helpers as h
import templates.opensearch.dataprepper.v2_10_2.dataprepper as dp
import templates.elastic.v7_10_2.elasticsearch as elasticsearch
import templates.elastic.v7_10_2.kibana as kibana

_namespace = "idp-acceptance-dataprepper-elk-stack-rollout"
_runtime_image = "python:3.12.3-alpine3.20"

# Elasticsearch: HTTP on 9200, TCP transport on 9300
_es_server = "import http.server,socketserver,threading\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'{\\\"status\\\":\\\"green\\\"}')\n    def log_message(self,*args):\n        pass\nclass T(socketserver.BaseRequestHandler):\n    def handle(self):\n        pass\nthreading.Thread(target=socketserver.TCPServer(('', 9300), T).serve_forever, daemon=True).start()\nsocketserver.TCPServer(('', 9200), H).serve_forever()\n"

# Kibana: HTTP on 5601
_kibana_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 5601), H).serve_forever()\n"

# DataPrepper: HTTP on 4900
_dp_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 4900), H).serve_forever()\n"

_dp_base = dp.DataPrepperModule {
    name = "acceptance-dp-elk"
    namespace = _namespace
    configurations = {}
    asset = {version = "2.10.2"}
    dependsOn = []
    replicas = 1
    pipelineConfig = "log-pipeline:\n  source:\n    http:\n      path: /log/ingest\n  sink:\n    - opensearch:\n        hosts: [\"http://acceptance-elk-dp-es:9200\"]\n        index: logs\n"
    resources = dp.DataPrepperResources {
        cpuRequest = "50m"
        cpuLimit = "250m"
        memoryRequest = "128Mi"
        memoryLimit = "256Mi"
    }
}.instance

_es_base = elasticsearch.ElasticsearchModule {
    name = "acceptance-elk-dp-es"
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
    name = "acceptance-elk-dp-kibana"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.10.2"}
    dependsOn = []
    replicas = 1
    elasticsearchHosts = ["http://acceptance-elk-dp-es:9200"]
    resources = kibana.KibanaResources {
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

_dp_module = h.wrap_component("acceptance-dp-elk", _namespace, [_patch_dp(manifest) for manifest in _dp_base.manifests], "2.10.2")
_es_module = h.wrap_component("acceptance-elk-dp-es", _namespace, [_patch_es(manifest) for manifest in _es_base.manifests], "7.10.2")
_kibana_module = h.wrap_component("acceptance-elk-dp-kibana", _namespace, [_patch_kibana(manifest) for manifest in _kibana_base.manifests], "7.10.2")

h.render_stack([_namespace], [_dp_module, _es_module, _kibana_module], [])

