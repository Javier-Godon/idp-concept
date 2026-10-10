"""
Route Builder — exposes a Service through the platform API gateway (Kubernetes Gateway API).

Gateway API HTTPRoutes are the framework standard for north-south HTTP traffic; Ingress is not
generated. Routes attach to the shared platform Gateway provisioned by
crossplane_v2/managed_resources/gateway_api (XGateway, Envoy Gateway) or
templates.gateway_api.v1_0_0.gateway_api.GatewayModule:

  - listener "https": TLS hostnames (certificate on the Gateway; plain HTTP is redirected)
  - listener "http":  plain-HTTP hostnames

Usage:
    import builders.route as route

    _route = route.build_http_route(route.HTTPRouteSpec {
        name = "orders-api"
        namespace = "orders"
        serviceName = "orders-api"
        servicePort = 8080
        route = route.RouteSpec {hostnames = ["orders.example.com"], path = "/api"}
    })
"""

DEFAULT_GATEWAY_NAME = "platform-gateway"
DEFAULT_GATEWAY_NAMESPACE = "gateway-system"

helm_fullname = lambda release: str, chart: str -> str {
    """Service name rendered by charts using the Bitnami `common.names.fullname` helper."""
    release if chart in release else "${release}-${chart}"
}

schema RouteSpec:
    """How a module is exposed on the platform gateway."""
    hostnames: [str]
    path?: str = "/"
    # Replace the matched path prefix before forwarding (e.g. "/" to strip "/api").
    rewritePrefix?: str
    # Redirect the exact `path` (no trailing slash) to `path/` with a 301. Needed for single-page apps
    # served under a sub-path that load assets with relative URLs.
    trailingSlashRedirect?: bool = False
    listener?: "https" | "http" = "https"
    gatewayName?: str = DEFAULT_GATEWAY_NAME
    gatewayNamespace?: str = DEFAULT_GATEWAY_NAMESPACE
    # Request timeout, Gateway API duration format (e.g. "30s").
    timeout?: str

    check:
        len(hostnames) > 0, "route.hostnames must not be empty"
        all h in hostnames {
            len(h) > 0 and "/" not in h and ":" not in h
        }, "route.hostnames must be bare hostnames (no scheme, path or port)"
        path.startswith("/"), "route.path must start with '/'"
        rewritePrefix.startswith("/") if rewritePrefix, "route.rewritePrefix must start with '/'"
        not path.endswith("/") if trailingSlashRedirect, "route.trailingSlashRedirect requires a path without a trailing '/' (and not '/')"

schema HTTPRouteSpec:
    name: str
    namespace: str
    serviceName: str
    servicePort: int
    route: RouteSpec
    labels?: {str:str}

    check:
        1 <= servicePort <= 65535, "servicePort must be between 1 and 65535"

build_http_route = lambda spec: HTTPRouteSpec -> {str:} {
    _r = spec.route
    _rule = {
        matches = [{path = {$type = "PathPrefix", value = _r.path}}]
        backendRefs = [{name = spec.serviceName, port = spec.servicePort}]
        if _r.rewritePrefix:
            filters = [{
                $type = "URLRewrite"
                urlRewrite.path = {$type = "ReplacePrefixMatch", replacePrefixMatch = _r.rewritePrefix}
            }]
        if _r.timeout:
            timeouts.request = _r.timeout
    }
    _redirect_rule = {
        matches = [{path = {$type = "Exact", value = _r.path}}]
        filters = [{
            $type = "RequestRedirect"
            requestRedirect = {
                path = {$type = "ReplaceFullPath", replaceFullPath = "${_r.path}/"}
                statusCode = 301
            }
        }]
    }
    {
        apiVersion = "gateway.networking.k8s.io/v1"
        kind = "HTTPRoute"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {"app" = spec.serviceName} | (spec.labels or {})
        }
        spec = {
            parentRefs = [{
                name = _r.gatewayName
                namespace = _r.gatewayNamespace
                sectionName = _r.listener
            }]
            hostnames = _r.hostnames
            rules = ([_redirect_rule] if _r.trailingSlashRedirect else []) + [_rule]
        }
    }
}
