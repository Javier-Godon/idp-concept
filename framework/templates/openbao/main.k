"""
OpenBao Template — deploys OpenBao via HelmRelease using ThirdPartyHelmSpec.
Production defaults prefer HA mode with Raft storage.

Usage:
    import templates.openbao as openbao

    _spec = openbao.OpenBaoSpec {
        name = "openbao"
        namespace = "security"
    }
    _manifest = openbao.build_openbao_release(_spec)
"""
import models.modules.thirdparty_helm as th
import models.modules.accessory as accessory
import builders.leader as leader

_HELM_RELEASE_API = "helm.toolkit.fluxcd.io/v2beta1"

schema OpenBaoSpec:
    """Specification for deploying OpenBao via Helm chart."""
    name: str
    namespace: str
    chartVersion: str = "0.8.1"
    mode?: "standalone" | "ha" = "ha"
    replicas?: int = 3
    storageSize?: str = "10Gi"
    storageClassName?: str = "rook-ceph-block"
    uiEnabled?: bool = True
    serviceType?: str = "ClusterIP"
    tlsDisable?: bool = False
    extraValues?: {str:str}

    check:
        len(name) > 0, "OpenBao release name must not be empty"
        len(namespace) > 0, "OpenBao namespace must not be empty"
        replicas >= 1 if replicas is not Undefined, "replicas must be >= 1"
        replicas >= 3 if mode == "ha", "replicas must be >= 3 in ha mode"
        len(storageSize) > 0 if storageSize is not Undefined, "storageSize must not be empty"
        serviceType in ["ClusterIP", "NodePort", "LoadBalancer"] if serviceType is not Undefined, "serviceType must be ClusterIP, NodePort, or LoadBalancer"

build_openbao_release = lambda spec: OpenBaoSpec -> any {
    _ha_enabled = spec.mode == "ha"
    _base_values: {str:str} = {
        "server.dev.enabled" = "false"
        "server.ha.enabled" = "true" if _ha_enabled else "false"
        "server.standalone.enabled" = "false" if _ha_enabled else "true"
        "server.ha.replicas" = str(spec.replicas)
        "server.ha.raft.enabled" = "true" if _ha_enabled else "false"
        "server.ha.raft.setNodeId" = "true" if _ha_enabled else "false"
        "ui.enabled" = "true" if spec.uiEnabled else "false"
        "global.tlsDisable" = "true" if spec.tlsDisable else "false"
        "server.service.type" = spec.serviceType
    }
    _storage_values: {str:str} = {
        if spec.storageSize:
            "server.dataStorage.enabled" = "true"
            "server.dataStorage.size" = spec.storageSize
        if spec.storageClassName:
            "server.dataStorage.storageClass" = spec.storageClassName
    }
    _all_values: {str:str} = _base_values | _storage_values | (spec.extraValues or {})

    _helm_spec = th.ThirdPartyHelmSpec {
        name = spec.name
        namespace = spec.namespace
        repository = "https://openbao.github.io/openbao-helm"
        chart = "openbao/openbao"
        version = spec.chartVersion
        values = _all_values
    }

    th.build_thirdparty_helm(_helm_spec)
}

schema OpenBaoModule(accessory.Accessory):
    """Accessory wrapper for deploying OpenBao HelmRelease in a stack."""
    kind = "CRD"

    openbaoName: str
    chartVersion?: str = "0.8.1"
    mode?: "standalone" | "ha" = "ha"
    replicas?: int = 3
    storageSize?: str = "10Gi"
    storageClassName?: str = "rook-ceph-block"
    uiEnabled?: bool = True
    serviceType?: str = "ClusterIP"
    tlsDisable?: bool = False
    extraValues?: {str:str}

    leaders = [leader.build_accessory_leader(openbaoName, namespace, "HelmRelease", _HELM_RELEASE_API)]

    _openbao_manifest = build_openbao_release(OpenBaoSpec {
        name = openbaoName
        namespace = namespace
        chartVersion = chartVersion
        mode = mode
        replicas = replicas
        storageSize = storageSize
        storageClassName = storageClassName
        uiEnabled = uiEnabled
        serviceType = serviceType
        tlsDisable = tlsDisable
        extraValues = extraValues
    })

    manifests = [_openbao_manifest]

