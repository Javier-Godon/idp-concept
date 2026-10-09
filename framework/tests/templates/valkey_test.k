"""
Valkey Template Tests.

Tests HelmRelease generation for Valkey template defaults and overrides,
and the XValkeyInstance spec emitted for the crossplane output.
"""
import templates.valkey.v1_0_0.valkey as valkey
import procedures.kcl_to_crossplane as crossplane_proc
import models.modules.accessory as accessory
import runtime

# === Test: default Valkey release ===
test_build_valkey_default = lambda {
    _result = valkey.build_valkey_release(valkey.ValkeySpec {
        name = "cache"
        namespace = "data"
    })
    assert _result.apiVersion == "helm.toolkit.fluxcd.io/v2beta1"
    assert _result.kind == "HelmRelease"
    assert _result.metadata.name == "cache"
    assert _result.spec.chart == "bitnami/valkey"
    assert _result.spec.version == "2.1.3"
    assert _result.spec.values["architecture"] == "replication"
    assert _result.spec.values["replica.replicaCount"] == "3"
    assert _result.spec.values["master.persistence.size"] == "8Gi"
}

# === Test: custom values are rendered ===
test_build_valkey_custom = lambda {
    _result = valkey.build_valkey_release(valkey.ValkeySpec {
        name = "cache"
        namespace = "data"
        storageSize = "20Gi"
        storageClassName = "fast-ssd"
        replicas = 2
        serviceType = "NodePort"
        authEnabled = True
    })
    assert _result.spec.values["master.persistence.size"] == "20Gi"
    assert _result.spec.values["master.persistence.storageClass"] == "fast-ssd"
    assert _result.spec.values["replica.replicaCount"] == "2"
    assert _result.spec.values["master.service.type"] == "NodePort"
    assert _result.spec.values["auth.enabled"] == "true"
}

# === Test: validation rejects empty storage ===
test_valkey_rejects_empty_storage = lambda {
    _err = runtime.catch(lambda {
        valkey.ValkeySpec {
            name = "cache"
            namespace = "data"
            storageSize = ""
        }
    })
    assert _err != Undefined, "Expected validation error for empty storageSize"
}

# === Test: validation rejects invalid service type ===
test_valkey_rejects_invalid_service_type = lambda {
    _err = runtime.catch(lambda {
        valkey.ValkeySpec {
            name = "cache"
            namespace = "data"
            serviceType = "ExternalName"
        }
    })
    assert _err != Undefined, "Expected validation error for invalid serviceType"
}

# === Test: validation rejects replication mode with low replicas ===
test_valkey_replication_rejects_low_replicas = lambda {
    _err = runtime.catch(lambda {
        valkey.ValkeySpec {
            name = "cache"
            namespace = "data"
            mode = "replication"
            replicas = 1
        }
    })
    assert _err != Undefined, "Expected validation error for replicas < 2 in replication mode"
}


# === Test: crossplane XR spec follows footprint defaults (local collapses to standalone) ===
test_valkey_xr_spec_local_footprint = lambda {
    _xr = valkey.build_valkey_xr_spec(valkey.ValkeySpec {
        name = "cache"
        namespace = "data"
        footprint = "local"
    })
    assert _xr.clusterName == "cache"
    assert _xr.mode == "standalone"
    assert "nodeCount" not in _xr
    assert _xr.storageSize == "512Mi"
    assert _xr.environment == "local"
}

# === Test: replication nodeCount counts the primary plus replicas ===
test_valkey_xr_spec_replication = lambda {
    _xr = valkey.build_valkey_xr_spec(valkey.ValkeySpec {
        name = "cache"
        namespace = "data"
        replicas = 2
        storageClassName = "fast-ssd"
    })
    assert _xr.mode == "replication"
    assert _xr.nodeCount == 3
    assert _xr.storageSize == "8Gi"
    assert _xr.storageClass == "fast-ssd"
    assert _xr.environment == "production"
}

# === Test: crossplane output emits a typed XValkeyInstance from crossplaneSpec (no Object wrapping) ===
test_valkey_crossplane_output_uses_xr_spec = lambda {
    _spec = valkey.ValkeySpec {
        name = "cache"
        namespace = "data"
        footprint = "development"
    }
    _acc = accessory.AccessoryInstance {
        name = "cache"
        kind = "CRD"
        namespace = "data"
        component = "valkey"
        crossplaneSpec = valkey.build_valkey_xr_spec(_spec)
        configurations = {}
        asset = {version = "8.1.10"}
        leaders = []
        manifests = [valkey.build_valkey_release(_spec)]
        dependsOn = []
    }
    _out = crossplane_proc.generate_crossplane_from_stack([], [_acc], [], "erp", "0.1.0")
    assert len(_out.managed_resources) == 1
    _xr = _out.managed_resources[0]
    assert _xr.apiVersion == "koncept.bluesolution.es/v1alpha1"
    assert _xr.kind == "XValkeyInstance"
    assert _xr.metadata.name == "cache"
    assert _xr.spec.namespace == "data"
    assert _xr.spec.clusterName == "cache"
    assert _xr.spec.mode == "standalone"
    assert _xr.spec.storageSize == "1Gi"
    assert _out.metadata.resourceCount == 0
}
