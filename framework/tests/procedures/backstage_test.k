"""
Backstage procedure tests — validates Backstage catalog entity generation from stack structures.
TDD: Phase 8 — kcl_to_backstage implementation.
"""
import procedures.kcl_to_backstage as backstage
import models.modules.component as component
import models.modules.accessory as accessory
import models.modules.k8snamespace as k8snamespace

# --- Helpers (prefixed with _bs_ to avoid package-scope collisions) ---

_bs_mk_app_component = lambda name: str, ns: str -> component.ComponentInstance {
    component.ComponentInstance {
        name = name
        kind = "APPLICATION"
        namespace = ns
        configurations = {}
        asset = { version = "1.0.0" }
        leaders = [{ name = name, kind = "Deployment", apiVersion = "apps/v1" }]
        manifests = [
            { apiVersion = "apps/v1", kind = "Deployment", metadata = { name = name, namespace = ns } }
        ]
        dependsOn = []
    }
}

_bs_mk_infra_component = lambda name: str, ns: str -> component.ComponentInstance {
    component.ComponentInstance {
        name = name
        kind = "INFRASTRUCTURE"
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

_bs_mk_accessory = lambda name: str, ns: str, kind: str -> accessory.AccessoryInstance {
    accessory.AccessoryInstance {
        name = name
        kind = kind
        namespace = ns
        configurations = {}
        asset = { version = "1.0.0" }
        leaders = [{ name = name, kind = "StatefulSet", apiVersion = "apps/v1" }]
        manifests = [
            { apiVersion = "apps/v1", kind = "StatefulSet", metadata = { name = name, namespace = ns } }
        ]
        dependsOn = []
    }
}

_bs_mk_namespace = lambda name: str -> k8snamespace.K8sNamespaceInstance {
    k8snamespace.K8sNamespaceInstance {
        name = name
        kind = "Namespace"
        apiVersion = "v1"
        configurations = {}
        leaders = [{ name = name, kind = "Namespace", apiVersion = "v1" }]
        manifests = [
            { apiVersion = "v1", kind = "Namespace", metadata = { name = name } }
        ]
        dependsOn = []
    }
}

# === Test: generate Domain entity ===
test_generate_domain = lambda {
    _domain = backstage.generate_domain("erp-back", "platform-team", "")
    assert _domain.apiVersion == "backstage.io/v1alpha1"
    assert _domain.kind == "Domain"
    assert _domain.metadata.name == "erp-back"
    assert _domain.spec.owner == "platform-team"
}

# === Test: generate System entity ===
test_generate_system = lambda {
    _system = backstage.generate_system("erp-back", "erp-back", "platform-team", "")
    assert _system.apiVersion == "backstage.io/v1alpha1"
    assert _system.kind == "System"
    assert _system.metadata.name == "erp-back"
    assert _system.spec.domain == "erp-back"
    assert _system.spec.owner == "platform-team"
}

# === Test: generate Component entity from APPLICATION ===
test_bs_generate_component_entity = lambda {
    _comp = _bs_mk_app_component("api", "apps")
    _entity = backstage.generate_component_entity(_comp, "erp-back", "platform-team", "production", "https://github.com/org/repo")
    assert _entity.apiVersion == "backstage.io/v1alpha1"
    assert _entity.kind == "Component"
    assert _entity.metadata.name == "api"
    assert _entity.spec.lifecycle == "production"
    assert _entity.spec.system == "erp-back"
    assert _entity.metadata.annotations["backstage.io/kubernetes-id"] == "api"
}

# === Test: generate Resource from INFRASTRUCTURE component ===
test_bs_generate_resource_from_infra = lambda {
    _comp = _bs_mk_infra_component("postgres-db", "data")
    _entity = backstage.generate_resource_from_component(_comp, "erp-back", "platform-team", "production")
    assert _entity.apiVersion == "backstage.io/v1alpha1"
    assert _entity.kind == "Resource"
    assert _entity.metadata.name == "postgres-db"
    assert _entity.spec.owner == "platform-team"
}

# === Test: generate Resource from CRD accessory ===
test_bs_generate_resource_from_crd_accessory = lambda {
    _acc = _bs_mk_accessory("kafka-cluster", "infra", "CRD")
    _entity = backstage.generate_resource_from_accessory(_acc, "erp-back", "platform-team", "production")
    assert _entity.kind == "Resource"
    assert _entity.metadata.name == "kafka-cluster"
    assert _entity.metadata.annotations["koncept.io/module-type"] == "CRD"
}

# === Test: generate Resource from SECRET accessory ===
test_bs_generate_resource_from_secret_accessory = lambda {
    _acc = _bs_mk_accessory("db-credentials", "apps", "SECRET")
    _entity = backstage.generate_resource_from_accessory(_acc, "erp-back", "platform-team", "production")
    assert _entity.kind == "Resource"
    assert _entity.metadata.name == "db-credentials"
}

# === Test: generate Resource from namespace ===
test_bs_generate_resource_from_namespace = lambda {
    _ns = _bs_mk_namespace("apps")
    _entity = backstage.generate_resource_from_namespace(_ns, "erp-back", "platform-team", "production")
    assert _entity.kind == "Resource"
    assert _entity.metadata.name == "apps"
}

# === Test: full catalog with mixed components ===
test_bs_full_catalog = lambda {
    _components = [_bs_mk_app_component("api", "apps"), _bs_mk_infra_component("db", "data")]
    _accessories = [_bs_mk_accessory("kafka", "infra", "CRD")]
    _namespaces = [_bs_mk_namespace("apps")]
    _catalog = backstage.generate_catalog_from_stack(
        _components, _accessories, _namespaces,
        "erp-back", "1.0.0", "platform-team", "production", "https://github.com/org/repo", ""
    )
    # Domain + System + 1 app component + 1 infra resource + 1 accessory resource + 1 namespace resource = 6
    assert _catalog.metadata.entityCount == 6
    assert _catalog.metadata.projectName == "erp-back"
}

# === Test: empty stack produces domain + system only ===
test_bs_empty_stack = lambda {
    _catalog = backstage.generate_catalog_from_stack(
        [], [], [],
        "empty-project", "0.1.0", "platform-team", "experimental", "", ""
    )
    # Domain + System = 2
    assert _catalog.metadata.entityCount == 2
}

# === Test: components-only catalog (no accessories or namespaces) ===
test_bs_components_only = lambda {
    _components = [_bs_mk_app_component("web", "apps"), _bs_mk_app_component("worker", "apps")]
    _catalog = backstage.generate_catalog_from_stack(
        _components, [], [],
        "my-project", "2.0.0", "dev-team", "production", "", ""
    )
    # Domain + System + 2 app components = 4
    assert _catalog.metadata.entityCount == 4
}

# === Test: lifecycle and owner propagation ===
test_bs_lifecycle_owner = lambda {
    _comp = _bs_mk_app_component("api", "apps")
    _entity = backstage.generate_component_entity(_comp, "my-system", "dev-team", "experimental", "")
    assert _entity.spec.lifecycle == "experimental"
    assert _entity.spec.owner == "dev-team"
    assert _entity.spec.system == "my-system"
}

# === Test: repo_url annotation ===
test_bs_repo_url_annotation = lambda {
    _comp = _bs_mk_app_component("api", "apps")
    _entity = backstage.generate_component_entity(_comp, "sys", "team", "production", "https://github.com/org/repo")
    assert _entity.metadata.annotations["backstage.io/source-location"] == "url:https://github.com/org/repo"
}

# === Test: techdocs annotation on domain and system ===
test_bs_techdocs_annotation = lambda {
    _domain = backstage.generate_domain("my-proj", "team", "dir:docs/")
    assert _domain.metadata.annotations["backstage.io/techdocs-ref"] == "dir:docs/"
    _system = backstage.generate_system("my-sys", "my-proj", "team", "dir:docs/")
    assert _system.metadata.annotations["backstage.io/techdocs-ref"] == "dir:docs/"
}

# === Test: techdocs annotation absent when empty ===
test_bs_no_techdocs_when_empty = lambda {
    _domain = backstage.generate_domain("my-proj", "team", "")
    assert "backstage.io/techdocs-ref" not in _domain.metadata.annotations
}
