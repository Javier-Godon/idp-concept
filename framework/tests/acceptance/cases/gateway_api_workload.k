"""
Acceptance fixture: Gateway API controller and Gateway resource through the IDP render path.
Tests: Envoy Gateway HelmRelease + Gateway CRD rendering.
Level: L1 (dry-run) — requires Flux HelmRelease and Gateway API CRD stubs.
"""

import ._helpers as h
import templates.gateway_api.v1_0_0.gateway_api as gw

_namespace = "idp-acceptance-gateway-api"
_controller = gw.build_gateway_controller({
    name = "acceptance-envoy-gateway"
    namespace = _namespace
    provider = "envoy"
    replicas = 1
    chartVersion = gw._ENVOY_GATEWAY_VERSION
})
_gateway = gw.build_gateway({
    name = "acceptance-gateway"
    namespace = _namespace
    gatewayClassName = "envoy"
    port = 80
    protocolType = "HTTP"
})
_module = h.wrap_accessory(
    "acceptance-gateway-api",
    _namespace,
    "helm.toolkit.fluxcd.io/v2beta1",
    "HelmRelease",
    [_controller, _gateway],
    gw._ENVOY_GATEWAY_VERSION
)

h.render_accessory(_namespace, _module)
