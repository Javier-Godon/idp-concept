"""
Acceptance fixture: Nexus Repository with persistent storage, published on a gateway sub-path through the IDP render path.
Dry-run only: it needs the Gateway API CRDs (stubbed by the dry-run runner) and a heavy JVM image.
"""
import ._helpers as h
import templates.nexus.v1_0_0.nexus as nexus

_namespace = "idp-acceptance-nexus"
_module = nexus.NexusModule {
    name = "acceptance-nexus"
    namespace = _namespace
    configurations = {}
    asset = {version = "3.96.4"}
    dependsOn = []
    storageClassName = "acceptance-local"
    storageSize = "5Gi"
    contextPath = "/nexus"
    route = {hostnames = ["acceptance.example.com"], path = "/nexus", timeout = "0s"}
}.instance
h.render_component(_namespace, _module)
