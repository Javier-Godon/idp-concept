import models.modules.k8snamespace as ns

# === Test: K8sNamespace auto-generates manifest ===
test_k8snamespace_auto_manifest = lambda {
    _ns = ns.K8sNamespace {
        name = "apps"
        configurations = {}
    }
    assert _ns.kind == "Namespace"
    assert _ns.apiVersion == "v1"
    assert len(_ns.manifests) == 1
    assert _ns.manifests[0].kind == "Namespace"
    assert _ns.manifests[0].metadata.name == "apps"
}

# === Test: K8sNamespace auto-generates leader ===
test_k8snamespace_auto_leader = lambda {
    _ns = ns.K8sNamespace {
        name = "infra"
        configurations = {}
    }
    assert len(_ns.leaders) == 1
    assert _ns.leaders[0].name == "infra"
    assert _ns.leaders[0].kind == "Namespace"
    assert _ns.leaders[0].apiVersion == "v1"
}

# === Test: K8sNamespace instance ===
test_k8snamespace_instance = lambda {
    _ns = ns.K8sNamespace {
        name = "data"
        configurations = { region = "eu-west-1" }
    }
    _inst = _ns.instance
    assert _inst.name == "data"
    assert _inst.kind == "Namespace"
    assert _inst.apiVersion == "v1"
    assert _inst.configurations.region == "eu-west-1"
    assert len(_inst.manifests) == 1
}

# === Test: K8sNamespace with annotations and labels ===
test_k8snamespace_annotations_labels = lambda {
    _ns = ns.K8sNamespace {
        name = "monitored"
        configurations = {}
        annotations = { "team" = "platform" }
        labels = { "env" = "prod" }
    }
    _manifest = _ns.manifests[0]
    assert _manifest.metadata.annotations.team == "platform"
    assert _manifest.metadata.labels.env == "prod"
}
