"""
Timoni procedure tests — validates Timoni module generation from stack structures.
"""
import procedures.kcl_to_timoni as timoni
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

# === Test: generate_timoni_metadata ===
test_timoni_metadata = lambda {
    _result = timoni.generate_timoni_metadata("my-stack", "1.0.0")
    assert _result.apiVersion == "timoni.sh/v1alpha1"
    assert _result.kind == "Module"
    assert _result.metadata.name == "my-stack"
    assert _result.spec.version == "1.0.0"
}

# === Test: generate_timoni_metadata custom version ===
test_timoni_metadata_version = lambda {
    _result = timoni.generate_timoni_metadata("app", "2.5.0")
    assert _result.spec.version == "2.5.0"
    assert _result.metadata.name == "app"
}

# === Test: generate_timoni_values with components ===
test_timoni_values_components = lambda {
    _comp = _mk_component("api", "apps")
    _result = timoni.generate_timoni_values([_comp], [], [])
    assert _result.components.api.namespace == "apps"
    assert _result.components.api.kind == "APPLICATION"
    assert _result.components.api.manifestCount == 2
}

# === Test: generate_timoni_values with accessories ===
test_timoni_values_accessories = lambda {
    _acc = _mk_accessory("db", "data")
    _result = timoni.generate_timoni_values([], [_acc], [])
    assert _result.accessories.db.namespace == "data"
    assert _result.accessories.db.kind == "CRD"
}

# === Test: generate_timoni_values with namespaces ===
test_timoni_values_namespaces = lambda {
    _ns = _mk_namespace("apps")
    _result = timoni.generate_timoni_values([], [], [_ns])
    assert _result.namespaces.apps.kind == "Namespace"
}

# === Test: generate_timoni_resources single component ===
test_timoni_resources_single = lambda {
    _comp = _mk_component("api", "apps")
    _result = timoni.generate_timoni_resources([_comp.manifests])
    assert len(_result) == 2
    assert _result[0].kind == "Deployment"
    assert _result[1].kind == "Service"
}

# === Test: generate_timoni_resources multiple groups ===
test_timoni_resources_multiple = lambda {
    _comp = _mk_component("api", "apps")
    _acc = _mk_accessory("db", "data")
    _result = timoni.generate_timoni_resources([_comp.manifests, _acc.manifests])
    assert len(_result) == 3
}

# === Test: generate_timoni_resources empty ===
test_timoni_resources_empty = lambda {
    _result = timoni.generate_timoni_resources([])
    assert len(_result) == 0
}

# === Test: generate_timoni_module_from_stack full ===
test_module_from_stack = lambda {
    _comp = _mk_component("api", "apps")
    _acc = _mk_accessory("db", "data")
    _ns = _mk_namespace("apps")
    _result = timoni.generate_timoni_module_from_stack(
        [_comp], [_acc], [_ns], "my-stack", "1.0.0"
    )
    assert _result.metadata.apiVersion == "timoni.sh/v1alpha1"
    assert _result.metadata.metadata.name == "my-stack"
    assert _result.values.components.api.namespace == "apps"
    assert _result.values.accessories.db.namespace == "data"
    # 2 (component) + 1 (accessory) + 1 (namespace) = 4
    assert _result.resourceCount == 4
    assert len(_result.resources) == 4
}

# === Test: generate_timoni_module_from_stack empty ===
test_module_from_stack_empty = lambda {
    _result = timoni.generate_timoni_module_from_stack(
        [], [], [], "empty-stack", "0.1.0"
    )
    assert _result.resourceCount == 0
    assert _result.metadata.spec.version == "0.1.0"
}

# === Test: generate_timoni_module_from_stack components only ===
test_module_from_stack_components_only = lambda {
    _comp1 = _mk_component("api", "apps")
    _comp2 = _mk_component("worker", "apps")
    _result = timoni.generate_timoni_module_from_stack(
        [_comp1, _comp2], [], [], "web-stack", "3.0.0"
    )
    assert _result.resourceCount == 4
    assert _result.values.components.api.manifestCount == 2
    assert _result.values.components.worker.manifestCount == 2
}
