"""
Acceptance fixture: WebAppModule workload.

Uses the backward-compatible root template import and a small pause image so the
case can roll out quickly in a local kind cluster.
"""

import manifests
import templates.webapp as webapp

_namespace = {
    apiVersion = "v1"
    kind = "Namespace"
    metadata = {name = "idp-acceptance-webapp"}
}

_app = webapp.WebAppModule {
    name = "acceptance-webapp"
    namespace = "idp-acceptance-webapp"
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "message: webapp acceptance\n"}
}.instance

manifests.yaml_stream([_namespace] + _app.manifests)
