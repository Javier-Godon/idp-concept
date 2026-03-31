import assembly.helpers as asm

# === Test: create_namespace ===
test_create_namespace = lambda {
    _cfg = { projectName = "test", appsNamespace = "apps" }
    _ns = asm.create_namespace("my-namespace", _cfg)
    assert _ns.name == "my-namespace"
    assert _ns.kind == "Namespace"
    assert _ns.apiVersion == "v1"
    assert len(_ns.manifests) == 1
    assert _ns.manifests[0].metadata.name == "my-namespace"
    assert _ns.configurations.projectName == "test"
}

# === Test: create_namespace_from_config ===
test_create_namespace_from_config = lambda {
    _cfg = { projectName = "test", appsNamespace = "custom-ns" }
    _ns = asm.create_namespace_from_config("appsNamespace", _cfg)
    assert _ns.name == "custom-ns"
    assert _ns.manifests[0].metadata.name == "custom-ns"
}

# === Test: create_namespace_from_config fallback ===
test_create_namespace_from_config_fallback = lambda {
    _cfg = { projectName = "test" }
    _ns = asm.create_namespace_from_config("appsNamespace", _cfg)
    # When config field is falsy, uses the field name as namespace name
    assert _ns.name == "appsNamespace"
}
