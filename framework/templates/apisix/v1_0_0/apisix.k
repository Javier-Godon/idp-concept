"""
Apache APISIX Template — API gateway for REST APIs, deployed via the official Helm chart.

APISIX (Apache-2.0) is the *API gateway* of the platform: it applies per-API policies (rewrite,
authentication, rate limiting, ...) to the REST APIs behind it. It does not replace the Gateway API
(Envoy Gateway), which stays the edge/ingress of the cluster: Envoy Gateway forwards the API prefix
(default `/api`) and the APISIX Admin UI to APISIX. See docs/platform-engineering/API_GATEWAY_VS_GATEWAY_API.md.

Chart apisix/apisix 2.18.0 ships APISIX 3.19.0, the embedded Admin UI (served by the Admin API listener at
`/ui`; it cannot be moved under a sub-path) and, optionally, the Apache apisix-ingress-controller 2.x
(the operator): routes are declared as `ApisixRoute` custom resources instead of Admin API calls.

etcd is the configuration store. The chart bundles a *development/testing* etcd based on the Bitnami legacy
image; it is pinned here because the chart default tag is `latest`. For production prefer an external etcd.

Secrets: the Admin API keys come from an existing Secret (`adminKeySecretName`, keys `admin` and `viewer`)
created out of band — the chart default key is public and must never be used.

Usage:
    import templates.apisix.v1_0_0.apisix as apisix

    _module = apisix.APIGatewayModule {
        name = "apisix"
        namespace = "apisix"
        footprint = "development"
        adminKeySecretName = "apisix-admin-keys"
        etcdStorageClass = "local-path"
        publish = apisix.ApisixPublishSpec {hostname = "example.com"}
    }.instance
"""
import models.modules.accessory as accessory
import models.modules.thirdparty_helm as th
import templates.footprints.v1_0_0.footprint as fp
import builders.leader as leader

DEFAULT_ETCD_IMAGE_TAG = "3.6.4-debian-12-r4"

schema ApisixPublishSpec:
    """How APISIX is published on the platform gateway (Gateway API, Envoy Gateway)."""
    hostname: str
    listener: str = "https"
    gatewayName: str = "platform-gateway"
    gatewayNamespace: str = "gateway-system"
    # Prefix Envoy forwards to the APISIX data plane; APISIX decides what each API path maps to.
    proxyPath: str = "/api"
    # The Admin UI lives at /ui and calls /apisix/admin; `uiEntryPath` redirects to /ui/.
    uiEntryPath: str = "/apisix"

    check:
        proxyPath.startswith("/"), "proxyPath must start with /"
        uiEntryPath.startswith("/"), "uiEntryPath must start with /"
        len(hostname) > 0, "hostname must not be empty"

schema APIGatewaySpec:
    """Specification for deploying Apache APISIX via Helm chart."""
    name: str
    namespace: str
    chartVersion: str = "2.18.0"
    footprint: str = "production"

    # The release name must contain "apisix" so the chart Services are `<name>-gateway` and `<name>-admin`.
    adminKeySecretName: str
    # Client CIDRs allowed to reach the Admin API (pod network: Envoy Gateway proxy, ingress controller).
    adminAllowCidrs: [str] = ["10.244.0.0/16"]
    adminPort: int = 9180
    gatewayHttpPort: int = 80
    gatewayType: str = "ClusterIP"

    # Apache apisix-ingress-controller (operator): reconciles ApisixRoute/ApisixUpstream/... resources
    ingressController: bool = True

    # etcd backend (bundled with the Helm chart, development/testing only)
    etcdReplicas?: int
    etcdStorageSize?: str
    etcdStorageClass?: str
    etcdImageTag: str = DEFAULT_ETCD_IMAGE_TAG

    replicas?: int
    cpuRequest?: str
    memoryRequest?: str
    cpuLimit?: str
    memoryLimit?: str

    publish?: ApisixPublishSpec

    # Extra Helm values (flat key=value)
    extraValues?: {str:str}

    check:
        len(name) > 0, "APISIX release name must not be empty"
        "apisix" in name, "APISIX release name must contain 'apisix'"
        len(namespace) > 0, "APISIX namespace must not be empty"
        len(adminKeySecretName) > 0, "adminKeySecretName must reference an existing Secret"
        adminPort > 0 and adminPort <= 65535, "adminPort must be valid"
        gatewayHttpPort > 0 and gatewayHttpPort <= 65535, "gatewayHttpPort must be valid"
        gatewayType in ["ClusterIP", "NodePort", "LoadBalancer"], "gatewayType must be ClusterIP, NodePort, or LoadBalancer"
        len(adminAllowCidrs) > 0, "adminAllowCidrs must not be empty"
        "latest" not in etcdImageTag, "etcdImageTag must be pinned"

