"""
Ceph Template — deploys Rook Ceph operator and a CephCluster CR.

Production pattern:
- install Rook operator with HelmRelease
- create CephCluster custom resource for the storage control plane
- create CephBlockPool + StorageClass (rook-ceph-block) for PVC provisioning

Usage:
    import templates.ceph.v1_0_0.ceph as ceph

    _spec = ceph.CephSpec {
        name = "rook-ceph"
        namespace = "storage"
    }
    _resources = ceph.build_ceph_resources(_spec)
"""

import models.modules.thirdparty_helm as th
import models.modules.accessory as accessory
import builders.leader as leader

_CEPH_API_VERSION = "ceph.rook.io/v1"
_HELM_RELEASE_API = "helm.toolkit.fluxcd.io/v2beta1"

schema CephSpec:
    """Specification for deploying Rook Ceph operator + CephCluster."""
    name: str
    namespace: str
    clusterName?: str = "rook-ceph"
    createBlockPoolAndStorageClass?: bool = True
    blockPoolName?: str = "replicapool"
    blockPoolReplicatedSize?: int = 3
    blockPoolFailureDomain?: str = "host"
    storageClassName?: str = "rook-ceph-block"
    reclaimPolicy?: str = "Delete"
    chartVersion: str = "1.15.2"
    cephImage?: str = "quay.io/ceph/ceph:v19.2.3"
    monCount?: int = 3
    mgrCount?: int = 2
    storageUseAllNodes?: bool = True
    storageUseAllDevices?: bool = True
    storageDeviceFilter?: str
    enableDashboard?: bool = True
    csiEnabled?: bool = True
    monitoringEnabled?: bool = False
    discoveryEnabled?: bool = True
    pspEnable?: bool = False
    extraValues?: {str:str}

    check:
        len(name) > 0, "Ceph release name must not be empty"
        len(namespace) > 0, "Ceph namespace must not be empty"
        monCount >= 1 if monCount != Undefined, "monCount must be >= 1"
        mgrCount >= 1 if mgrCount != Undefined, "mgrCount must be >= 1"
        blockPoolReplicatedSize >= 1 if blockPoolReplicatedSize != Undefined, "blockPoolReplicatedSize must be >= 1"
        reclaimPolicy in ["Delete", "Retain"] if reclaimPolicy != Undefined, "reclaimPolicy must be Delete or Retain"

build_ceph_block_pool = lambda spec: CephSpec -> any {
    {
        apiVersion = _CEPH_API_VERSION
        kind = "CephBlockPool"
        metadata = {
            name = spec.blockPoolName
            namespace = spec.namespace
        }
        spec = {
            failureDomain = spec.blockPoolFailureDomain
            replicated = {
                size = spec.blockPoolReplicatedSize
            }
        }
    }
}

build_ceph_storage_class = lambda spec: CephSpec -> any {
    {
        apiVersion = "storage.k8s.io/v1"
        kind = "StorageClass"
        metadata = {
            name = spec.storageClassName
        }
        provisioner = "rook-ceph.rbd.csi.ceph.com"
        parameters = {
            clusterID = spec.namespace
            pool = spec.blockPoolName
            imageFormat = "2"
            imageFeatures = "layering"
            "csi.storage.k8s.io/provisioner-secret-name" = "rook-csi-rbd-provisioner"
            "csi.storage.k8s.io/provisioner-secret-namespace" = spec.namespace
            "csi.storage.k8s.io/node-stage-secret-name" = "rook-csi-rbd-node"
            "csi.storage.k8s.io/node-stage-secret-namespace" = spec.namespace
            "csi.storage.k8s.io/fstype" = "ext4"
        }
        reclaimPolicy = spec.reclaimPolicy
        allowVolumeExpansion = True
        volumeBindingMode = "Immediate"
    }
}

