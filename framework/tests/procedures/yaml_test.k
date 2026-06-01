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
import models.release_notes as rn
import models.metadata as meta

# === Test: get_components extracts manifests ===
test_get_components = lambda {
    _components = [component.ComponentInstance {
        name = "api"
        kind = "APPLICATION"
        namespace = "apps"
        configurations = {}
        asset = {version = "1.0.0"}
        leaders = [{name = "api", kind = "Deployment", apiVersion = "apps/v1"}]
        manifests = [
            {apiVersion = "apps/v1", kind = "Deployment", metadata = {name = "api"}}
            {apiVersion = "v1", kind = "Service", metadata = {name = "api"}}
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
        asset = {version = "16.0"}
        leaders = [{name = "db", kind = "Deployment", apiVersion = "apps/v1"}]
        manifests = [
            {apiVersion = "apps/v1", kind = "Deployment", metadata = {name = "db"}}
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
        leaders = [{name = "apps", kind = "Namespace", apiVersion = "v1"}]
        manifests = [
            {apiVersion = "v1", kind = "Namespace", metadata = {name = "apps"}}
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
            asset = {version = "1.0.0"}
            leaders = [{name = name, kind = "Deployment", apiVersion = "apps/v1"}]
            manifests = [
                {apiVersion = "apps/v1", kind = "Deployment", metadata = {name = name}}
            ]
            dependsOn = []
        }
    }
    _components = [_mk_component("api"), _mk_component("web")]
    _result = yaml_proc.get_components(_components)
    assert len(_result) == 2
}

test_get_release_notes = lambda {
    _result = yaml_proc.get_release_notes(rn.ReleaseNotes {
        name = "my-release"
        version = "1.0.0"
        namespace = "apps"
    })
    assert len(_result) == 1
    assert _result[0].kind == "ConfigMap"
    assert _result[0].metadata.name == "my-release-release-notes"
}

test_apply_stack_metadata_adds_labels_and_annotations = lambda {
    _result = yaml_proc.apply_stack_metadata({
        apiVersion = "apps/v1"
        kind = "Deployment"
        metadata = {
            name = "api"
        }
    }, meta.Metadata {
        owner = "platform-team"
        lifecycle = "production"
        sloTier = "gold"
        dataClassification = "internal"
        costCenter = "cc-42"
        runbook = "https://docs.example.invalid/runbooks/api"
        support = "platform@example.invalid"
        labels = {
            "app.kubernetes.io/part-of" = "erp-back"
        }
        annotations = {
            "example.com/custom" = "custom-value"
        }
    })
    assert _result.metadata.labels["app.kubernetes.io/part-of"] == "erp-back"
    assert _result.metadata.annotations["koncept.io/owner"] == "platform-team"
    assert _result.metadata.annotations["koncept.io/lifecycle"] == "production"
    assert _result.metadata.annotations["koncept.io/slo-tier"] == "gold"
    assert _result.metadata.annotations["koncept.io/data-classification"] == "internal"
    assert _result.metadata.annotations["koncept.io/cost-center"] == "cc-42"
    assert _result.metadata.annotations["koncept.io/runbook"] == "https://docs.example.invalid/runbooks/api"
    assert _result.metadata.annotations["koncept.io/support-contact"] == "platform@example.invalid"
    assert _result.metadata.annotations["example.com/custom"] == "custom-value"
}

test_apply_stack_metadata_preserves_manifest_specific_values = lambda {
    _result = yaml_proc.apply_stack_metadata({
        apiVersion = "apps/v1"
        kind = "Deployment"
        metadata = {
            name = "api"
            labels = {
                "app.kubernetes.io/part-of" = "resource-specific"
            }
            annotations = {
                "koncept.io/owner" = "service-team"
            }
        }
    }, meta.Metadata {
        owner = "platform-team"
        labels = {
            "app.kubernetes.io/part-of" = "stack"
            "app.kubernetes.io/managed-by" = "koncept"
        }
    })
    assert _result.metadata.labels["app.kubernetes.io/part-of"] == "resource-specific"
    assert _result.metadata.labels["app.kubernetes.io/managed-by"] == "koncept"
    assert _result.metadata.annotations["koncept.io/owner"] == "service-team"
}

test_get_components_with_metadata_applies_to_nested_manifests = lambda {
    _components = [component.ComponentInstance {
        name = "api"
        kind = "APPLICATION"
        namespace = "apps"
        configurations = {}
        asset = {version = "1.0.0"}
        leaders = [{name = "api", kind = "Deployment", apiVersion = "apps/v1"}]
        manifests = [
            {apiVersion = "apps/v1", kind = "Deployment", metadata = {name = "api"}}
            {apiVersion = "v1", kind = "Service", metadata = {name = "api"}}
        ]
        dependsOn = []
    }]
    _result = yaml_proc.get_components_with_metadata(_components, meta.Metadata {
        owner = "platform-team"
    })
    assert len(_result) == 1
    assert len(_result[0]) == 2
    assert _result[0][0].metadata.annotations["koncept.io/owner"] == "platform-team"
    assert _result[0][1].metadata.annotations["koncept.io/owner"] == "platform-team"
}
