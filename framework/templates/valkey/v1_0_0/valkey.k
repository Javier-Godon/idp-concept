"""
Valkey Template — deploys Valkey via HelmRelease using ThirdPartyHelmSpec.
Production defaults prefer replication mode and persistent storage.

Usage:
    import templates.valkey.v1_0_0.valkey as valkey

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
import templates.footprints.v1_0_0.footprint as fp
import templates.admin.v1_0_0.data_admin as admin

_HELM_RELEASE_API = "helm.toolkit.fluxcd.io/v2beta1"

schema ValkeySpec:
    """Specification for deploying Valkey via Helm chart."""
    name: str
    namespace: str
    chartVersion: str = "2.1.3"
    footprint?: str = "production"
    mode?: "standalone" | "replication" = "replication"
    storageSize?: str
    storageClassName?: str
    replicas?: int
    serviceType?: str = "ClusterIP"
    authEnabled?: bool = False
    extraValues?: {str:str}

    check:
        len(name) > 0, "Valkey release name must not be empty"
        len(namespace) > 0, "Valkey namespace must not be empty"
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"
        len(storageSize) > 0 if storageSize is not Undefined, "Valkey storageSize must not be empty"
        replicas >= 1 if replicas is not Undefined, "replicas must be >= 1"
        replicas >= 2 if mode == "replication" and replicas is not Undefined, "replicas must be >= 2 in replication mode"
        serviceType in ["ClusterIP", "NodePort", "LoadBalancer"] if serviceType is not Undefined, "serviceType must be ClusterIP, NodePort, or LoadBalancer"

schema ValkeySettings:
    """Effective mode/replicas/storage after footprint defaults; shared by every output path."""
    spec: ValkeySpec
    mode: str = "standalone" if spec.footprint in ["local", "development"] and spec.mode == "replication" else spec.mode
    replicas: int = spec.replicas if spec.replicas is not Undefined else fp.replicas(spec.footprint, 1, 1, 2, 3)
    storageSize: str = spec.storageSize if spec.storageSize is not Undefined else fp.storage_size(spec.footprint, "512Mi", "1Gi", "4Gi", "8Gi")
    storageClass?: str = spec.storageClassName if spec.storageClassName is not Undefined else fp.storage_class(spec.footprint)

build_valkey_xr_spec = lambda spec: ValkeySpec -> {str:} {
    """XValkeyInstance spec (crossplane_v2/managed_resources/valkey) for the crossplane output.
    `replicas` counts replicas besides the primary, as in the Helm chart, so nodeCount = replicas + 1."""
    _s = ValkeySettings {spec = spec}
    {
        clusterName = spec.name
        mode = _s.mode
        if _s.mode == "replication":
            nodeCount = _s.replicas + 1
        storageSize = _s.storageSize
        if _s.storageClass:
            storageClass = _s.storageClass
        environment = spec.footprint
    }
}

build_valkey_release = lambda spec: ValkeySpec -> any {
    _s = ValkeySettings {spec = spec}
    _mode = _s.mode
    _is_replication = _mode == "replication"
    _replicas = _s.replicas
    _storage_size = _s.storageSize
    _storage_class = _s.storageClass
    _base_values: {str:str} = {
        "architecture" = _mode
        "replica.replicaCount" = str(_replicas)
        "auth.enabled" = "true" if spec.authEnabled else "false"
        "master.persistence.enabled" = "false" if spec.footprint == "local" else "true"
        "master.persistence.size" = _storage_size
        "replica.persistence.enabled" = "true" if _is_replication else "false"
        "replica.persistence.size" = _storage_size
        "master.service.type" = spec.serviceType
        "replica.service.type" = spec.serviceType
    }
    _ha_values: {str:str} = {
        if _is_replication:
            "podAntiAffinityPreset" = "soft"
    }
    _storage_class_values: {str:str} = {
        if _storage_class:
            "master.persistence.storageClass" = _storage_class
        if _storage_class and _is_replication:
            "replica.persistence.storageClass" = _storage_class
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
    """Accessory wrapper for deploying Valkey in a stack.
    YAML/Helm outputs emit a HelmRelease; the crossplane output emits an XValkeyInstance XR."""
    kind = "CRD"
    component = "valkey"

    valkeyName: str
    chartVersion?: str = "2.1.3"
    footprint?: str = "production"
    mode?: "standalone" | "replication" = "replication"
    storageSize?: str
    storageClassName?: str
    replicas?: int
    serviceType?: str = "ClusterIP"
    authEnabled?: bool = False
    extraValues?: {str:str}
    adminUi?: admin.RedisInsightSpec
    leaders = [leader.build_accessory_leader(valkeyName, namespace, "HelmRelease", _HELM_RELEASE_API)]

    _valkey_spec = ValkeySpec {
        name = valkeyName
        namespace = namespace
        chartVersion = chartVersion
        footprint = footprint
        mode = mode
        storageSize = storageSize
        storageClassName = storageClassName
        replicas = replicas
        serviceType = serviceType
        authEnabled = authEnabled
        extraValues = extraValues
    }
    _valkey_manifest = build_valkey_release(_valkey_spec)
    crossplaneSpec = build_valkey_xr_spec(_valkey_spec)

    _admin_manifests = admin.build_redis_insight_resources(adminUi) if adminUi else []

    manifests = [_valkey_manifest] + _admin_manifests

