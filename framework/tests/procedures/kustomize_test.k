"""
Kustomize procedure tests — validates kustomization.yaml generation and
manifest grouping from stack structures.
"""
import procedures.kcl_to_kustomize as kustomize
import models.modules.component as component
import models.modules.accessory as accessory
import models.modules.k8snamespace as k8snamespace

# --- Helpers ---

_mk_component = lambda name: str, ns: str -> component.ComponentInstance {
    component.ComponentInstance {
        name = name
        kind = "APPLICATION"
        namespace = ns
        configurations = {}
        asset = { version = "1.0.0" }
        leaders = [{ name = name, kind = "Deployment", apiVersion = "apps/v1" }]
        manifests = [
            { apiVersion = "apps/v1", kind = "Deployment", metadata = { name = name, namespace = ns } }
            { apiVersion = "v1", kind = "Service", metadata = { name = name, namespace = ns } }
        ]
        dependsOn = []
    }
}

_mk_accessory = lambda name: str, ns: str -> accessory.AccessoryInstance {
    accessory.AccessoryInstance {
        name = name
        kind = "CRD"
        namespace = ns
        configurations = {}
        asset = { version = "16.0" }
        leaders = [{ name = name, kind = "StatefulSet", apiVersion = "apps/v1" }]
        manifests = [
            { apiVersion = "apps/v1", kind = "StatefulSet", metadata = { name = name, namespace = ns } }
        ]
        dependsOn = []
    }
}

_mk_namespace = lambda name: str -> k8snamespace.K8sNamespaceInstance {
    k8snamespace.K8sNamespaceInstance {
        name = name
        kind = "Namespace"
        apiVersion = "v1"
        configurations = {}
        leaders = [{ name = name, kind = "Namespace", apiVersion = "v1" }]
        manifests = [
            { apiVersion = "v1", kind = "Namespace", metadata = { name = name } }
        ]
    }
}

# === Test: generate_kustomization with single component ===
test_kustomization_single_component = lambda {
    _comp = _mk_component("api", "apps")
    _result = kustomize.generate_kustomization([_comp.manifests], "my-app", "1.0.0")
    assert _result.apiVersion == "kustomize.config.k8s.io/v1beta1"
    assert _result.kind == "Kustomization"
    assert len(_result.resources) == 2
}

# === Test: generate_kustomization with multiple components ===
test_kustomization_multiple = lambda {
    _comp1 = _mk_component("api", "apps")
    _comp2 = _mk_component("worker", "apps")
    _all_manifests = [_comp1.manifests, _comp2.manifests]
    _result = kustomize.generate_kustomization(_all_manifests, "stack", "2.0.0")
    assert len(_result.resources) == 4
}

# === Test: generate_kustomization with accessories ===
test_kustomization_with_accessories = lambda {
    _comp = _mk_component("api", "apps")
    _acc = _mk_accessory("db", "data")
    _all = [_comp.manifests, _acc.manifests]
    _result = kustomize.generate_kustomization(_all, "full-stack", "1.0.0")
    assert len(_result.resources) == 3
}

# === Test: generate_kustomization labels ===
test_kustomization_labels = lambda {
    _comp = _mk_component("api", "apps")
    _result = kustomize.generate_kustomization([_comp.manifests], "my-app", "1.0.0")
    assert _result.commonLabels["app.kubernetes.io/managed-by"] == "idp-concept"
    assert _result.commonLabels["app.kubernetes.io/version"] == "1.0.0"
}

# === Test: generate_kustomization_from_stack ===
test_generate_from_stack = lambda {
    _comp = _mk_component("api", "apps")
    _ns = _mk_namespace("apps")
    _result = kustomize.generate_kustomization_from_stack(
        [_comp], [], [_ns], "my-stack", "1.0.0"
    )
    assert _result.kind == "Kustomization"
    # 2 from component + 1 from namespace = 3
    assert len(_result.resources) == 3
}

# === Test: resource naming ===
test_resource_names = lambda {
    _comp = _mk_component("api", "apps")
    _result = kustomize.generate_kustomization([_comp.manifests], "app", "1.0.0")
    # Resources should be named as "kind-name.yaml" (lowercase)
    assert "deployment-api.yaml" in _result.resources
    assert "service-api.yaml" in _result.resources
}

# === Test: empty stack ===
test_empty_stack = lambda {
    _result = kustomize.generate_kustomization([], "empty", "1.0.0")
    assert len(_result.resources) == 0
}

# === Test: generate_overlay_patch ===
test_overlay_patch = lambda {
    _patch = kustomize.generate_overlay_patch("api", "apps/v1", "Deployment", {
        replicas = 3
    })
    assert _patch.apiVersion == "apps/v1"
    assert _patch.kind == "Deployment"
    assert _patch.metadata.name == "api"
    assert _patch.spec.replicas == 3
}
