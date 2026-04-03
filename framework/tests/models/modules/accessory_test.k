import models.modules.accessory as acc

# === Test: Accessory schema fields ===
test_accessory_fields = lambda {
    _a = acc.Accessory {
        kind = "CRD"
        name = "postgres"
        namespace = "infra"
        configurations = { port = 5432 }
        asset = { image = "postgres", version = "16.4" }
        leaders = [acc.AccessoryLeader { name = "postgres", kind = "Cluster", apiVersion = "postgresql.cnpg.io/v1", namespace = "infra" }]
        manifests = [{ kind = "Cluster", metadata.name = "postgres" }]
        dependsOn = []
    }
    assert _a.name == "postgres"
    assert _a.kind == "CRD"
    assert _a.namespace == "infra"
    assert _a.asset.version == "16.4"
    assert len(_a.leaders) == 1
    assert len(_a.manifests) == 1
}

# === Test: Accessory kind values ===
test_accessory_kind_crd = lambda {
    _a = acc.Accessory {
        kind = "CRD"
        name = "db"
        namespace = "ns"
        configurations = {}
        asset = { version = "1.0" }
        leaders = []
        manifests = []
        dependsOn = []
    }
    assert _a.kind == "CRD"
}

test_accessory_kind_secret = lambda {
    _a = acc.Accessory {
        kind = "SECRET"
        name = "sec"
        namespace = "ns"
        configurations = {}
        asset = { version = "1.0" }
        leaders = []
        manifests = []
        dependsOn = []
    }
    assert _a.kind == "SECRET"
}

# === Test: Accessory instance auto-population ===
test_accessory_instance = lambda {
    _a = acc.Accessory {
        kind = "SECRET"
        name = "vault-sync"
        namespace = "secrets"
        configurations = { refreshInterval = "1h" }
        asset = { version = "1.0" }
        leaders = [acc.AccessoryLeader { name = "vault-sync", kind = "VaultStaticSecret", apiVersion = "secrets.hashicorp.com/v1beta1", namespace = "secrets" }]
        manifests = [{ kind = "VaultStaticSecret" }]
        dependsOn = []
    }
    _i = _a.instance
    assert _i.name == "vault-sync"
    assert _i.kind == "SECRET"
    assert _i.namespace == "secrets"
    assert _i.configurations.refreshInterval == "1h"
    assert len(_i.leaders) == 1
    assert _i.leaders[0].kind == "VaultStaticSecret"
}

# === Test: AccessoryAsset optional image ===
test_accessory_asset_optional_image = lambda {
    _a = acc.AccessoryAsset { version = "3.0" }
    assert _a.version == "3.0"
}

# === Test: AccessoryLeader inherits from Leader ===
test_accessory_leader_is_leader = lambda {
    _l = acc.AccessoryLeader { name = "kafka", kind = "Kafka", apiVersion = "kafka.strimzi.io/v1beta2", namespace = "infra" }
    assert _l.name == "kafka"
    assert _l.kind == "Kafka"
    assert _l.apiVersion == "kafka.strimzi.io/v1beta2"
    assert _l.namespace == "infra"
}
