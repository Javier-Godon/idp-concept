"""
Backstage output procedure — generates catalog-info.yaml entities from stack structures.

Maps idp-concept models to Backstage entity kinds:
    Project          → Domain
    Stack            → System
    Component (APP)  → Component (type: service)
    Component (INFRA)→ Resource (type: database/cache/message-queue)
    Accessory (CRD)  → Resource (type: kubernetes-crd)
    Accessory (SECRET)→ Resource (type: secret)
    K8sNamespace     → Resource (type: kubernetes-namespace)

Output structure (written by CLI):
    output/backstage/
    └── catalog-info.yaml   ← multi-document YAML with all entities

Usage:
    import procedures.kcl_to_backstage as backstage

    _entities = backstage.generate_catalog_from_stack(
        _stack.components, _stack.accessories, _stack.k8snamespaces,
        "my-project", "1.0.0", "platform-team", "production",
        "https://github.com/org/repo"
    )
"""
import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace

_BACKSTAGE_API_VERSION = "backstage.io/v1alpha1"

# --- Entity generators ---

generate_domain = lambda project_name: str, owner: str, techdocs_ref: str -> {str:} {
    """Generate a Backstage Domain entity from a project name."""
    {
        apiVersion = _BACKSTAGE_API_VERSION
        kind = "Domain"
        metadata = {
            name = project_name
            annotations = {
                "koncept.io/generated-by" = "idp-concept"
                if techdocs_ref:
                    "backstage.io/techdocs-ref" = techdocs_ref
            }
        }
        spec = {
            owner = owner
        }
    }
}

generate_system = lambda stack_name: str, domain_name: str, owner: str, techdocs_ref: str -> {str:} {
    """Generate a Backstage System entity from a stack name."""
    {
        apiVersion = _BACKSTAGE_API_VERSION
        kind = "System"
        metadata = {
            name = stack_name
            annotations = {
                "koncept.io/generated-by" = "idp-concept"
                if techdocs_ref:
                    "backstage.io/techdocs-ref" = techdocs_ref
            }
        }
        spec = {
            owner = owner
            domain = domain_name
        }
    }
}

generate_component_entity = lambda comp: component.ComponentInstance, system_name: str, owner: str, lifecycle: str, repo_url: str -> {str:} {
    """Generate a Backstage Component entity from a framework ComponentInstance."""
    {
        apiVersion = _BACKSTAGE_API_VERSION
        kind = "Component"
        metadata = {
            name = comp.name
            annotations = {
                "backstage.io/kubernetes-id" = comp.name
                "koncept.io/module-type" = comp.kind
                "koncept.io/generated-by" = "idp-concept"
                if repo_url:
                    "backstage.io/source-location" = "url:${repo_url}"
            }
        }
        spec = {
            $type = "service"
            lifecycle = lifecycle
            owner = owner
            system = system_name
        }
    }
}

_infer_resource_type = lambda kind: str -> str {
    """Infer Backstage resource type from component/accessory kind."""
    "database" if kind == "INFRASTRUCTURE" else \
    "kubernetes-crd" if kind == "CRD" else \
    "secret" if kind == "SECRET" else \
    "resource"
}

generate_resource_from_component = lambda comp: component.ComponentInstance, system_name: str, owner: str, lifecycle: str -> {str:} {
    """Generate a Backstage Resource entity from an INFRASTRUCTURE component."""
    {
        apiVersion = _BACKSTAGE_API_VERSION
        kind = "Resource"
        metadata = {
            name = comp.name
            annotations = {
                "backstage.io/kubernetes-id" = comp.name
                "koncept.io/module-type" = comp.kind
                "koncept.io/generated-by" = "idp-concept"
            }
        }
        spec = {
            $type = _infer_resource_type(comp.kind)
            lifecycle = lifecycle
            owner = owner
            system = system_name
        }
    }
}

generate_resource_from_accessory = lambda acc: accessory.AccessoryInstance, system_name: str, owner: str, lifecycle: str -> {str:} {
    """Generate a Backstage Resource entity from an AccessoryInstance."""
    {
        apiVersion = _BACKSTAGE_API_VERSION
        kind = "Resource"
        metadata = {
            name = acc.name
            annotations = {
                "backstage.io/kubernetes-id" = acc.name
                "koncept.io/module-type" = acc.kind
                "koncept.io/generated-by" = "idp-concept"
            }
        }
        spec = {
            $type = _infer_resource_type(acc.kind)
            lifecycle = lifecycle
            owner = owner
            system = system_name
        }
    }
}

generate_resource_from_namespace = lambda ns: k8snamespace.K8sNamespaceInstance, system_name: str, owner: str, lifecycle: str -> {str:} {
    """Generate a Backstage Resource entity from a K8sNamespaceInstance."""
    {
        apiVersion = _BACKSTAGE_API_VERSION
        kind = "Resource"
        metadata = {
            name = ns.name
            annotations = {
                "backstage.io/kubernetes-id" = ns.name
                "koncept.io/module-type" = "K8sNamespace"
                "koncept.io/generated-by" = "idp-concept"
            }
        }
        spec = {
            $type = "kubernetes-namespace"
            lifecycle = lifecycle
            owner = owner
            system = system_name
        }
    }
}

# --- Full catalog generation ---

generate_catalog_from_stack = lambda components: [component.ComponentInstance], accessories: [accessory.AccessoryInstance], namespaces: [k8snamespace.K8sNamespaceInstance], project_name: str, version: str, owner: str, lifecycle: str, repo_url: str, techdocs_ref: str -> {str:} {
    """Generate a complete Backstage catalog structure from stack data."""
    _stack_name = project_name

    _domain = generate_domain(project_name, owner, techdocs_ref)
    _system = generate_system(_stack_name, project_name, owner, techdocs_ref)

    # APPLICATION components → Backstage Components
    _app_components = [
        generate_component_entity(c, _stack_name, owner, lifecycle, repo_url)
        for c in components if c.kind == "APPLICATION"
    ] if components else []

    # INFRASTRUCTURE components → Backstage Resources
    _infra_resources = [
        generate_resource_from_component(c, _stack_name, owner, lifecycle)
        for c in components if c.kind == "INFRASTRUCTURE"
    ] if components else []

    # Accessories → Backstage Resources
    _accessory_resources = [
        generate_resource_from_accessory(a, _stack_name, owner, lifecycle)
        for a in accessories
    ] if accessories else []

    # Namespaces → Backstage Resources
    _namespace_resources = [
        generate_resource_from_namespace(n, _stack_name, owner, lifecycle)
        for n in namespaces
    ] if namespaces else []

    _all_entities = [_domain, _system] + _app_components + _infra_resources + _accessory_resources + _namespace_resources

    {
        metadata = {
            projectName = project_name
            version = version
            entityCount = len(_all_entities)
        }
        entities = _all_entities
    }
}
