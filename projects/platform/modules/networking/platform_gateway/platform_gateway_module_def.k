"""
Shared platform API gateway (Envoy Gateway). Rendered as an XGateway XR by the crossplane output;
every HTTPRoute in the cluster attaches to it (listeners "https" and "http").
"""
import framework.templates.gateway_api.v1_0_0.gateway_api as gw

schema PlatformGatewayModule(gw.GatewayModule):
    footprint = configurations.footprint
    addresses = configurations.gatewayAddresses or []
    tlsHostnames = configurations.gatewayTlsHostnames or []
    selfSignedCA = configurations.gatewaySelfSignedCA or False
    if configurations.gatewayIssuerName:
        issuerName = configurations.gatewayIssuerName
    owner = "platform-team"
