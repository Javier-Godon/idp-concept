"""
Runtime rollout fixture: WebAppModule + DataPrepperModule + ElasticsearchModule + KibanaModule.

This is the most complete native-Kubernetes mixture rollout: a web application
with full structured logging, search indexing, and visualization, all rendered
through a single RenderStack via render_stack. No operators required.

The webapp produces structured log events. Data Prepper collects them and ships
to Elasticsearch. Kibana provides the visualization dashboard. All four components
roll out in the same Kubernetes namespace using lightweight Python runtime
containers that satisfy the generated probes.

- WebApp: pause image (no active probes)
- DataPrepper: Python HTTP server on port 4900
- Elasticsearch: Python HTTP server on ports 9200 (HTTP) and 9300 (TCP)
- Kibana: Python HTTP server on port 5601

Covers:
- Full four-component IDP stack assembled via render_stack
- Mixed workload types: 3 x Deployment + 1 x StatefulSet in the same namespace
- Application → log-collector → indexer → dashboard cross-module env wiring
- PDB resources alongside all workloads
- Largest mixture rollout in the acceptance matrix
"""

import ._helpers as h
import templates.webapp.v1_0_0.webapp as webapp
import templates.opensearch.dataprepper.v2_10_2.dataprepper as dp
import templates.elastic.v7_10_2.elasticsearch as elasticsearch
import templates.elastic.v7_10_2.kibana as kibana

_namespace = "idp-acceptance-webapp-dataprepper-elk-stack-rollout"
_runtime_image = "python:3.12.3-alpine3.20"

# Elasticsearch: HTTP on 9200, TCP transport on 9300
_es_server = "import http.server,socketserver,threading\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'{\\\"status\\\":\\\"green\\\"}')\n    def log_message(self,*args):\n        pass\nclass T(socketserver.BaseRequestHandler):\n    def handle(self):\n        pass\nthreading.Thread(target=socketserver.TCPServer(('', 9300), T).serve_forever, daemon=True).start()\nsocketserver.TCPServer(('', 9200), H).serve_forever()\n"

# Kibana: HTTP on 5601
_kibana_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 5601), H).serve_forever()\n"

# DataPrepper: HTTP on 4900
_dp_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 4900), H).serve_forever()\n"

_app_base = webapp.WebAppModule {
    name = "acceptance-webapp-full"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "server.port: 8080\nlog.endpoint: http://acceptance-dp-full:4900/log/ingest\nes.host: http://acceptance-es-full:9200\nkibana.host: http://acceptance-kibana-full:5601\n"}
    env = [
        {name = "LOG_ENDPOINT", value = "http://acceptance-dp-full:4900/log/ingest"}
        {name = "ES_HOST", value = "http://acceptance-es-full:9200"}
        {name = "KIBANA_HOST", value = "http://acceptance-kibana-full:5601"}
    ]
}.instance

_dp_base = dp.DataPrepperModule {
    name = "acceptance-dp-full"
    namespace = _namespace
    configurations = {}
    asset = {version = "2.10.2"}
    dependsOn = []
    replicas = 1
    pipelineConfig = "log-pipeline:\n  source:\n    http:\n      path: /log/ingest\n  sink:\n    - opensearch:\n        hosts: [\"http://acceptance-es-full:9200\"]\n        index: app-logs\n"
    resources = dp.DataPrepperResources {
        cpuRequest = "50m"
        cpuLimit = "250m"
        memoryRequest = "128Mi"
        memoryLimit = "256Mi"
    }
}.instance

_es_base = elasticsearch.ElasticsearchModule {
    name = "acceptance-es-full"
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
    name = "acceptance-kibana-full"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.10.2"}
    dependsOn = []
    replicas = 1
    elasticsearchHosts = ["http://acceptance-es-full:9200"]
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

_app_module = h.wrap_component("acceptance-webapp-full", _namespace, _app_base.manifests, "3.10")
_dp_module = h.wrap_component("acceptance-dp-full", _namespace, [_patch_dp(manifest) for manifest in _dp_base.manifests], "2.10.2")
_es_module = h.wrap_component("acceptance-es-full", _namespace, [_patch_es(manifest) for manifest in _es_base.manifests], "7.10.2")
_kibana_module = h.wrap_component("acceptance-kibana-full", _namespace, [_patch_kibana(manifest) for manifest in _kibana_base.manifests], "7.10.2")

h.render_stack([_namespace], [_app_module, _dp_module, _es_module, _kibana_module], [])

