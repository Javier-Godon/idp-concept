"""
Runtime rollout fixture: WebAppModule + DataPrepperModule co-deployed in one stack.

This models a log collection pipeline: the webapp emits logs via HTTP and Data
Prepper collects them. Both components are rendered through a single RenderStack
via render_stack, exercising the full multi-component IDP stack path.

The webapp uses the pause image (no active probes required). Data Prepper is
patched to a Python HTTP server that satisfies the generated health-check probes
so kind can prove the pipeline stack rolls out without the real JVM process.

Covers:
- Application + sidecar/collector IDP stack assembled via render_stack
- Two Deployments in the same namespace (app + collector pattern)
- Data Prepper ConfigMap + Service + PDB alongside the webapp ConfigMap + Service
- Cross-module env wiring (webapp sets LOG_ENDPOINT pointing at Data Prepper)
"""

import ._helpers as h
import templates.webapp.v1_0_0.webapp as webapp
import templates.opensearch.dataprepper.v2_10_2.dataprepper as dp

_namespace = "idp-acceptance-webapp-dataprepper-stack-rollout"
_runtime_image = "python:3.12.3-alpine3.20"
_dp_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 4900), H).serve_forever()\n"

_app_base = webapp.WebAppModule {
    name = "acceptance-webapp-dp"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "server.port: 8080\nlog.endpoint: http://acceptance-dp:4900\n"}
    env = [
        {name = "APP_ENV", value = "acceptance"}
        {name = "LOG_ENDPOINT", value = "http://acceptance-dp:4900/log/ingest"}
    ]
}.instance

_dp_base = dp.DataPrepperModule {
    name = "acceptance-dp"
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

_app_module = h.wrap_component("acceptance-webapp-dp", _namespace, _app_base.manifests, "3.10")
_dp_module = h.wrap_component("acceptance-dp", _namespace, [_patch_dp(manifest) for manifest in _dp_base.manifests], "2.10.2")

h.render_stack([_namespace], [_app_module, _dp_module], [])

