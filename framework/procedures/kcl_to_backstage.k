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
        "https://github.com/org/repo", "dir:docs/", _stack.metadata
    )
"""
import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace

_BACKSTAGE_API_VERSION = "backstage.io/v1alpha1"

# --- Entity generators ---

_metadata_annotations = lambda meta: any -> {str:str} {
    """Map portable IDP catalog metadata to koncept.io/* Backstage annotations."""
    {} if meta is Undefined else {
        if meta.owner is not Undefined:
            "koncept.io/owner" = meta.owner
        if meta.team is not Undefined:
            "koncept.io/team" = meta.team
        if meta.lifecycle is not Undefined:
            "koncept.io/lifecycle" = meta.lifecycle
        if meta.tier is not Undefined:
            "koncept.io/tier" = meta.tier
        if meta.sloTier is not Undefined:
            "koncept.io/slo-tier" = meta.sloTier
        if meta.criticality is not Undefined:
            "koncept.io/criticality" = meta.criticality
        if meta.dataClassification is not Undefined:
            "koncept.io/data-classification" = meta.dataClassification
        if meta.costCenter is not Undefined:
            "koncept.io/cost-center" = meta.costCenter
        if meta.runbook is not Undefined:
            "koncept.io/runbook" = meta.runbook
        if meta.support is not Undefined:
            "koncept.io/support-contact" = meta.support
    }
}

_apply_metadata_annotations = lambda entity: {str:}, anns: {str:str} -> {str:} {
    """Merge derived catalog annotations onto an already-generated entity."""
    entity if not anns else entity | {
        metadata.annotations = entity.metadata.annotations | anns
    }
}

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

_dependency_ref = lambda dep: any -> str {
    """Map a framework dependency object to a Backstage entity reference."""
    "component:${dep.name}" if dep.kind == "APPLICATION" else \
    "resource:kubernetes-namespace-${dep.name}" if dep.kind == "Namespace" else \
    "resource:${dep.name}"
}

_dependency_refs = lambda deps: [any] -> [str] {
    [_dependency_ref(dep) for dep in deps] if deps else []
}

generate_component_entity = lambda comp: component.ComponentInstance, system_name: str, owner: str, lifecycle: str, repo_url: str -> {str:} {
    """Generate a Backstage Component entity from a framework ComponentInstance."""
    _depends_on_refs = _dependency_refs(comp.dependsOn)
    {
        apiVersion = _BACKSTAGE_API_VERSION
        kind = "Component"
        metadata = {
            name = comp.name
            annotations = {
                "backstage.io/kubernetes-id" = comp.name
                "koncept.io/module-type" = comp.kind
                "koncept.io/generated-by" = "idp-concept"
                "koncept.io/namespace" = comp.namespace
                "koncept.io/asset-version" = comp.asset.version
                if comp.asset.image is not Undefined:
                    "koncept.io/container-image" = comp.asset.image
                if comp.asset.helmChart is not Undefined:
                    "koncept.io/helm-chart" = comp.asset.helmChart
                if repo_url:
                    "backstage.io/source-location" = "url:${repo_url}"
            }
        }
        spec = {
            $type = "service"
            lifecycle = lifecycle
            owner = owner
            system = system_name
            if _depends_on_refs:
                dependsOn = _depends_on_refs
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
    _depends_on_refs = _dependency_refs(comp.dependsOn)
    {
        apiVersion = _BACKSTAGE_API_VERSION
        kind = "Resource"
        metadata = {
            name = comp.name
            annotations = {
                "backstage.io/kubernetes-id" = comp.name
                "koncept.io/module-type" = comp.kind
                "koncept.io/generated-by" = "idp-concept"
                "koncept.io/namespace" = comp.namespace
                "koncept.io/asset-version" = comp.asset.version
                if comp.asset.image is not Undefined:
                    "koncept.io/container-image" = comp.asset.image
                if comp.asset.helmChart is not Undefined:
                    "koncept.io/helm-chart" = comp.asset.helmChart
            }
        }
        spec = {
            $type = _infer_resource_type(comp.kind)
            lifecycle = lifecycle
            owner = owner
            system = system_name
            if _depends_on_refs:
                dependsOn = _depends_on_refs
        }
    }
}

generate_resource_from_accessory = lambda acc: accessory.AccessoryInstance, system_name: str, owner: str, lifecycle: str -> {str:} {
    """Generate a Backstage Resource entity from an AccessoryInstance."""
    _depends_on_refs = _dependency_refs(acc.dependsOn)
    {
        apiVersion = _BACKSTAGE_API_VERSION
        kind = "Resource"
        metadata = {
            name = acc.name
            annotations = {
                "backstage.io/kubernetes-id" = acc.name
                "koncept.io/module-type" = acc.kind
                "koncept.io/generated-by" = "idp-concept"
                "koncept.io/namespace" = acc.namespace
                "koncept.io/asset-version" = acc.asset.version
                if acc.asset.image is not Undefined:
                    "koncept.io/container-image" = acc.asset.image
            }
        }
        spec = {
            $type = _infer_resource_type(acc.kind)
            lifecycle = lifecycle
            owner = owner
            system = system_name
            if _depends_on_refs:
                dependsOn = _depends_on_refs
        }
    }
}

generate_resource_from_namespace = lambda ns: k8snamespace.K8sNamespaceInstance, system_name: str, owner: str, lifecycle: str -> {str:} {
    """Generate a Backstage Resource entity from a K8sNamespaceInstance."""
    {
        apiVersion = _BACKSTAGE_API_VERSION
        kind = "Resource"
        metadata = {
            name = "kubernetes-namespace-${ns.name}"
            annotations = {
                "backstage.io/kubernetes-id" = ns.name
                "koncept.io/module-type" = "K8sNamespace"
                "koncept.io/generated-by" = "idp-concept"
                "koncept.io/namespace" = ns.name
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

generate_catalog_from_stack = lambda components: [component.ComponentInstance], accessories: [accessory.AccessoryInstance], namespaces: [k8snamespace.K8sNamespaceInstance], project_name: str, version: str, owner: str, lifecycle: str, repo_url: str, techdocs_ref: str, stack_metadata: any -> {str:} {
    """Generate a complete Backstage catalog structure from stack data.

    `stack_metadata` is an optional `models.metadata.Metadata` instance (or
    Undefined). When present, its `owner`/`lifecycle` override the positional
    defaults and SLO tier, data classification, cost center, runbook, and
    support-contact fields are emitted as `koncept.io/*` annotations on every
    generated entity.
    """
    _stack_name = project_name

    _owner = stack_metadata.owner if (stack_metadata is not Undefined and stack_metadata.owner is not Undefined) else owner
    _lifecycle = stack_metadata.lifecycle if (stack_metadata is not Undefined and stack_metadata.lifecycle is not Undefined) else lifecycle
    _meta_anns = _metadata_annotations(stack_metadata)

    _domain = generate_domain(project_name, _owner, techdocs_ref)
    _system = generate_system(_stack_name, project_name, _owner, techdocs_ref)

    # APPLICATION components → Backstage Components
    _app_components = [
        generate_component_entity(c, _stack_name, _owner, _lifecycle, repo_url)
        for c in components if c.kind == "APPLICATION"
    ] if components else []

    # INFRASTRUCTURE components → Backstage Resources
    _infra_resources = [
        generate_resource_from_component(c, _stack_name, _owner, _lifecycle)
        for c in components if c.kind == "INFRASTRUCTURE"
    ] if components else []

    # Accessories → Backstage Resources
    _accessory_resources = [
        generate_resource_from_accessory(a, _stack_name, _owner, _lifecycle)
        for a in accessories
    ] if accessories else []

    # Namespaces → Backstage Resources
    _namespace_resources = [
        generate_resource_from_namespace(n, _stack_name, _owner, _lifecycle)
        for n in namespaces
    ] if namespaces else []

    _raw_entities = [_domain, _system] + _app_components + _infra_resources + _accessory_resources + _namespace_resources
    _all_entities = [_apply_metadata_annotations(e, _meta_anns) for e in _raw_entities]

    {
        metadata = {
            projectName = project_name
            version = version
            entityCount = len(_all_entities)
        }
        entities = _all_entities
    }
}
