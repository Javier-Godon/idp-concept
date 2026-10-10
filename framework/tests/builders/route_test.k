"""
Route Builder Tests — Gateway API HTTPRoute generation (framework standard, no Ingress).
"""
import builders.route as route
import runtime

test_http_route_defaults_to_https_listener_on_platform_gateway = lambda {
    _r = route.build_http_route(route.HTTPRouteSpec {
        name = "orders"
        namespace = "apps"
        serviceName = "orders-api"
        servicePort = 8080
        route = route.RouteSpec {hostnames = ["orders.example.com"]}
    })
    assert _r.apiVersion == "gateway.networking.k8s.io/v1"
    assert _r.kind == "HTTPRoute"
    assert _r.metadata.name == "orders"
    assert _r.metadata.namespace == "apps"
    assert _r.spec.parentRefs == [{name = "platform-gateway", namespace = "gateway-system", sectionName = "https"}]
    assert _r.spec.hostnames == ["orders.example.com"]
    assert _r.spec.rules[0].matches[0].path == {type = "PathPrefix", value = "/"}
    assert _r.spec.rules[0].backendRefs == [{name = "orders-api", port = 8080}]
    assert "filters" not in _r.spec.rules[0]
}

test_http_route_rewrite_timeout_and_http_listener = lambda {
    _r = route.build_http_route(route.HTTPRouteSpec {
        name = "parser"
        namespace = "tools"
        serviceName = "parser"
        servicePort = 8000
        route = route.RouteSpec {
            hostnames = ["tools.example.com"]
            path = "/parser"
            rewritePrefix = "/"
            listener = "http"
            gatewayName = "edge"
            gatewayNamespace = "edge-system"
            timeout = "30s"
        }
    })
    assert _r.spec.parentRefs[0] == {name = "edge", namespace = "edge-system", sectionName = "http"}
    assert _r.spec.rules[0].filters[0].type == "URLRewrite"
    assert _r.spec.rules[0].filters[0].urlRewrite.path.replacePrefixMatch == "/"
    assert _r.spec.rules[0].timeouts.request == "30s"
}

test_route_spec_rejects_hostname_with_scheme = lambda {
    _err = runtime.catch(lambda {
        route.RouteSpec {hostnames = ["https://bad.example.com"]}
    })
    assert _err != Undefined, "Expected validation error for hostname with scheme"
}

test_helm_fullname = lambda {
    assert route.helm_fullname("backstage", "backstage") == "backstage"
    assert route.helm_fullname("portal", "backstage") == "portal-backstage"
}
