"""
Runtime rollout fixture: WebAppModule with HTTP liveness, readiness, and startup probes.

The WebAppModule is instantiated with all three probe types pointing at port 8080.
The generated Deployment container is then patched to a lightweight Python HTTP
server so kind can prove the generated probe config rolls out without requiring
the real application image or JVM startup.

Covers: configData, env vars, explicit ResourceSpec, and all three probe types.
"""

import ._helpers as h
import templates.webapp.v1_0_0.webapp as webapp
import builders.deployment as deploy

_namespace = "idp-acceptance-webapp-probes-rollout"
_runtime_image = "python:3.12.3-alpine3.20"
_runtime_server = "import http.server,socketserver\nclass H(http.server.BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.end_headers()\n        self.wfile.write(b'ok')\n    def log_message(self,*args):\n        pass\nsocketserver.TCPServer(('', 8080), H).serve_forever()\n"

_base = webapp.WebAppModule {
    name = "acceptance-webapp-probes"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "server.port: 8080\n"}
    env = [{name = "APP_ENV", value = "acceptance"}]
    resources = deploy.ResourceSpec {
        cpuRequest = "10m"
        cpuLimit = "50m"
        memoryRequest = "32Mi"
        memoryLimit = "64Mi"
    }
    livenessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/health"
        port = 8080
        initialDelaySeconds = 5
        periodSeconds = 5
    }
    readinessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/ready"
        port = 8080
        initialDelaySeconds = 2
        periodSeconds = 3
    }
    startupProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/startup"
        port = 8080
        initialDelaySeconds = 1
        periodSeconds = 2
        failureThreshold = 15
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
                livenessProbe.initialDelaySeconds = 5
                livenessProbe.periodSeconds = 5
                startupProbe.initialDelaySeconds = 1
                startupProbe.periodSeconds = 1
                volumeMounts = []
            }]
    }
}

_module = h.wrap_component("acceptance-webapp-probes", _namespace, [_patch(manifest) for manifest in _base.manifests], "3.10")

h.render_component(_namespace, _module)