build_ceph_cluster = lambda spec: CephSpec -> any {
    _storage_spec = {
        useAllNodes = spec.storageUseAllNodes
        useAllDevices = spec.storageUseAllDevices
        if spec.storageDeviceFilter:
            deviceFilter = spec.storageDeviceFilter
    }
    {
        apiVersion = _CEPH_API_VERSION
        kind = "CephCluster"
        metadata = {
            name = spec.clusterName
            namespace = spec.namespace
        }
        spec = {
            cephVersion = {
                image = spec.cephImage
            }
            mon = {
                count = spec.monCount
                allowMultiplePerNode = False
            }
            mgr = {
                count = spec.mgrCount
                allowMultiplePerNode = False
            }
            dashboard = {
                enabled = spec.enableDashboard
            }
            monitoring = {
                enabled = spec.monitoringEnabled
            }
            storage = _storage_spec
        }
    }
}

build_ceph_release = lambda spec: CephSpec -> any {
    _base_values: {str:str} = {
        "csi.enableCSI" = "true" if spec.csiEnabled else "false"
        "monitoring.enabled" = "true" if spec.monitoringEnabled else "false"
        "enableDiscoveryDaemon" = "true" if spec.discoveryEnabled else "false"
        "pspEnable" = "true" if spec.pspEnable else "false"
    }
    _all_values: {str:str} = _base_values | (spec.extraValues or {})

    _helm_spec = th.ThirdPartyHelmSpec {
        name = spec.name
        namespace = spec.namespace
        repository = "https://charts.rook.io/release"
        chart = "rook-release/rook-ceph"
        version = spec.chartVersion
        values = _all_values
    }

    th.build_thirdparty_helm(_helm_spec)
}

build_ceph_resources = lambda spec: CephSpec -> [any] {
    _storage_resources = [
        build_ceph_block_pool(spec)
        build_ceph_storage_class(spec)
    ] if spec.createBlockPoolAndStorageClass else []
    [
        build_ceph_release(spec)
        build_ceph_cluster(spec)
    ] + _storage_resources
}

schema CephModule(accessory.Accessory):
    """Accessory wrapper that emits Rook operator HelmRelease + CephCluster."""
    kind = "CRD"

    cephName: str
    clusterName?: str = "rook-ceph"
    createBlockPoolAndStorageClass?: bool = True
    blockPoolName?: str = "replicapool"
    blockPoolReplicatedSize?: int = 3
    blockPoolFailureDomain?: str = "host"
    storageClassName?: str = "rook-ceph-block"
    reclaimPolicy?: str = "Delete"
    chartVersion?: str = "1.15.2"
    cephImage?: str = "quay.io/ceph/ceph:v19.2.3"
    monCount?: int = 3
    mgrCount?: int = 2
    storageUseAllNodes?: bool = True
    storageUseAllDevices?: bool = True
    storageDeviceFilter?: str
    enableDashboard?: bool = True
    csiEnabled?: bool = True
    monitoringEnabled?: bool = False
    discoveryEnabled?: bool = True
    pspEnable?: bool = False
    extraValues?: {str:str}
    leaders = [leader.build_accessory_leader(clusterName, namespace, "CephCluster", _CEPH_API_VERSION)]

    _ceph_resources = build_ceph_resources(CephSpec {
        name = cephName
        namespace = namespace
        clusterName = clusterName
        createBlockPoolAndStorageClass = createBlockPoolAndStorageClass
        blockPoolName = blockPoolName
        blockPoolReplicatedSize = blockPoolReplicatedSize
        blockPoolFailureDomain = blockPoolFailureDomain
        storageClassName = storageClassName
        reclaimPolicy = reclaimPolicy
        chartVersion = chartVersion
        cephImage = cephImage
        monCount = monCount
        mgrCount = mgrCount
        storageUseAllNodes = storageUseAllNodes
        storageUseAllDevices = storageUseAllDevices
        storageDeviceFilter = storageDeviceFilter
        enableDashboard = enableDashboard
        csiEnabled = csiEnabled
        monitoringEnabled = monitoringEnabled
        discoveryEnabled = discoveryEnabled
        pspEnable = pspEnable
        extraValues = extraValues
    })

    manifests = _ceph_resources

