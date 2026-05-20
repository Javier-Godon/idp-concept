"""
Runtime rollout fixture: ElasticsearchModule + KibanaModule + LogstashModule in one stack.

All three ELK components are rendered through a single RenderStack via render_stack,
exercising the full multi-component IDP stack path with StatefulSet (Elasticsearch)
and two Deployments (Kibana, Logstash) in the same namespace.

Python runtime servers satisfy the generated probes so kind can prove the full
ELK stack rolls out without JVM processes or actual data pipelines.

Covers:
- Full ELK stack assembled via render_stack
- StatefulSet + two Deployments in the same namespace
- Cross-module wiring (Kibana and Logstash both point at Elasticsearch)
- All three PDB resources rendered alongside their workloads
- Logstash beats input + Kibana visualization in one namespace
"""

import ._helpers as h
import templates.elasticsearch as elasticsearch
import templates.kibana as kibana
import templates.logstash as logstash

_namespace = "idp-acceptance-elk-stack-rollout"
_runtime_image = "python:3.12.3-alpine3.20"

# Elasticsearch: HTTP on 9200, TCP transport on 9300
_es_server = "import http.server,socketserver,threading\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'{\\\"status\\\":\\\"green\\\"}')\n    def log_message(self,*args):\n        pass\nclass T(socketserver.BaseRequestHandler):\n    def handle(self):\n        pass\nthreading.Thread(target=socketserver.TCPServer(('', 9300), T).serve_forever, daemon=True).start()\nsocketserver.TCPServer(('', 9200), H).serve_forever()\n"

# Kibana: HTTP on 5601
_kibana_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 5601), H).serve_forever()\n"

# Logstash: HTTP metrics on 9600
_logstash_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 9600), H).serve_forever()\n"

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

_logstash_base = logstash.LogstashModule {
    name = "acceptance-elk-logstash"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.10.2"}
    dependsOn = []
    replicas = 1
    pipelineConfig = "input { beats { port => 5044 } }\noutput { elasticsearch { hosts => [\"http://acceptance-elk-es:9200\"] } }\n"
    resources = logstash.LogstashResources {
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

_patch_logstash = lambda manifest: any -> any {
    manifest | {
        if manifest.kind == "Deployment":
            spec.template.spec.containers = [manifest.spec.template.spec.containers[0] | {
                image = _runtime_image
                command = ["python", "-c", _logstash_server]
                readinessProbe.initialDelaySeconds = 1
                readinessProbe.periodSeconds = 1
                livenessProbe.initialDelaySeconds = 10
                livenessProbe.periodSeconds = 5
                volumeMounts = []
            }]
    }
}

_es_module = h.wrap_component("acceptance-elk-es", _namespace, [_patch_es(manifest) for manifest in _es_base.manifests], "7.10.2")
_kibana_module = h.wrap_component("acceptance-elk-kibana", _namespace, [_patch_kibana(manifest) for manifest in _kibana_base.manifests], "7.10.2")
_logstash_module = h.wrap_component("acceptance-elk-logstash", _namespace, [_patch_logstash(manifest) for manifest in _logstash_base.manifests], "7.10.2")

h.render_stack([_namespace], [_es_module, _kibana_module, _logstash_module], [])

