"""
Longhorn Template Tests.

Tests HelmRelease and StorageClass generation for Longhorn template defaults and overrides.
"""
import templates.longhorn.v1_0_0.longhorn as longhorn
import runtime

# === Test: default Longhorn release ===
test_build_longhorn_default = lambda {
    _result = longhorn.build_longhorn_release(longhorn.LonghornSpec {
        name = "longhorn"
        namespace = "longhorn-system"
    })
    assert _result.apiVersion == "helm.toolkit.fluxcd.io/v2beta1"
    assert _result.kind == "HelmRelease"
    assert _result.spec.chart == "longhorn/longhorn"
    assert _result.spec.version == "1.7.2"
    assert _result.spec.values["defaultSettings.defaultDataPath"] == "/var/lib/longhorn"
    assert _result.spec.values["defaultSettings.defaultReplicaCount"] == "2"
}

# === Test: Longhorn StorageClass defaults ===
test_build_longhorn_storage_class_default = lambda {
    _result = longhorn.build_longhorn_storage_class(longhorn.LonghornSpec {
        name = "longhorn"
        namespace = "longhorn-system"
    })
    assert _result.apiVersion == "storage.k8s.io/v1"
    assert _result.kind == "StorageClass"
    assert _result.metadata.name == "longhorn"
    assert _result.provisioner == "driver.longhorn.io"
    assert _result.parameters.numberOfReplicas == "2"
    assert _result.reclaimPolicy == "Delete"
}

# === Test: resources include storage class by default ===
test_build_longhorn_resources_default = lambda {
    _result = longhorn.build_longhorn_resources(longhorn.LonghornSpec {
        name = "longhorn"
        namespace = "longhorn-system"
    })
    assert len(_result) == 2
    assert _result[0].kind == "HelmRelease"
    assert _result[1].kind == "StorageClass"
}

# === Test: resources without storage class ===
test_build_longhorn_resources_without_storage_class = lambda {
    _result = longhorn.build_longhorn_resources(longhorn.LonghornSpec {
        name = "longhorn"
        namespace = "longhorn-system"
        createStorageClass = False
    })
    assert len(_result) == 1
    assert _result[0].kind == "HelmRelease"
}

# === Test: validation rejects invalid replica count ===
test_longhorn_rejects_invalid_replica_count = lambda {
    _err = runtime.catch(lambda {
        longhorn.LonghornSpec {
            name = "longhorn"
            namespace = "longhorn-system"
            defaultReplicaCount = 0
        }
    })
    assert _err != Undefined, "Expected validation error for defaultReplicaCount < 1"
}

