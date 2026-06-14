"""
Gateway API Template — Modern Kubernetes API Gateway

Deploys a Gateway API infrastructure controller. Gateway API is a modern, actively developed
alternative to Ingress that provides better support for L7 traffic management, multiple protocols,
cross-namespace routing, and delegation.

Implementations:
- NGINX Gateway Fabric: Reference implementation with NGINX backend
- Envoy Gateway: Envoy-based implementation
- Istio: Service mesh with Gateway API support

Usage:
    import templates.gateway_api.v1_0_0.gateway_api as gw

    _gateway_controller = gw.build_gateway_controller({
        name = "envoy-gateway"
        namespace = "envoy-gateway-system"
        provider = "envoy"
    })
"""

_ENVOY_GATEWAY_CHART = "oci://registry-1.docker.io/envoyproxy/gateway-helm"
_ENVOY_GATEWAY_VERSION = "1.2.2"

_NGINX_GATEWAY_CHART = "oci://registry-1.docker.io/nginxcontainer/nginx-gateway-fabric"
_NGINX_GATEWAY_VERSION = "1.4.0"

build_gateway_controller = lambda spec: any {
    _chart = _ENVOY_GATEWAY_CHART if spec.provider == "envoy" else _NGINX_GATEWAY_CHART if spec.provider == "nginx" else _ENVOY_GATEWAY_CHART
    _version = spec.chartVersion if spec.chartVersion is not Undefined else (_ENVOY_GATEWAY_VERSION if spec.provider == "envoy" else _NGINX_GATEWAY_VERSION)

    {
        apiVersion = "helm.toolkit.fluxcd.io/v2beta1"
        kind = "HelmRelease"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            interval = "5m"
            chart = {
                spec = {
                    chart = "gateway" if spec.provider == "envoy" else "nginx-gateway"
                    version = _version
                    sourceRef = {
                        kind = "HelmRepository"
                        name = spec.provider
                        namespace = "flux-system"
                    }
                }
            }
            values = {
                "replicaCount" = str(spec.replicas if spec.replicas is not Undefined else 2)
                "service.type" = spec.serviceType if spec.serviceType is not Undefined else "LoadBalancer"
            }
            serviceAccountName = spec.name
        }
    }
}

build_gateway = lambda spec: any {
    {
        apiVersion = "gateway.networking.k8s.io/v1"
        kind = "Gateway"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            gatewayClassName = spec.gatewayClassName
            listeners = [{
                name = "http"
                port = spec.port if spec.port is not Undefined else 80
                "protocol" = spec.protocolType if spec.protocolType is not Undefined else "HTTP"
                hostname = spec.hostname if spec.hostname is not Undefined else None
                allowedRoutes = {
                    namespaces = {
                        from = "Same"
                    }
                }
            }]
        }
    }
}


