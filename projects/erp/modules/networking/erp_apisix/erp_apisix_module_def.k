"""
erp apisix module — Apache APISIX API gateway (Helm chart + apisix-ingress-controller).
The crossplane output renders it as an XAPIGateway reconciled by crossplane_v2/managed_resources/apisix.

Envoy Gateway (platform-gateway) stays the cluster edge: it forwards `/api` (the data plane) and the Admin UI
(`/ui`, `/apisix/admin`, entry point `/apisix`) to APISIX. APIs are declared as ApisixRoute resources next to
their application (see ErpBackendModule). Admin API keys live in a Secret referenced by name only.
"""
import framework.templates.apisix.v1_0_0.apisix as apisix

schema ErpApisixModule(apisix.APIGatewayModule):
    footprint = configurations.apisixFootprint
    adminKeySecretName = configurations.apisixAdminKeySecret
    adminAllowCidrs = configurations.apisixAdminAllowCidrs
    etcdStorageClass = configurations.apisixEtcdStorageClass
    publish = apisix.ApisixPublishSpec {
        hostname = configurations.apisixHostname
        proxyPath = configurations.erpApiPath
    }
