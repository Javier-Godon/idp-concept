"""
Kusion procedure tests — validates KusionResource creation and spec stream functions.
Tests the kcl_to_kusion module's ability to wrap K8s manifests into Kusion resources.
"""
import procedures.kcl_to_kusion as kusion
import models.modules.component as component
import models.modules.accessory as accessory
import models.modules.k8snamespace as k8snamespace

# === Test: KusionResource from namespaced manifest ===
test_kusion_resource_namespaced = lambda {
    _manifest = {
        apiVersion = "apps/v1"
        kind = "Deployment"
        metadata = {
            name = "api"
            namespace = "apps"
        }
    }
    _result = kusion.kusion_spec_stream_single_manifest(_manifest, [])
    assert _result.id == "apps/v1:Deployment:apps:api"
    assert _result.type == "Kubernetes"
    assert _result.attributes.kind == "Deployment"
}

# === Test: KusionResource from cluster-scoped manifest ===
test_kusion_resource_cluster_scoped = lambda {
    _manifest = {
        apiVersion = "v1"
        kind = "Namespace"
        metadata = {
            name = "apps"
        }
    }
    _result = kusion.kusion_spec_stream_single_manifest(_manifest, [])
    assert _result.id == "v1:Namespace:apps"
    assert _result.type == "Kubernetes"
}

# === Test: KusionResource with dependsOn ===
test_kusion_resource_with_depends = lambda {
    _manifest = {
        apiVersion = "apps/v1"
        kind = "Deployment"
        metadata = {
            name = "api"
            namespace = "apps"
        }
    }
    _deps = [{
        leaders = [{
            apiVersion = "v1"
            kind = "Namespace"
            name = "apps"
            namespace = "apps"
        }]
    }]
    _result = kusion.kusion_spec_stream_single_manifest(_manifest, _deps)
    assert len(_result.dependsOn) == 1
    assert _result.dependsOn[0] == "v1:Namespace:apps:apps"
}

# === Test: kusion_spec_stream_components ===
test_kusion_stream_components = lambda {
    _components = [component.ComponentInstance {
        name = "api"
        kind = "APPLICATION"
        namespace = "apps"
        configurations = {}
        asset = { version = "1.0.0" }
        leaders = [{ name = "api", kind = "Deployment", apiVersion = "apps/v1" }]
        manifests = [
            {
                apiVersion = "apps/v1"
                kind = "Deployment"
                metadata = { name = "api", namespace = "apps" }
            }
            {
                apiVersion = "v1"
                kind = "Service"
                metadata = { name = "api", namespace = "apps" }
            }
        ]
        dependsOn = []
    }]
    _result = kusion.kusion_spec_stream_components(_components)
    assert len(_result) == 2
    assert _result[0].id == "apps/v1:Deployment:apps:api"
    assert _result[1].id == "v1:Service:apps:api"
}

# === Test: kusion_spec_stream_accessories ===
test_kusion_stream_accessories = lambda {
    _accessories = [accessory.AccessoryInstance {
        name = "postgres"
        kind = "CRD"
        namespace = "data"
        configurations = {}
        asset = { version = "16.0" }
        leaders = [{ name = "postgres", kind = "Deployment", apiVersion = "apps/v1" }]
        manifests = [
            {
                apiVersion = "apps/v1"
                kind = "Deployment"
                metadata = { name = "postgres", namespace = "data" }
            }
        ]
        dependsOn = []
    }]
    _result = kusion.kusion_spec_stream_accessories(_accessories)
    assert len(_result) == 1
    assert _result[0].id == "apps/v1:Deployment:data:postgres"
}

# === Test: kusion_spec_stream_namespaces ===
test_kusion_stream_namespaces = lambda {
    _namespaces = [k8snamespace.K8sNamespaceInstance {
        name = "apps"
        kind = "Namespace"
        apiVersion = "v1"
        configurations = {}
        leaders = [{ name = "apps", kind = "Namespace", apiVersion = "v1" }]
        manifests = [
            {
                apiVersion = "v1"
                kind = "Namespace"
                metadata = { name = "apps" }
            }
        ]
    }]
    _result = kusion.kusion_spec_stream_namespaces(_namespaces)
    assert len(_result) == 1
    assert _result[0].id == "v1:Namespace:apps"
}

# === Test: KusionSpec schema ===
test_kusion_spec_schema = lambda {
    _spec = kusion.KusionSpec {
        resources = [
            kusion.KusionResource {
                id = "v1:Namespace:apps"
                attributes = { apiVersion = "v1", kind = "Namespace" }
            }
        ]
    }
    assert len(_spec.resources) == 1
    assert _spec.resources[0].type == "Kubernetes"
}

# === Test: Component with dependsOn generates correct Kusion deps ===
test_kusion_component_with_depends = lambda {
    _ns_leader = { name = "apps", kind = "Namespace", apiVersion = "v1" }
    _components = [component.ComponentInstance {
        name = "api"
        kind = "APPLICATION"
        namespace = "apps"
        configurations = {}
        asset = { version = "1.0.0" }
        leaders = [{ name = "api", kind = "Deployment", apiVersion = "apps/v1" }]
        manifests = [
            {
                apiVersion = "apps/v1"
                kind = "Deployment"
                metadata = { name = "api", namespace = "apps" }
            }
        ]
        dependsOn = [{ leaders = [_ns_leader] }]
    }]
    _result = kusion.kusion_spec_stream_components(_components)
    assert len(_result) == 1
    assert len(_result[0].dependsOn) == 1
    assert _result[0].dependsOn[0] == "v1:Namespace:apps"
}
