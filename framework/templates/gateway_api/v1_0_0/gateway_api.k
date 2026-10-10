"""
Platform API Gateway Template — Kubernetes Gateway API on Envoy Gateway.

The framework standard for north-south HTTP traffic is the Gateway API (Ingress is not generated;
ingress-nginx is retired upstream). Envoy Gateway (CNCF Envoy project, Apache-2.0, Gateway API
conformant) is the implementation.

Two pieces:
  - GatewayModule: the shared platform Gateway (one per cluster, platform team).
      * crossplane output → XGateway XR (crossplane_v2/managed_resources/gateway_api), which also
        installs the Envoy Gateway controller.
      * yaml output → GatewayClass, EnvoyProxy, Gateway, cert-manager Certificate (+ local CA) and
        an HTTP→HTTPS redirect HTTPRoute. The Envoy Gateway controller and cert-manager are
        cluster prerequisites on this path, and the stack creates the gateway namespace.
  - HTTPRouteModule: exposes an existing Service (e.g. a Helm-installed product) on the gateway.
    Application modules expose themselves with `route` (see WebAppModule / builders.route).

Listeners: "https" serves tlsHostnames with one certificate; "http" serves plain HTTP and
redirects tlsHostnames to HTTPS.

Usage:
    import templates.gateway_api.v1_0_0.gateway_api as gw

    _gateway = gw.GatewayModule {
        name = "platform-gateway"
        namespace = "gateway-system"
        configurations = {}
        asset = {version = gw.ENVOY_GATEWAY_VERSION}
        dependsOn = []
        footprint = "local"
        addresses = ["192.168.49.2"]
        tlsHostnames = ["example.com"]
        selfSignedCA = True
    }.instance
"""

import models.modules.accessory as accessory
import builders.leader as leader
import builders.route as route_builder
import templates.footprints.v1_0_0.footprint as fp

ENVOY_GATEWAY_VERSION = "v1.9.2"
ENVOY_GATEWAY_CONTROLLER = "gateway.envoyproxy.io/gatewayclass-controller"
_GATEWAY_API = "gateway.networking.k8s.io/v1"

schema GatewaySpec:
    """Shared platform gateway settings (mirrors the XGateway API)."""
    name: str = route_builder.DEFAULT_GATEWAY_NAME
    namespace: str = route_builder.DEFAULT_GATEWAY_NAMESPACE
    footprint?: str = "production"
    controllerVersion?: str = ENVOY_GATEWAY_VERSION
    # IPs set as the proxy Service externalIPs (e.g. a local node IP). Empty → LoadBalancer.
    addresses?: [str] = []
    serviceType?: "LoadBalancer" | "NodePort"
    replicas?: int
    allowedRoutes?: "All" | "Same" = "All"
    tlsHostnames?: [str] = []
    issuerName?: str
    issuerKind?: "ClusterIssuer" | "Issuer" = "ClusterIssuer"
    # Local/development only: issue the certificate from a generated self-signed CA.
    selfSignedCA?: bool = False
    caNamespace?: str = "cert-manager"
    redirectToHttps?: bool = True
    owner?: str = ""

    check:
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"
        replicas >= 1 if replicas is not Undefined, "replicas must be >= 1"
        not (selfSignedCA and issuerName), "set either selfSignedCA or issuerName, not both"
        len(tlsHostnames) == 0 or selfSignedCA or issuerName, "tlsHostnames requires issuerName or selfSignedCA"
        not (selfSignedCA and footprint == "production"), "selfSignedCA is not allowed with the production footprint"

schema GatewaySettings:
    """Effective settings after footprint defaults; shared by the yaml and crossplane paths."""
    spec: GatewaySpec
    replicas: int = spec.replicas if spec.replicas is not Undefined else fp.replicas(spec.footprint, 1, 1, 2, 3)
    serviceType: str = spec.serviceType if spec.serviceType is not Undefined else ("NodePort" if spec.addresses else "LoadBalancer")
    hasTls: bool = len(spec.tlsHostnames) > 0
    caIssuer: str = "${spec.name}-local-ca"
    tlsSecret: str = "${spec.name}-tls"

build_gateway_xr_spec = lambda spec: GatewaySpec -> {str:} {
    """XGateway spec (crossplane_v2/managed_resources/gateway_api) for the crossplane output."""
    _s = GatewaySettings {spec = spec}
    {
        namespace = spec.namespace
        gatewayName = spec.name
        controller.version = spec.controllerVersion
        addresses = spec.addresses
        serviceType = _s.serviceType
        replicas = _s.replicas
        allowedRoutes = spec.allowedRoutes
        http.redirectToHttps = spec.redirectToHttps
        tls = {
            hostnames = spec.tlsHostnames
            selfSignedCA = spec.selfSignedCA
            caNamespace = spec.caNamespace
            if spec.issuerName:
                issuerRef = {name = spec.issuerName, kind = spec.issuerKind}
        }
        environment = spec.footprint
        owner = spec.owner
    }
}

