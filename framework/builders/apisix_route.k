"""
ApisixRoute builder — declares an API on Apache APISIX through the apisix-ingress-controller (operator).

The route is a namespaced `apisix.apache.org/v2 ApisixRoute` custom resource, reconciled by the operator into
the APISIX configuration store (etcd). It is the API-gateway counterpart of builders/route.k (Gateway API
HTTPRoute): Envoy Gateway delivers the traffic to APISIX, the ApisixRoute decides which backend serves it.

Usage:
    import builders.apisix_route as apisix_route

    _route = apisix_route.build_apisix_route(apisix_route.ApisixRouteSpec {
        name = "orders-api"
        namespace = "orders"
        serviceName = "orders-api"
        servicePort = 8080
        publicPath = "/api"
        upstreamPath = "/orders"
    })
"""

API_VERSION = "apisix.apache.org/v2"
DEFAULT_INGRESS_CLASS = "apisix"

schema ApisixRouteSpec:
    name: str
    namespace: str
    serviceName: str
    servicePort: int
    # Prefix published through the gateway; the route matches `publicPath` and `publicPath/*`.
    publicPath: str
    # Prefix the backend serves under; `publicPath` is rewritten to it. Empty = forward unchanged.
    upstreamPath?: str
    ingressClassName: str = DEFAULT_INGRESS_CLASS
    labels?: {str:str}

    check:
        1 <= servicePort <= 65535, "servicePort must be between 1 and 65535"
        publicPath.startswith("/"), "publicPath must start with /"
        len(publicPath) > 1, "publicPath must not be the root path"
        not publicPath.endswith("/"), "publicPath must not end with /"
        upstreamPath.startswith("/") if upstreamPath, "upstreamPath must start with /"

build_apisix_route = lambda spec: ApisixRouteSpec -> {str:} {
    {
        apiVersion = API_VERSION
        kind = "ApisixRoute"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            if spec.labels:
                labels = spec.labels
        }
        spec = {
            ingressClassName = spec.ingressClassName
            http = [{
                name = spec.name
                match.paths = [spec.publicPath, "${spec.publicPath}/*"]
                backends = [{serviceName = spec.serviceName, servicePort = spec.servicePort}]
                if spec.upstreamPath:
                    plugins = [{
                        name = "proxy-rewrite"
                        enable = True
                        config.regex_uri = ["^${spec.publicPath}/?(.*)", "${spec.upstreamPath}/$1"]
                    }]
            }]
        }
    }
}
