"""
Runtime rollout fixture: WebAppModule + OpenSearchDashboardsModule co-deployed in one stack.

Models a search-enabled web application where the webapp emits data and the
OpenSearch Dashboards instance provides a visualization layer. Both components
are rendered through a single RenderStack via render_stack.

The webapp uses the pause image (no active probes). OpenSearch Dashboards is
patched to a Python HTTP server on port 5601 so kind can prove the generated
Deployment rolls out without a real Dashboards process or a backing OpenSearch
cluster.

Covers:
- Application + visualization-layer IDP stack via render_stack
- Two Deployments in the same namespace
- OpenSearch Dashboards ConfigMap, Service, and PDB alongside the webapp resources
- Cross-module env wiring (webapp sets SEARCH_UI pointing at Dashboards Service)
"""

import ._helpers as h
import templates.webapp as webapp
import templates.opensearch_dashboards as dashboards

_namespace = "idp-acceptance-webapp-opensearch-dashboards-stack-rollout"
_runtime_image = "python:3.12.3-alpine3.20"
_dashboards_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 5601), H).serve_forever()\n"

_app_base = webapp.WebAppModule {
    name = "acceptance-webapp-osd"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "server.port: 8080\nsearch.ui: http://acceptance-osd:5601\n"}
    env = [{name = "SEARCH_UI", value = "http://acceptance-osd:5601"}]
}.instance

_osd_base = dashboards.OpenSearchDashboardsModule {
    name = "acceptance-osd"
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

_patch_osd = lambda manifest: any -> any {
    manifest | {
        if manifest.kind == "Deployment":
            spec.template.spec.containers = [manifest.spec.template.spec.containers[0] | {
                image = _runtime_image
                command = ["python", "-c", _dashboards_server]
                readinessProbe.initialDelaySeconds = 1
                readinessProbe.periodSeconds = 1
                livenessProbe.initialDelaySeconds = 10
                livenessProbe.periodSeconds = 5
                volumeMounts = []
            }]
    }
}

_app_module = h.wrap_component("acceptance-webapp-osd", _namespace, _app_base.manifests, "3.10")
_osd_module = h.wrap_component("acceptance-osd", _namespace, [_patch_osd(manifest) for manifest in _osd_base.manifests], "2.17.0")

h.render_stack([_namespace], [_app_module, _osd_module], [])

