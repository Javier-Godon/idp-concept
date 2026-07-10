"""
Acceptance fixture: cert-manager HelmRelease through the IDP render path.
Tests: Bitnami cert-manager Helm chart rendering with ACME configuration.
Level: L1 (dry-run) — requires Flux HelmRelease CRD stubs.
"""

import ._helpers as h
import templates.cert_manager.v1_0_0.cert_manager as cm

_namespace = "idp-acceptance-cert-manager"
_resource = cm.build_cert_manager({
    name = "acceptance-cert-manager"
    namespace = _namespace
    replicas = 1
    chartVersion = cm._CERT_MANAGER_VERSION
})
_module = h.wrap_accessory(
    "acceptance-cert-manager",
    _namespace,
    "helm.toolkit.fluxcd.io/v2beta1",
    "HelmRelease",
    [_resource],
    cm._CERT_MANAGER_VERSION
)

h.render_accessory(_namespace, _module)
