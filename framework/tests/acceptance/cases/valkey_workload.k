"""
Acceptance fixture: ValkeyModule through the IDP render path.
"""
import ._helpers as h
import templates.valkey as valkey
_module = valkey.ValkeyModule {
    name = "acceptance-valkey"
    namespace = "idp-acceptance-valkey"
    configurations = {}
    asset = {version = "2.1.3"}
    dependsOn = []
    valkeyName = "acceptance-valkey"
    chartVersion = "2.1.3"
    mode = "standalone"
    replicas = 1
    storageSize = "1Gi"
}.instance
h.render_accessory("idp-acceptance-valkey", _module)
