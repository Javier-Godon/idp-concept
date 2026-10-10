"""
Platform API gateway template tests (Envoy Gateway / Gateway API).
"""
import templates.gateway_api.v1_0_0.gateway_api as gw
import procedures.kcl_to_crossplane as crossplane_proc
import models.modules.accessory as accessory
import runtime

_local = gw.GatewaySpec {
    name = "platform-gateway"
    namespace = "gateway-system"
    footprint = "local"
    addresses = ["192.168.49.2"]
    tlsHostnames = ["example.com"]
    selfSignedCA = True
}

test_gateway_resources_local_tls = lambda {
    _res = gw.build_gateway_resources(_local)
    assert [r.kind for r in _res] == ["Namespace", "GatewayClass", "EnvoyProxy", "Gateway", "ClusterIssuer", "Certificate", "ClusterIssuer", "Certificate", "HTTPRoute"]
    _gwr = [r for r in _res if r.kind == "Gateway"][0]
    assert _gwr.spec.gatewayClassName == "platform-gateway"
    assert _gwr.spec.addresses == [{type = "IPAddress", value = "192.168.49.2"}]
    assert [l.name for l in _gwr.spec.listeners] == ["http", "https"]
    assert _gwr.spec.listeners[1].tls.certificateRefs[0].name == "platform-gateway-tls"
    _proxy = [r for r in _res if r.kind == "EnvoyProxy"][0]
    assert _proxy.spec.provider.kubernetes.envoyService.type == "NodePort"
    assert _proxy.spec.provider.kubernetes.envoyDeployment.replicas == 1
    _class = [r for r in _res if r.kind == "GatewayClass"][0]
    assert _class.spec.controllerName == "gateway.envoyproxy.io/gatewayclass-controller"
    _redirect = [r for r in _res if r.kind == "HTTPRoute"][0]
    assert _redirect.spec.parentRefs[0].sectionName == "http"
    assert _redirect.spec.rules[0].filters[0].requestRedirect.scheme == "https"
}

test_gateway_resources_http_only_production = lambda {
    _res = gw.build_gateway_resources(gw.GatewaySpec {name = "edge", namespace = "edge"})
    assert [r.kind for r in _res] == ["Namespace", "GatewayClass", "EnvoyProxy", "Gateway"]
    _proxy = [r for r in _res if r.kind == "EnvoyProxy"][0]
    assert _proxy.spec.provider.kubernetes.envoyService.type == "LoadBalancer"
    assert _proxy.spec.provider.kubernetes.envoyDeployment.replicas == 3
}

test_gateway_spec_requires_issuer_for_tls = lambda {
    _err = runtime.catch(lambda {
        gw.GatewaySpec {name = "edge", namespace = "edge", tlsHostnames = ["example.com"]}
    })
    assert _err != Undefined, "Expected validation error for TLS without issuer"
}

test_gateway_spec_rejects_selfsigned_in_production = lambda {
    _err = runtime.catch(lambda {
        gw.GatewaySpec {name = "edge", namespace = "edge", tlsHostnames = ["example.com"], selfSignedCA = True}
    })
    assert _err != Undefined, "Expected validation error for self-signed CA in production"
}

test_gateway_xr_spec = lambda {
    _xr = gw.build_gateway_xr_spec(_local)
    assert _xr.gatewayName == "platform-gateway"
    assert _xr.namespace == "gateway-system"
    assert _xr.controller.version == gw.ENVOY_GATEWAY_VERSION
    assert _xr.serviceType == "NodePort"
    assert _xr.tls.hostnames == ["example.com"]
    assert _xr.tls.selfSignedCA
    assert "issuerRef" not in _xr.tls
    _prod = gw.build_gateway_xr_spec(gw.GatewaySpec {name = "edge", namespace = "edge", tlsHostnames = ["example.com"], issuerName = "letsencrypt-prod"})
    assert _prod.tls.issuerRef == {name = "letsencrypt-prod", kind = "ClusterIssuer"}
    assert _prod.environment == "production"
}

test_gateway_crossplane_output_is_curated_xgateway = lambda {
    _acc = accessory.AccessoryInstance {
        name = "platform-gateway"
        kind = "CRD"
        namespace = "gateway-system"
        component = "gateway"
        crossplaneSpec = gw.build_gateway_xr_spec(_local)
        configurations = {}
        asset = {version = gw.ENVOY_GATEWAY_VERSION}
        leaders = []
        manifests = gw.build_gateway_resources(_local)
        dependsOn = []
    }
    _out = crossplane_proc.generate_crossplane_from_stack([], [_acc], [], "platform", "0.1.0")
    assert len(_out.managed_resources) == 1
    assert _out.managed_resources[0].kind == "XGateway"
    assert _out.managed_resources[0].metadata.name == "platform-gateway"
    assert _out.managed_resources[0].spec.addresses == ["192.168.49.2"]
    assert _out.metadata.resourceCount == 0
}
