"""
Valkey Template — deploys Valkey via HelmRelease using ThirdPartyHelmSpec.
Production defaults prefer replication mode and persistent storage.

Usage:
    import templates.valkey as valkey

    _spec = valkey.ValkeySpec {
        name = "cache"
        namespace = "data"
        storageSize = "10Gi"
    }
    _manifest = valkey.build_valkey_release(_spec)
"""

import models.modules.thirdparty_helm as th
import models.modules.accessory as accessory
import builders.leader as leader

_HELM_RELEASE_API = "helm.toolkit.fluxcd.io/v2beta1"

schema ValkeySpec:
    """Specification for deploying Valkey via Helm chart."""
    name: str
    namespace: str
    chartVersion: str = "2.1.3"
    mode?: "standalone" | "replication" = "replication"
    storageSize: str = "8Gi"
    storageClassName?: str
    replicas?: int = 3
    serviceType?: str = "ClusterIP"
    authEnabled?: bool = False
    extraValues?: {str:str}

    check:
        len(name) > 0, "Valkey release name must not be empty"
        len(namespace) > 0, "Valkey namespace must not be empty"
        len(storageSize) > 0, "Valkey storageSize must not be empty"
        replicas >= 1 if replicas is not Undefined, "replicas must be >= 1"
        replicas >= 2 if mode == "replication", "replicas must be >= 2 in replication mode"
        serviceType in ["ClusterIP", "NodePort", "LoadBalancer"] if serviceType is not Undefined, "serviceType must be ClusterIP, NodePort, or LoadBalancer"

build_valkey_release = lambda spec: ValkeySpec -> any {
    _is_replication = spec.mode == "replication"
    _base_values: {str:str} = {
        "architecture" = spec.mode
        "replica.replicaCount" = str(spec.replicas)
        "auth.enabled" = "true" if spec.authEnabled else "false"
        "master.persistence.enabled" = "true"
        "master.persistence.size" = spec.storageSize
        "replica.persistence.enabled" = "true" if _is_replication else "false"
        "replica.persistence.size" = spec.storageSize
        "master.service.type" = spec.serviceType
        "replica.service.type" = spec.serviceType
    }
    _ha_values: {str:str} = {
        if _is_replication:
            "podAntiAffinityPreset" = "soft"
    }
    _storage_class_values: {str:str} = {
        if spec.storageClassName:
            "master.persistence.storageClass" = spec.storageClassName
        if spec.storageClassName and _is_replication:
            "replica.persistence.storageClass" = spec.storageClassName
    }
    _all_values: {str:str} = _base_values | _ha_values | _storage_class_values | (spec.extraValues or {})

    _helm_spec = th.ThirdPartyHelmSpec {
        name = spec.name
        namespace = spec.namespace
        repository = "https://charts.bitnami.com/bitnami"
        chart = "bitnami/valkey"
        version = spec.chartVersion
        values = _all_values
    }

    th.build_thirdparty_helm(_helm_spec)
}

schema ValkeyModule(accessory.Accessory):
    """Accessory wrapper for deploying Valkey HelmRelease in a stack."""
    kind = "CRD"

    valkeyName: str
    chartVersion?: str = "2.1.3"
    mode?: "standalone" | "replication" = "replication"
    storageSize?: str = "8Gi"
    storageClassName?: str
    replicas?: int = 3
    serviceType?: str = "ClusterIP"
    authEnabled?: bool = False
    extraValues?: {str:str}
    leaders = [leader.build_accessory_leader(valkeyName, namespace, "HelmRelease", _HELM_RELEASE_API)]

    _valkey_manifest = build_valkey_release(ValkeySpec {
        name = valkeyName
        namespace = namespace
        chartVersion = chartVersion
        mode = mode
        storageSize = storageSize
        storageClassName = storageClassName
        replicas = replicas
        serviceType = serviceType
        authEnabled = authEnabled
        extraValues = extraValues
    })

    manifests = [_valkey_manifest]

