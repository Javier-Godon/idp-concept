"""
Acceptance fixture: platform API gateway (Envoy Gateway / Gateway API) through the IDP render path.
Renders GatewayModule (GatewayClass, EnvoyProxy, Gateway, local-CA certificate, HTTP→HTTPS redirect),
an HTTPRouteModule for an existing Service, and a WebAppModule exposed with `route`.
Level: L1 (dry-run) — requires Gateway API, Envoy Gateway and cert-manager CRD stubs.
"""

import ._helpers as h
import templates.gateway_api.v1_0_0.gateway_api as gw
import templates.webapp.v1_0_0.webapp as webapp

_namespace = "idp-acceptance-gateway-api"

_gateway = gw.GatewayModule {
    name = "acceptance-gateway"
    namespace = _namespace
    configurations = {}
    asset = {version = gw.ENVOY_GATEWAY_VERSION}
    dependsOn = []
    footprint = "local"
    tlsHostnames = ["acceptance.example.com"]
    selfSignedCA = True
    caNamespace = _namespace
}.instance

_existing_service_route = gw.HTTPRouteModule {
    name = "acceptance-existing-service"
    namespace = _namespace
    configurations = {}
    asset = {version = "1.0.0"}
    dependsOn = []
    serviceName = "acceptance-existing-service"
    servicePort = 80
    route = {
        hostnames = ["acceptance.example.com"]
        path = "/tools"
        gatewayName = "acceptance-gateway"
        gatewayNamespace = _namespace
    }
}.instance

_app = webapp.WebAppModule {
    name = "acceptance-routed-app"
    namespace = _namespace
    configurations = {}
    asset = {image = "nginx", version = "1.27.3-alpine"}
    dependsOn = []
    port = 8080
    route = {
        hostnames = ["acceptance.example.com"]
        gatewayName = "acceptance-gateway"
        gatewayNamespace = _namespace
    }
}.instance

h.render_stack([_namespace], [_app], [_gateway, _existing_service_route])