_effective_replicas = lambda spec: APIGatewaySpec -> int {
    spec.replicas if spec.replicas is not Undefined else fp.replicas(spec.footprint, 1, 1, 2, 2)
}

_effective_etcd_replicas = lambda spec: APIGatewaySpec -> int {
    spec.etcdReplicas if spec.etcdReplicas is not Undefined else fp.replicas(spec.footprint, 1, 1, 3, 3)
}

_effective_etcd_storage = lambda spec: APIGatewaySpec -> str {
    spec.etcdStorageSize if spec.etcdStorageSize is not Undefined else fp.storage_size(spec.footprint, "1Gi", "2Gi", "8Gi", "8Gi")
}

build_apisix_xr_spec = lambda spec: APIGatewaySpec -> {str:} {
    """XAPIGateway spec (crossplane_v2/managed_resources/apisix) for the crossplane output."""
    {
        releaseName = spec.name
        namespace = spec.namespace
        chartVersion = spec.chartVersion
        replicas = _effective_replicas(spec)
        adminKeySecretName = spec.adminKeySecretName
        adminAllowCidrs = spec.adminAllowCidrs
        gatewayType = spec.gatewayType
        ingressController = spec.ingressController
        etcd = {
            replicas = _effective_etcd_replicas(spec)
            storageSize = _effective_etcd_storage(spec)
            imageTag = spec.etcdImageTag
            if spec.etcdStorageClass:
                storageClass = spec.etcdStorageClass
        }
        if spec.publish:
            publish = {
                hostname = spec.publish.hostname
                listener = spec.publish.listener
                gatewayName = spec.publish.gatewayName
                gatewayNamespace = spec.publish.gatewayNamespace
                proxyPath = spec.publish.proxyPath
                uiEntryPath = spec.publish.uiEntryPath
            }
        environment = spec.footprint
    }
}

