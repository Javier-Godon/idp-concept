"""
Storage Builder — generates PersistentVolume and PersistentVolumeClaim from a high-level spec.
"""

schema PersistentVolumeSpec:
    name: str
    namespace: str
    size?: str = "20Gi"
    storageClassName?: str = "rook-ceph-block"
    accessMode?: str = "ReadWriteOnce"
    reclaimPolicy?: str = "Retain"
    hostPath?: str = "/mnt/data"
    createPersistentVolume?: bool = False

    check:
        accessMode in ["ReadWriteOnce", "ReadOnlyMany", "ReadWriteMany"] if accessMode, "accessMode must be ReadWriteOnce, ReadOnlyMany, or ReadWriteMany"
        reclaimPolicy in ["Retain", "Delete", "Recycle"] if reclaimPolicy, "reclaimPolicy must be Retain, Delete, or Recycle"

build_pv_and_pvc = lambda spec: PersistentVolumeSpec -> [any] {
    _storage_class = spec.storageClassName if spec.storageClassName else "rook-ceph-block"
    _pv = {
        apiVersion = "v1"
        kind = "PersistentVolume"
        metadata = {
            name = "${spec.name}-pv"
            namespace = spec.namespace
            labels = {
                $type = "local"
            }
        }
        spec = {
            storageClassName = _storage_class
            accessModes = [spec.accessMode]
            capacity = {
                storage = spec.size
            }
            persistentVolumeReclaimPolicy = spec.reclaimPolicy
            hostPath = {
                path = spec.hostPath
            }
        }
    }
    _pvc = {
        apiVersion = "v1"
        kind = "PersistentVolumeClaim"
        metadata = {
            name = "${spec.name}-pvc"
            namespace = spec.namespace
        }
        spec = {
            storageClassName = _storage_class
            accessModes = [spec.accessMode]
            resources = {
                requests = {
                    storage = spec.size
                }
            }
        }
    }
    [_pv, _pvc] if spec.createPersistentVolume else [_pvc]
}
