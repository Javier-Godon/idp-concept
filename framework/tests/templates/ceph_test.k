"""
Ceph Template Tests.

Tests HelmRelease generation for Rook Ceph template defaults and overrides.
"""
import templates.ceph.v1_0_0.ceph as ceph
import runtime

# === Test: default Ceph release ===
test_build_ceph_default = lambda {
    _result = ceph.build_ceph_release(ceph.CephSpec {
        name = "rook-ceph"
        namespace = "storage"
    })
    assert _result.apiVersion == "helm.toolkit.fluxcd.io/v2beta1"
    assert _result.kind == "HelmRelease"
    assert _result.spec.chart == "rook-release/rook-ceph"
    assert _result.spec.version == "1.15.2"
    assert _result.spec.values["csi.enableCSI"] == "true"
    assert _result.spec.values["monitoring.enabled"] == "false"
}

# === Test: custom toggles ===
test_build_ceph_custom = lambda {
    _result = ceph.build_ceph_release(ceph.CephSpec {
        name = "rook-ceph"
        namespace = "storage"
        csiEnabled = False
        monitoringEnabled = True
        discoveryEnabled = False
        pspEnable = True
    })
    assert _result.spec.values["csi.enableCSI"] == "false"
    assert _result.spec.values["monitoring.enabled"] == "true"
    assert _result.spec.values["enableDiscoveryDaemon"] == "false"
    assert _result.spec.values["pspEnable"] == "true"
}

# === Test: validation rejects empty name ===
test_ceph_rejects_empty_name = lambda {
    _err = runtime.catch(lambda {
        ceph.CephSpec {
            name = ""
            namespace = "storage"
        }
    })
    assert _err != Undefined, "Expected validation error for empty name"
}

# === Test: extra values merge ===
test_build_ceph_extra_values = lambda {
    _result = ceph.build_ceph_release(ceph.CephSpec {
        name = "rook-ceph"
        namespace = "storage"
        extraValues = {
            "logLevel" = "DEBUG"
        }
    })
    assert _result.spec.values["logLevel"] == "DEBUG"
}

# === Test: CephCluster resource generation ===
test_build_ceph_cluster = lambda {
    _result = ceph.build_ceph_cluster(ceph.CephSpec {
        name = "rook-ceph"
        namespace = "storage"
        clusterName = "platform-ceph"
    })
    assert _result.apiVersion == "ceph.rook.io/v1"
    assert _result.kind == "CephCluster"
    assert _result.metadata.name == "platform-ceph"
    assert _result.spec.mon.count == 3
    assert _result.spec.mgr.count == 2
    assert _result.spec.dashboard.enabled == True
}

# === Test: CephBlockPool resource generation ===
test_build_ceph_block_pool = lambda {
    _result = ceph.build_ceph_block_pool(ceph.CephSpec {
        name = "rook-ceph"
        namespace = "storage"
    })
    assert _result.apiVersion == "ceph.rook.io/v1"
    assert _result.kind == "CephBlockPool"
    assert _result.metadata.name == "replicapool"
    assert _result.spec.replicated.size == 3
}

# === Test: Ceph StorageClass resource generation ===
test_build_ceph_storage_class = lambda {
    _result = ceph.build_ceph_storage_class(ceph.CephSpec {
        name = "rook-ceph"
        namespace = "storage"
    })
    assert _result.apiVersion == "storage.k8s.io/v1"
    assert _result.kind == "StorageClass"
    assert _result.metadata.name == "rook-ceph-block"
    assert _result.provisioner == "rook-ceph.rbd.csi.ceph.com"
    assert _result.parameters.pool == "replicapool"
}

# === Test: build_ceph_resources emits operator + cluster + storage primitives ===
test_build_ceph_resources = lambda {
    _result = ceph.build_ceph_resources(ceph.CephSpec {
        name = "rook-ceph"
        namespace = "storage"
    })
    assert len(_result) == 4
    assert _result[0].kind == "HelmRelease"
    assert _result[1].kind == "CephCluster"
    assert _result[2].kind == "CephBlockPool"
    assert _result[3].kind == "StorageClass"
}

