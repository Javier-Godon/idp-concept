import models.configurations as cfg

# === Test: Merge configurations order (later overrides earlier) ===
test_merge_configurations_basic = lambda {
    _kernel = { projectName = "test", env = "dev" }
    _profile = { version = "1.0" }
    _tenant = { brandIcon = "icon.png" }
    _site = { siteName = "production" }

    _result = cfg.merge_configurations(_kernel, _profile, _tenant, _site)
    assert _result.projectName == "test"
    assert _result.version == "1.0"
    assert _result.brandIcon == "icon.png"
    assert _result.siteName == "production"
}

# === Test: Merge override behavior (later wins) ===
test_merge_configurations_override = lambda {
    _kernel = { replicas = 1, env = "dev" }
    _profile = { replicas = 2 }
    _tenant = {}
    _site = { replicas = 3 }

    _result = cfg.merge_configurations(_kernel, _profile, _tenant, _site)
    assert _result.replicas == 3
    assert _result.env == "dev"
}

# === Test: Merge with empty layers ===
test_merge_configurations_empty_layers = lambda {
    _kernel = { projectName = "app", port = 8080 }
    _profile = {}
    _tenant = {}
    _site = {}

    _result = cfg.merge_configurations(_kernel, _profile, _tenant, _site)
    assert _result.projectName == "app"
    assert _result.port == 8080
}

# === Test: BaseConfigurations schema fields ===
test_base_configurations_schema = lambda {
    _cfg = cfg.BaseConfigurations {
        projectName = "my-project"
        siteName = "dev"
        brandIcon = "logo.png"
        appsNamespace = "apps"
        rootPaths = { base = "/opt/app" }
    }
    assert _cfg.projectName == "my-project"
    assert _cfg.siteName == "dev"
    assert _cfg.brandIcon == "logo.png"
    assert _cfg.appsNamespace == "apps"
    assert _cfg.rootPaths.base == "/opt/app"
}
