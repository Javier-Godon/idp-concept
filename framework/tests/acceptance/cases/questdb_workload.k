"""
Acceptance fixture: QuestDB HelmRelease through the IDP render path.
"""

import ._helpers as h
import templates.questdb.v1_0_0.questdb as qdb

_namespace = "idp-acceptance-questdb"
_resource = qdb.build_questdb_release(qdb.QuestDBSpec {
    name = "acceptance-questdb"
    namespace = _namespace
    chartVersion = "0.32.0"
    storageSize = "1Gi"
})
_module = h.wrap_accessory("acceptance-questdb", _namespace, "helm.toolkit.fluxcd.io/v2beta1", "HelmRelease", [_resource], "0.32.0")

h.render_accessory(_namespace, _module)

