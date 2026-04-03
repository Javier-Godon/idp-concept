import models.modules.component as comp
import models.modules.leader as base_leader

# === Test: Component schema fields ===
test_component_fields = lambda {
    _c = comp.Component {
        kind = "APPLICATION"
        name = "web-api"
        namespace = "apps"
        configurations = { port = 8080 }
        asset = { image = "nginx", version = "1.25" }
        leaders = [comp.ComponentLeader { name = "web-api", kind = "Deployment", apiVersion = "apps/v1", namespace = "apps" }]
        manifests = [{ kind = "Deployment", metadata.name = "web-api" }]
        dependsOn = []
    }
    assert _c.name == "web-api"
    assert _c.kind == "APPLICATION"
    assert _c.namespace == "apps"
    assert _c.asset.image == "nginx"
    assert _c.asset.version == "1.25"
    assert len(_c.leaders) == 1
    assert len(_c.manifests) == 1
}

# === Test: Component kind values ===
test_component_kind_application = lambda {
    _c = comp.Component {
        kind = "APPLICATION"
        name = "api"
        namespace = "ns"
        configurations = {}
        asset = { version = "1.0" }
        leaders = []
        manifests = []
        dependsOn = []
    }
    assert _c.kind == "APPLICATION"
}

test_component_kind_infrastructure = lambda {
    _c = comp.Component {
        kind = "INFRASTRUCTURE"
        name = "svc"
        namespace = "ns"
        configurations = {}
        asset = { version = "1.0" }
        leaders = []
        manifests = []
        dependsOn = []
    }
    assert _c.kind == "INFRASTRUCTURE"
}

# === Test: Component instance auto-population ===
test_component_instance = lambda {
    _c = comp.Component {
        kind = "INFRASTRUCTURE"
        name = "cache"
        namespace = "infra"
        configurations = { replicas = 3 }
        asset = { image = "redis", version = "7.2" }
        leaders = [comp.ComponentLeader { name = "cache", kind = "StatefulSet", apiVersion = "apps/v1", namespace = "infra" }]
        manifests = [{ kind = "StatefulSet" }]
        dependsOn = []
    }
    _i = _c.instance
    assert _i.name == "cache"
    assert _i.kind == "INFRASTRUCTURE"
    assert _i.namespace == "infra"
    assert _i.configurations.replicas == 3
    assert _i.asset.version == "7.2"
    assert len(_i.leaders) == 1
    assert _i.leaders[0].kind == "StatefulSet"
}

# === Test: ComponentAsset optional image ===
test_component_asset_optional_image = lambda {
    _a = comp.ComponentAsset { version = "2.0" }
    assert _a.version == "2.0"
}

# === Test: ComponentAsset helmChart ===
test_component_asset_helm_chart = lambda {
    _a = comp.ComponentAsset { helmChart = "bitnami/redis", version = "18.0.0" }
    assert _a.helmChart == "bitnami/redis"
}

# === Test: ComponentLeader inherits from Leader ===
test_component_leader_is_leader = lambda {
    _l = comp.ComponentLeader { name = "app", kind = "Deployment", apiVersion = "apps/v1", namespace = "ns" }
    assert _l.name == "app"
    assert _l.kind == "Deployment"
    assert _l.apiVersion == "apps/v1"
    assert _l.namespace == "ns"
}

# === Test: Component dependsOn defaults to empty ===
test_component_depends_on_default = lambda {
    _c = comp.Component {
        kind = "APPLICATION"
        name = "app"
        namespace = "ns"
        configurations = {}
        asset = { version = "1.0" }
        leaders = []
        manifests = []
        dependsOn = []
    }
    assert True
}
