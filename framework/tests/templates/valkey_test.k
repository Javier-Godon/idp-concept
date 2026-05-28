"""
Valkey Template Tests.

Tests HelmRelease generation for Valkey template defaults and overrides.
"""
import templates.valkey.v1_0_0.valkey as valkey
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

