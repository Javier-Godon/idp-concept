"""
QuestDB Template Tests.

Tests the QuestDB template which wraps ThirdPartyHelmSpec
for the QuestDB time-series database (deployed via official Helm chart).
"""
import templates.questdb as qdb

# === Test: build_questdb_release with defaults ===
test_build_questdb_default = lambda {
    _result = qdb.build_questdb_release(qdb.QuestDBSpec {
        name = "my-questdb"
        namespace = "data"
        storageSize = "50Gi"
    })
    assert _result.apiVersion == "helm.toolkit.fluxcd.io/v2beta1"
    assert _result.kind == "HelmRelease"
    assert _result.metadata.name == "my-questdb"
    assert _result.spec.chart == "questdb/questdb"
    assert _result.spec.version == "0.32.0"
    assert _result.spec.values["persistence.size"] == "50Gi"
    assert _result.spec.values["persistence.enabled"] == "true"
}

# === Test: QuestDB with custom version and resources ===
test_build_questdb_custom = lambda {
    _result = qdb.build_questdb_release(qdb.QuestDBSpec {
        name = "ts-db"
        namespace = "analytics"
        chartVersion = "0.33.0"
        storageSize = "100Gi"
        storageClassName = "fast-ssd"
        cpuRequest = "1"
        memoryRequest = "4Gi"
        cpuLimit = "4"
        memoryLimit = "8Gi"
    })
    assert _result.spec.version == "0.33.0"
    assert _result.spec.values["persistence.size"] == "100Gi"
    assert _result.spec.values["persistence.storageClassName"] == "fast-ssd"
    assert _result.spec.values["resources.requests.cpu"] == "1"
    assert _result.spec.values["resources.requests.memory"] == "4Gi"
    assert _result.spec.values["resources.limits.cpu"] == "4"
    assert _result.spec.values["resources.limits.memory"] == "8Gi"
}

# === Test: QuestDB with HTTP and ILP ports ===
test_build_questdb_with_ports = lambda {
    _result = qdb.build_questdb_release(qdb.QuestDBSpec {
        name = "my-questdb"
        namespace = "data"
        storageSize = "50Gi"
        httpPort = 9000
        ilpPort = 9009
        pgPort = 8812
    })
    assert _result.spec.values["service.http.port"] == "9000"
    assert _result.spec.values["service.ilp.port"] == "9009"
    assert _result.spec.values["service.postgresql.port"] == "8812"
}

# === Test: QuestDB with service type ===
test_build_questdb_with_service_type = lambda {
    _result = qdb.build_questdb_release(qdb.QuestDBSpec {
        name = "my-questdb"
        namespace = "data"
        storageSize = "50Gi"
        serviceType = "LoadBalancer"
    })
    assert _result.spec.values["service.type"] == "LoadBalancer"
}
