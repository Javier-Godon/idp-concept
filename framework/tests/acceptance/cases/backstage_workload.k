"""
Acceptance fixture: Backstage HelmRelease through the IDP render path.
"""

import ._helpers as h
import templates.backstage as backstage

_namespace = "idp-acceptance-backstage"
_resource = backstage.build_backstage_release(backstage.BackstageHelmSpec {
    name = "acceptance-backstage"
    namespace = _namespace
    chartVersion = "2.3.0"
    replicas = 1
    host = "backstage.acceptance.example"
})
_module = h.wrap_accessory("acceptance-backstage", _namespace, "helm.toolkit.fluxcd.io/v2beta1", "HelmRelease", [_resource], "2.3.0")

h.render_accessory(_namespace, _module)

