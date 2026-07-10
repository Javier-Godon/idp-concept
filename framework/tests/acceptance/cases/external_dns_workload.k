"""
Acceptance fixture: external-dns HelmRelease through the IDP render path.
Tests: Bitnami external-dns Helm chart rendering with AWS Route 53 provider.
Level: L1 (dry-run) — requires Flux HelmRelease CRD stubs.
"""

import ._helpers as h
import templates.external_dns.v1_0_0.external_dns as edns

_namespace = "idp-acceptance-external-dns"
_resource = edns.build_external_dns({
    name = "acceptance-external-dns"
    namespace = _namespace
    provider = "aws"
    replicas = 1
    chartVersion = edns._EXTERNAL_DNS_VERSION
})
_module = h.wrap_accessory(
    "acceptance-external-dns",
    _namespace,
    "helm.toolkit.fluxcd.io/v2beta1",
    "HelmRelease",
    [_resource],
    edns._EXTERNAL_DNS_VERSION
)

h.render_accessory(_namespace, _module)
