"""
OpenBao Template Tests.

Tests HelmRelease generation for OpenBao template defaults and HA mode.
"""
import templates.openbao as openbao
import runtime

# === Test: default OpenBao release ===
test_build_openbao_default = lambda {
    _result = openbao.build_openbao_release(openbao.OpenBaoSpec {
        name = "openbao"
        namespace = "security"
    })
    assert _result.apiVersion == "helm.toolkit.fluxcd.io/v2beta1"
    assert _result.kind == "HelmRelease"
    assert _result.spec.chart == "openbao/openbao"
    assert _result.spec.version == "0.8.1"
    assert _result.spec.values["server.standalone.enabled"] == "false"
    assert _result.spec.values["server.ha.enabled"] == "true"
    assert _result.spec.values["server.ha.replicas"] == "3"
    assert _result.spec.values["server.ha.raft.enabled"] == "true"
}

# === Test: HA mode and storage overrides ===
test_build_openbao_ha = lambda {
    _result = openbao.build_openbao_release(openbao.OpenBaoSpec {
        name = "openbao"
        namespace = "security"
        mode = "ha"
        storageSize = "30Gi"
        storageClassName = "premium-rwo"
        uiEnabled = False
        serviceType = "LoadBalancer"
    })
    assert _result.spec.values["server.standalone.enabled"] == "false"
    assert _result.spec.values["server.ha.enabled"] == "true"
    assert _result.spec.values["server.dataStorage.size"] == "30Gi"
    assert _result.spec.values["server.dataStorage.storageClass"] == "premium-rwo"
    assert _result.spec.values["ui.enabled"] == "false"
    assert _result.spec.values["server.service.type"] == "LoadBalancer"
}

# === Test: validation rejects empty name ===
test_openbao_rejects_empty_name = lambda {
    _err = runtime.catch(lambda {
        openbao.OpenBaoSpec {
            name = ""
            namespace = "security"
        }
    })
    assert _err != Undefined, "Expected validation error for empty name"
}

# === Test: validation rejects invalid service type ===
test_openbao_rejects_invalid_service_type = lambda {
    _err = runtime.catch(lambda {
        openbao.OpenBaoSpec {
            name = "openbao"
            namespace = "security"
            serviceType = "ExternalName"
        }
    })
    assert _err != Undefined, "Expected validation error for invalid serviceType"
}

