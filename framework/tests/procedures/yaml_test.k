"""
YAML procedure tests — validates manifest extraction from stack structures.
Tests the kcl_to_yaml module's component/accessory/namespace extraction lambdas.
Note: yaml_stream_stack calls manifests.yaml_stream() which produces YAML output
as a side effect, so we test the extraction logic that feeds it.
"""
import procedures.kcl_to_yaml as yaml_proc
import models.modules.component as component
import models.modules.accessory as accessory
import models.modules.k8snamespace as k8snamespace

# === Test: get_components extracts manifests ===
test_get_components = lambda {
    _components = [component.ComponentInstance {
        name = "api"
        kind = "APPLICATION"
        namespace = "apps"
        configurations = {}
        asset = { version = "1.0.0" }
        leaders = [{ name = "api", kind = "Deployment", apiVersion = "apps/v1" }]
        manifests = [
            { apiVersion = "apps/v1", kind = "Deployment", metadata = { name = "api" } }
            { apiVersion = "v1", kind = "Service", metadata = { name = "api" } }
        ]
        dependsOn = []
    }]
    _result = yaml_proc.get_components(_components)
    assert len(_result) == 1
    assert len(_result[0]) == 2
}

# === Test: get_components empty ===
test_get_components_empty = lambda {
    _result = yaml_proc.get_components([])
    assert len(_result) == 0
}

# === Test: get_caccessories extracts manifests ===
test_get_accessories = lambda {
    _accessories = [accessory.AccessoryInstance {
        name = "db"
        kind = "CRD"
        namespace = "data"
        configurations = {}
        asset = { version = "16.0" }
        leaders = [{ name = "db", kind = "Deployment", apiVersion = "apps/v1" }]
        manifests = [
            { apiVersion = "apps/v1", kind = "Deployment", metadata = { name = "db" } }
        ]
        dependsOn = []
    }]
    _result = yaml_proc.get_caccessories(_accessories)
    assert len(_result) == 1
    assert len(_result[0]) == 1
}

# === Test: get_namespaces extracts manifests ===
test_get_namespaces = lambda {
    _namespaces = [k8snamespace.K8sNamespaceInstance {
        name = "apps"
        kind = "Namespace"
        apiVersion = "v1"
        configurations = {}
        leaders = [{ name = "apps", kind = "Namespace", apiVersion = "v1" }]
        manifests = [
            { apiVersion = "v1", kind = "Namespace", metadata = { name = "apps" } }
        ]
    }]
    _result = yaml_proc.get_namespaces(_namespaces)
    assert len(_result) == 1
    assert len(_result[0]) == 1
}

# === Test: Multiple components flatten correctly ===
test_get_components_multiple = lambda {
    _mk_component = lambda name: str -> component.ComponentInstance {
        component.ComponentInstance {
            name = name
            kind = "APPLICATION"
            namespace = "apps"
            configurations = {}
            asset = { version = "1.0.0" }
            leaders = [{ name = name, kind = "Deployment", apiVersion = "apps/v1" }]
            manifests = [
                { apiVersion = "apps/v1", kind = "Deployment", metadata = { name = name } }
            ]
            dependsOn = []
        }
    }
    _components = [_mk_component("api"), _mk_component("web")]
    _result = yaml_proc.get_components(_components)
    assert len(_result) == 2
}
