import builders.configmap as cm

# === Test: Basic ConfigMap ===
test_build_configmap_basic = lambda {
    _spec = cm.ConfigMapSpec {
        name = "my-config"
        namespace = "apps"
        data = { "application.yaml" = "server.port: 8080" }
    }
    _result = cm.build_configmap(_spec)
    assert _result.metadata.name == "my-config"
    assert _result.metadata.namespace == "apps"
    assert _result.kind == "ConfigMap"
    assert _result.apiVersion == "v1"
    assert _result.data["application.yaml"] == "server.port: 8080"
}

# === Test: ConfigMap with multiple entries ===
test_build_configmap_multiple_keys = lambda {
    _spec = cm.ConfigMapSpec {
        name = "multi-config"
        namespace = "default"
        data = {
            "app.yaml" = "port: 8080"
            "db.yaml" = "host: localhost"
            "feature.flags" = "dark_mode=true"
        }
    }
    _result = cm.build_configmap(_spec)
    assert len(_result.data) == 3
    assert _result.data["app.yaml"] == "port: 8080"
    assert _result.data["db.yaml"] == "host: localhost"
    assert _result.data["feature.flags"] == "dark_mode=true"
}