build_gateway_resources = lambda spec: GatewaySpec -> [{str:}] {
    """Gateway API resources for the yaml output (controller + cert-manager are prerequisites)."""
    _s = GatewaySettings {spec = spec}
    _labels = {
        "app.kubernetes.io/part-of" = "koncept-platform-gateway"
        "koncept.io/environment" = spec.footprint
        if spec.owner:
            "koncept.io/owner" = spec.owner
    }
    _issuer = {name = _s.caIssuer, kind = "ClusterIssuer"} if spec.selfSignedCA else {name = spec.issuerName, kind = spec.issuerKind}
    _ca = [
        {
            apiVersion = "cert-manager.io/v1"
            kind = "ClusterIssuer"
            metadata = {name = "${spec.name}-selfsigned", labels = _labels}
            spec.selfSigned = {}
        }
        {
            apiVersion = "cert-manager.io/v1"
            kind = "Certificate"
            metadata = {name = _s.caIssuer, namespace = spec.caNamespace, labels = _labels}
            spec = {
                isCA = True
                commonName = "${spec.name} local CA"
                secretName = _s.caIssuer
                duration = "87600h"
                privateKey = {algorithm = "ECDSA", size = 256}
                issuerRef = {name = "${spec.name}-selfsigned", kind = "ClusterIssuer", group = "cert-manager.io"}
            }
        }
        {
            apiVersion = "cert-manager.io/v1"
            kind = "ClusterIssuer"
            metadata = {name = _s.caIssuer, labels = _labels}
            spec.ca.secretName = _s.caIssuer
        }
    ] if _s.hasTls and spec.selfSignedCA else []
    _certificate = [{
        apiVersion = "cert-manager.io/v1"
        kind = "Certificate"
        metadata = {name = _s.tlsSecret, namespace = spec.namespace, labels = _labels}
        spec = {
            secretName = _s.tlsSecret
            dnsNames = spec.tlsHostnames
            issuerRef = _issuer | {group = "cert-manager.io"}
        }
    }] if _s.hasTls else []
    _listeners = [{
        name = "http"
        port = 80
        protocol = "HTTP"
        allowedRoutes.namespaces.from = spec.allowedRoutes
    }] + ([{
        name = "https"
        port = 443
        protocol = "HTTPS"
        tls = {mode = "Terminate", certificateRefs = [{kind = "Secret", name = _s.tlsSecret}]}
        allowedRoutes.namespaces.from = spec.allowedRoutes
    }] if _s.hasTls else [])
    _redirect = [{
        apiVersion = _GATEWAY_API
        kind = "HTTPRoute"
        metadata = {name = "${spec.name}-https-redirect", namespace = spec.namespace, labels = _labels}
        spec = {
            parentRefs = [{name = spec.name, sectionName = "http"}]
            hostnames = spec.tlsHostnames
            rules = [{filters = [{$type = "RequestRedirect", requestRedirect = {scheme = "https", statusCode = 301}}]}]
        }
    }] if _s.hasTls and spec.redirectToHttps else []
    [
        {
            apiVersion = _GATEWAY_API
            kind = "GatewayClass"
            metadata = {name = spec.name, labels = _labels}
            spec.controllerName = ENVOY_GATEWAY_CONTROLLER
        }
        {
            apiVersion = "gateway.envoyproxy.io/v1alpha1"
            kind = "EnvoyProxy"
            metadata = {name = spec.name, namespace = spec.namespace, labels = _labels}
            spec.provider = {
                $type = "Kubernetes"
                kubernetes = {
                    envoyService.$type = _s.serviceType
                    envoyDeployment.replicas = _s.replicas
                }
            }
        }
        {
            apiVersion = _GATEWAY_API
            kind = "Gateway"
            metadata = {name = spec.name, namespace = spec.namespace, labels = _labels}
            spec = {
                gatewayClassName = spec.name
                infrastructure.parametersRef = {group = "gateway.envoyproxy.io", kind = "EnvoyProxy", name = spec.name}
                if spec.addresses:
                    addresses = [{$type = "IPAddress", value = a} for a in spec.addresses]
                listeners = _listeners
            }
        }
    ] + _ca + _certificate + _redirect
}

schema GatewayModule(accessory.Accessory):
    """Shared platform gateway. `name` is the Gateway name routes reference; `namespace` its namespace."""
    kind = "CRD"
    component = "gateway"

    footprint?: str = "production"
    controllerVersion?: str = ENVOY_GATEWAY_VERSION
    addresses?: [str] = []
    serviceType?: "LoadBalancer" | "NodePort"
    replicas?: int
    allowedRoutes?: "All" | "Same" = "All"
    tlsHostnames?: [str] = []
    issuerName?: str
    issuerKind?: "ClusterIssuer" | "Issuer" = "ClusterIssuer"
    selfSignedCA?: bool = False
    caNamespace?: str = "cert-manager"
    redirectToHttps?: bool = True
    owner?: str = ""

    leaders = [leader.build_accessory_leader(name, namespace, "Gateway", _GATEWAY_API)]

    _gateway_spec = GatewaySpec {
        name = name
        namespace = namespace
        footprint = footprint
        controllerVersion = controllerVersion
        addresses = addresses
        serviceType = serviceType
        replicas = replicas
        allowedRoutes = allowedRoutes
        tlsHostnames = tlsHostnames
        issuerName = issuerName
        issuerKind = issuerKind
        selfSignedCA = selfSignedCA
        caNamespace = caNamespace
        redirectToHttps = redirectToHttps
        owner = owner
    }
    manifests = build_gateway_resources(_gateway_spec)
    crossplaneSpec = build_gateway_xr_spec(_gateway_spec)

schema HTTPRouteModule(accessory.Accessory):
    """Exposes an existing Service (not built by the framework) on the platform gateway."""
    kind = "CRD"

    serviceName: str
    servicePort: int
    route: route_builder.RouteSpec

    leaders = [leader.build_accessory_leader(name, namespace, "HTTPRoute", _GATEWAY_API)]
    manifests = [route_builder.build_http_route(route_builder.HTTPRouteSpec {
        name = name
        namespace = namespace
        serviceName = serviceName
        servicePort = servicePort
        route = route
    })]
