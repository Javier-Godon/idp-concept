import runtime
import builders.storage as store

# === Test: PVC with defaults (Ceph storage class) ===
test_build_pv_pvc_defaults = lambda {
    _spec = store.PersistentVolumeSpec {
        name = "test-db"
        namespace = "infra"
    }
    _result = store.build_pv_and_pvc(_spec)
    assert len(_result) == 1

    _pvc = _result[0]
    assert _pvc.kind == "PersistentVolumeClaim"
    assert _pvc.apiVersion == "v1"
    assert _pvc.metadata.name == "test-db-pvc"
    assert _pvc.metadata.namespace == "infra"
    assert _pvc.spec.resources.requests.storage == "20Gi"
    assert _pvc.spec.accessModes == ["ReadWriteOnce"]
    assert _pvc.spec.storageClassName == "rook-ceph-block"
}

# === Test: PV and PVC with custom values and local PV enabled ===
test_build_pv_pvc_custom_with_local_pv = lambda {
    _spec = store.PersistentVolumeSpec {
        name = "postgres"
        namespace = "data"
        size = "100Gi"
        storageClassName = "fast-ssd"
        accessMode = "ReadWriteMany"
        reclaimPolicy = "Delete"
        hostPath = "/data/postgres"
        createPersistentVolume = True
    }
    _result = store.build_pv_and_pvc(_spec)
    assert len(_result) == 2

    _pv = _result[0]
    assert _pv.spec.capacity.storage == "100Gi"
    assert _pv.spec.storageClassName == "fast-ssd"
    assert _pv.spec.accessModes == ["ReadWriteMany"]
    assert _pv.spec.persistentVolumeReclaimPolicy == "Delete"
    assert _pv.spec.hostPath.path == "/data/postgres"

    _pvc = _result[1]
    assert _pvc.spec.storageClassName == "fast-ssd"
    assert _pvc.spec.accessModes == ["ReadWriteMany"]
    assert _pvc.spec.resources.requests.storage == "100Gi"
}

# === Test: PV has type=local label ===
test_build_pv_type_label = lambda {
    _spec = store.PersistentVolumeSpec {
        name = "db"
        namespace = "ns"
        createPersistentVolume = True
    }
    _result = store.build_pv_and_pvc(_spec)
    _pv = _result[0]
    assert _pv.metadata.labels.$type == "local"
}

# === Test: Custom storage class without local PV ===
test_build_pvc_custom_storage_class_only = lambda {
    _spec = store.PersistentVolumeSpec {
        name = "redis"
        namespace = "infra"
        storageClassName = "ceph-rbd"
    }
    _result = store.build_pv_and_pvc(_spec)
    assert len(_result) == 1
    _pvc = _result[0]
    assert _pvc.kind == "PersistentVolumeClaim"
    assert _pvc.spec.storageClassName == "ceph-rbd"
}

# ====================================================================
# Validation Tests (check blocks)
# ====================================================================

# === Test: Invalid access mode ===
test_storage_invalid_access_mode = lambda {
    _msg = runtime.catch(lambda {
        store.PersistentVolumeSpec {
            name = "db"
            namespace = "ns"
            accessMode = "ReadWriteAll"
        }
    })
    assert _msg == "accessMode must be ReadWriteOnce, ReadOnlyMany, or ReadWriteMany"
}

# === Test: Invalid reclaim policy ===
test_storage_invalid_reclaim_policy = lambda {
    _msg = runtime.catch(lambda {
        store.PersistentVolumeSpec {
            name = "db"
            namespace = "ns"
            reclaimPolicy = "Destroy"
        }
    })
    assert _msg == "reclaimPolicy must be Retain, Delete, or Recycle"
}
