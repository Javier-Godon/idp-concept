"""
Apache APISIX Template — API Gateway deployed via Helm chart.

Apache APISIX is a dynamic, real-time API gateway built on NGINX and etcd.
It is deployed via official Helm chart. This template provides sensible defaults
for chart version, ports, persistence, and resources across all environments.

Official Helm chart: https://apisix.apache.org/docs/helm-chart/
Chart repo: https://charts.apiseven.com (chart: apisix/apisix)

Usage:
    import templates.apisix.v1_0_0.apisix as apisix

    _spec = apisix.APIGatewaySpec {
        name = "my-gateway"
        namespace = "gateway"
        footprint = "production"
    }
    _module = apisix.APIGatewayModule {
        name = "my-gateway"
        namespace = "gateway"
        footprint = "production"
    }.instance
"""
import models.modules.accessory as accessory
import models.modules.thirdparty_helm as th
import templates.footprints.v1_0_0.footprint as fp
import builders.leader as leader

schema APIGatewaySpec:
    """Specification for deploying Apache APISIX via Helm chart."""
    name: str
    namespace: str
    chartVersion: str = "2.4.0"
    footprint: str = "production"

    # Admin API
    adminEnabled: bool = True
    adminPort: int = 9180

    # Gateway ports
    gatewayHttpPort: int = 80
    gatewayHttpsPort: int = 443

    # etcd backend (bundled with Helm chart)
    etcdReplicas?: int
    etcdStorageSize?: str

    # Resource requests/limits
    cpuRequest?: str
    memoryRequest?: str
    cpuLimit?: str
    memoryLimit?: str

    # Dashboard
    dashboardEnabled: bool = True
    dashboardPort: int = 3000

    # Extra Helm values (flat key=value)
    extraValues?: {str:str}

    check:
        len(name) > 0, "APISIX release name must not be empty"
        len(namespace) > 0, "APISIX namespace must not be empty"
        adminPort > 0 and adminPort <= 65535, "adminPort must be valid"
        gatewayHttpPort > 0 and gatewayHttpPort <= 65535, "gatewayHttpPort must be valid"
        dashboardPort > 0 and dashboardPort <= 65535, "dashboardPort must be valid"

build_apisix_release = lambda spec: APIGatewaySpec -> any {
    _replicas = fp.replicas(spec.footprint)
    _admin_resources = fp.resource_values(spec.footprint, "50m", "100m", "64Mi", "256Mi")
    _gateway_resources = fp.resource_values(spec.footprint, "100m", "500m", "128Mi", "512Mi")
    _etcd_resources = fp.resource_values(spec.footprint, "50m", "100m", "64Mi", "256Mi")

    # Build values dict from spec fields
    _gateway_values: {str:str} = {"gateway.type" = "LoadBalancer" if spec.footprint == "production" else "NodePort", "gateway.http.port" = str(spec.gatewayHttpPort), "gateway.https.port" = str(spec.gatewayHttpsPort)}

    _admin_values: {str:str} = {if spec.adminEnabled: "admin.enabled" = "true", "admin.port" = str(spec.adminPort)}

    _dashboard_values: {str:str} = {if spec.dashboardEnabled: "dashboard.enabled" = "true", "dashboard.port" = str(spec.dashboardPort)}

    _replicas_values: {str:str} = {"apisix.replicas" = str(_replicas), "etcd.replicaCount" = str(spec.etcdReplicas or _replicas)}

    _resource_values: {str:str} = (
        {} | ({} if not spec.cpuRequest else {"apisix.resources.requests.cpu" = spec.cpuRequest})
        | ({} if not spec.memoryRequest else {"apisix.resources.requests.memory" = spec.memoryRequest})
        | ({} if not spec.cpuLimit else {"apisix.resources.limits.cpu" = spec.cpuLimit})
        | ({} if not spec.memoryLimit else {"apisix.resources.limits.memory" = spec.memoryLimit})
    )

    _etcd_values: {str:str} = {if spec.etcdStorageSize: "etcd.persistence.size" = spec.etcdStorageSize}

    _persistence_values: {str:str} = {"etcd.persistence.enabled" = "true" if spec.footprint != "local" else "false"}

    _all_values: {str:str} = _gateway_values | _admin_values | _dashboard_values | _replicas_values | _resource_values | _etcd_values | _persistence_values | (spec.extraValues or {})

    _helm_spec = th.ThirdPartyHelmSpec {
        name = spec.name
        namespace = spec.namespace
        chart = "apisix/apisix"
        version = spec.chartVersion
        values = _all_values
    }

    th.build_thirdparty_helm(_helm_spec)
}

schema APIGatewayModule(accessory.Accessory):
    """High-level template for Apache APISIX API Gateway via Helm chart."""
    kind = "CRD"

    # Settings
    footprint: str = "production"
    adminEnabled: bool = True
    adminPort: int = 9180
    gatewayHttpPort: int = 80
    gatewayHttpsPort: int = 443
    dashboardEnabled: bool = True
    dashboardPort: int = 3000
    etcdReplicas?: int
    etcdStorageSize?: str
    cpuRequest?: str
    memoryRequest?: str
    cpuLimit?: str
    memoryLimit?: str
    extraValues?: {str:str}

    # Auto-computed
    leaders = [leader.build_accessory_leader(name, namespace, "Release", "helm.crossplane.io/v1beta1")]

    _spec = APIGatewaySpec {
        name = name
        namespace = namespace
        footprint = footprint
        adminEnabled = adminEnabled
        adminPort = adminPort
        gatewayHttpPort = gatewayHttpPort
        gatewayHttpsPort = gatewayHttpsPort
        dashboardEnabled = dashboardEnabled
        dashboardPort = dashboardPort
        if etcdReplicas:
            etcdReplicas = etcdReplicas
        if etcdStorageSize:
            etcdStorageSize = etcdStorageSize
        if cpuRequest:
            cpuRequest = cpuRequest
        if memoryRequest:
            memoryRequest = memoryRequest
        if cpuLimit:
            cpuLimit = cpuLimit
        if memoryLimit:
            memoryLimit = memoryLimit
        if extraValues:
            extraValues = extraValues
    }

    manifests = [build_apisix_release(_spec)]



