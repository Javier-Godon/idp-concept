"""
Acceptance fixture: Apache APISIX APIGateway via Helm chart.
Tests: Rendering through IDP RenderStack with footprint configurations.
"""

import ._helpers as h
import templates.apisix.v1_0_0.apisix as apisix

_namespace = "idp-acceptance-apisix"
_module = apisix.APIGatewayModule {
    name = "acceptance-apisix"
    namespace = _namespace
    footprint = "development"
    adminKeySecretName = "acceptance-apisix-admin-keys"
    adminPort = 9180
    gatewayHttpPort = 80
    etcdReplicas = 1
    etcdStorageSize = "1Gi"
}.instance

h.render_accessory(_namespace, _module)