build_apisix_release = lambda spec: APIGatewaySpec -> any {
    _core: {str:str} = {
        "apisix.replicaCount" = str(_effective_replicas(spec))
        "apisix.admin.enabled" = "true"
        "apisix.admin.enable_admin_ui" = "true"
        "apisix.admin.port" = str(spec.adminPort)
        "apisix.admin.credentials.secretName" = spec.adminKeySecretName
        "apisix.admin.credentials.secretAdminKey" = "admin"
        "apisix.admin.credentials.secretViewerKey" = "viewer"
        "service.type" = spec.gatewayType
        "service.http.servicePort" = str(spec.gatewayHttpPort)
        "etcd.replicaCount" = str(_effective_etcd_replicas(spec))
        "etcd.image.tag" = spec.etcdImageTag
        "etcd.persistence.enabled" = "false" if spec.footprint == "local" else "true"
        "etcd.persistence.size" = _effective_etcd_storage(spec)
    }
    _allow: {str:str} = {"apisix.admin.allow.ipList[${i}]" = cidr for i, cidr in spec.adminAllowCidrs}
    _etcd_class: {str:str} = {if spec.etcdStorageClass: "etcd.persistence.storageClass" = spec.etcdStorageClass}
    _controller: {str:str} = {
        if spec.ingressController:
            "ingress-controller.enabled" = "true"
            "ingress-controller.config.disableGatewayAPI" = "true"
            "ingress-controller.webhook.enabled" = "false"
            "ingress-controller.gatewayProxy.createDefault" = "true"
            "ingress-controller.gatewayProxy.provider.controlPlane.service.name" = "${spec.name}-admin"
            "ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.value" = ""
            "ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.valueFrom.secretKeyRef.name" = spec.adminKeySecretName
            "ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.valueFrom.secretKeyRef.key" = "admin"
    }
    _resources: {str:str} = {} | ({} if not spec.cpuRequest else {"apisix.resources.requests.cpu" = spec.cpuRequest}) | ({} if not spec.memoryRequest else {"apisix.resources.requests.memory" = spec.memoryRequest}) | ({} if not spec.cpuLimit else {"apisix.resources.limits.cpu" = spec.cpuLimit}) | ({} if not spec.memoryLimit else {"apisix.resources.limits.memory" = spec.memoryLimit})

    _helm_spec = th.ThirdPartyHelmSpec {
        name = spec.name
        namespace = spec.namespace
        repository = "https://charts.apiseven.com"
        chart = "apisix/apisix"
        version = spec.chartVersion
        values = _core | _allow | _etcd_class | _controller | _resources | (spec.extraValues or {})
    }

    th.build_thirdparty_helm(_helm_spec)
}

schema APIGatewayModule(accessory.Accessory):
    """High-level template for Apache APISIX API Gateway via Helm chart.
    YAML/Helm outputs emit a HelmRelease; the crossplane output emits an XAPIGateway XR."""
    kind = "CRD"
    component = "apisix"

    chartVersion: str = "2.18.0"
    footprint: str = "production"
    adminKeySecretName: str
    adminAllowCidrs: [str] = ["10.244.0.0/16"]
    adminPort: int = 9180
    gatewayHttpPort: int = 80
    gatewayType: str = "ClusterIP"
    ingressController: bool = True
    etcdReplicas?: int
    etcdStorageSize?: str
    etcdStorageClass?: str
    etcdImageTag: str = DEFAULT_ETCD_IMAGE_TAG
    replicas?: int
    cpuRequest?: str
    memoryRequest?: str
    cpuLimit?: str
    memoryLimit?: str
    publish?: ApisixPublishSpec
    extraValues?: {str:str}

    leaders = [leader.build_accessory_leader(name, namespace, "HelmRelease", "helm.toolkit.fluxcd.io/v2beta1")]

    _spec = APIGatewaySpec {
        name = name
        namespace = namespace
        chartVersion = chartVersion
        footprint = footprint
        adminKeySecretName = adminKeySecretName
        adminAllowCidrs = adminAllowCidrs
        adminPort = adminPort
        gatewayHttpPort = gatewayHttpPort
        gatewayType = gatewayType
        ingressController = ingressController
        etcdImageTag = etcdImageTag
        if etcdReplicas:
            etcdReplicas = etcdReplicas
        if etcdStorageSize:
            etcdStorageSize = etcdStorageSize
        if etcdStorageClass:
            etcdStorageClass = etcdStorageClass
        if replicas:
            replicas = replicas
        if cpuRequest:
            cpuRequest = cpuRequest
        if memoryRequest:
            memoryRequest = memoryRequest
        if cpuLimit:
            cpuLimit = cpuLimit
        if memoryLimit:
            memoryLimit = memoryLimit
        if publish:
            publish = publish
        if extraValues:
            extraValues = extraValues
    }

    configurations = _spec
    asset = {version = chartVersion}
    manifests = [build_apisix_release(_spec)]
    crossplaneSpec = build_apisix_xr_spec(_spec)
    dependsOn = []
