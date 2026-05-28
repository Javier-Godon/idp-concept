"""
Longhorn Template — deploys Longhorn via HelmRelease and optionally creates a StorageClass.

Production-friendly defaults:
- install Longhorn manager components using the official chart
- define a Longhorn StorageClass for dynamic PVC provisioning

Usage:
    import templates.longhorn.v1_0_0.longhorn as longhorn

    _spec = longhorn.LonghornSpec {
        name = "longhorn"
        namespace = "longhorn-system"
    }
    _resources = longhorn.build_longhorn_resources(_spec)
"""

import models.modules.thirdparty_helm as th
import models.modules.accessory as accessory
import builders.leader as leader

_HELM_RELEASE_API = "helm.toolkit.fluxcd.io/v2beta1"

schema LonghornSpec:
    """Specification for deploying Longhorn and optional StorageClass."""
    name: str
    namespace: str
    chartVersion: str = "1.7.2"
    storageClassName?: str = "longhorn"
    createStorageClass?: bool = True
    makeStorageClassDefault?: bool = False
    defaultReplicaCount?: int = 2
    defaultDataPath?: str = "/var/lib/longhorn"
    reclaimPolicy?: str = "Delete"
    extraValues?: {str:str}

    check:
        len(name) > 0, "Longhorn release name must not be empty"
        len(namespace) > 0, "Longhorn namespace must not be empty"
        len(storageClassName) > 0 if storageClassName != Undefined, "storageClassName must not be empty"
        defaultReplicaCount >= 1 if defaultReplicaCount != Undefined, "defaultReplicaCount must be >= 1"
        reclaimPolicy in ["Delete", "Retain"] if reclaimPolicy != Undefined, "reclaimPolicy must be Delete or Retain"

build_longhorn_release = lambda spec: LonghornSpec -> any {
    _base_values: {str:str} = {
        "defaultSettings.defaultDataPath" = spec.defaultDataPath
        "defaultSettings.defaultReplicaCount" = str(spec.defaultReplicaCount)
    }
    _all_values: {str:str} = _base_values | (spec.extraValues or {})

    _helm_spec = th.ThirdPartyHelmSpec {
        name = spec.name
        namespace = spec.namespace
        repository = "https://charts.longhorn.io"
        chart = "longhorn/longhorn"
        version = spec.chartVersion
        values = _all_values
    }

    th.build_thirdparty_helm(_helm_spec)
}

build_longhorn_storage_class = lambda spec: LonghornSpec -> any {
    {
        apiVersion = "storage.k8s.io/v1"
        kind = "StorageClass"
        metadata = {
            name = spec.storageClassName
            annotations = {
                if spec.makeStorageClassDefault:
                    "storageclass.kubernetes.io/is-default-class" = "true"
                    "storageclass.beta.kubernetes.io/is-default-class" = "true"
            }
        }
        provisioner = "driver.longhorn.io"
        allowVolumeExpansion = True
        reclaimPolicy = spec.reclaimPolicy
        volumeBindingMode = "Immediate"
        parameters = {
            numberOfReplicas = str(spec.defaultReplicaCount)
            staleReplicaTimeout = "30"
            fsType = "ext4"
        }
    }
}

build_longhorn_resources = lambda spec: LonghornSpec -> [any] {
    _storage_class_resources = [
        build_longhorn_storage_class(spec)
    ] if spec.createStorageClass else []

    [
        build_longhorn_release(spec)
    ] + _storage_class_resources
}

schema LonghornModule(accessory.Accessory):
    """Accessory wrapper that emits Longhorn HelmRelease and optional StorageClass."""
    kind = "CRD"

    longhornName: str
    chartVersion?: str = "1.7.2"
    storageClassName?: str = "longhorn"
    createStorageClass?: bool = True
    makeStorageClassDefault?: bool = False
    defaultReplicaCount?: int = 2
    defaultDataPath?: str = "/var/lib/longhorn"
    reclaimPolicy?: str = "Delete"
    extraValues?: {str:str}

    leaders = [leader.build_accessory_leader(longhornName, namespace, "HelmRelease", _HELM_RELEASE_API)]

    _resources = build_longhorn_resources(LonghornSpec {
        name = longhornName
        namespace = namespace
        chartVersion = chartVersion
        storageClassName = storageClassName
        createStorageClass = createStorageClass
        makeStorageClassDefault = makeStorageClassDefault
        defaultReplicaCount = defaultReplicaCount
        defaultDataPath = defaultDataPath
        reclaimPolicy = reclaimPolicy
        extraValues = extraValues
    })

    manifests = _resources

