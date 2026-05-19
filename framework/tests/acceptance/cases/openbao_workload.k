"""
Acceptance fixture: OpenBaoModule through the IDP render path.
"""
import ._helpers as h
import templates.openbao as openbao
_module = openbao.OpenBaoModule {
    name = "acceptance-openbao"
    namespace = "idp-acceptance-openbao"
    configurations = {}
    asset = {version = "0.8.1"}
    dependsOn = []
    openbaoName = "acceptance-openbao"
    chartVersion = "0.8.1"
    mode = "standalone"
    replicas = 1
    storageSize = "1Gi"
    tlsDisable = True
}.instance
h.render_accessory("idp-acceptance-openbao", _module)
