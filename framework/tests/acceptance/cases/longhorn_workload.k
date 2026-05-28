"""
Acceptance fixture: LonghornModule through the IDP render path.
"""
import ._helpers as h
import templates.longhorn.v1_0_0.longhorn as longhorn
_module = longhorn.LonghornModule {
    name = "acceptance-longhorn"
    namespace = "idp-acceptance-longhorn"
    configurations = {}
    asset = {version = "1.7.2"}
    dependsOn = []
    longhornName = "acceptance-longhorn"
    chartVersion = "1.7.2"
    storageClassName = "acceptance-longhorn"
    defaultReplicaCount = 1
}.instance
h.render_accessory("idp-acceptance-longhorn", _module)
