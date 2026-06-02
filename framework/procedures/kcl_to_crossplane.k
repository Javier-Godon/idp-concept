"""
Crossplane output procedure — generates XRD, Composition, and XR from stack structures.

Wraps K8s manifests in Crossplane Object resources (provider-kubernetes) and
Helm charts in Release resources (provider-helm), using function-sequencer for
dependency ordering derived from the framework's dependsOn chains.

Output structure (written by CLI):
    output/crossplane/
    ├── xrd.yaml                  # CompositeResourceDefinition
    ├── composition.yaml          # Composition with pipeline
    ├── xr.yaml                   # Composite Resource instance
    └── prerequisites/
        ├── providers.yaml        # Provider + ProviderConfig manifests
        └── functions.yaml        # Function package manifests

Pipeline architecture:
    Step 1: function-patch-and-transform → creates all Crossplane Object/Release resources
    Step 2: function-sequencer → enforces dependsOn ordering
    Step 3: function-auto-ready → detects readiness before marking composite ready

Usage:
    import procedures.kcl_to_crossplane as crossplane_proc

    _result = crossplane_proc.generate_crossplane_from_stack(
        _stack.components, _stack.accessories, _stack.k8snamespaces,
        "my-stack", "1.0.0"
    )
"""
import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace
import procedures.kcl_to_yaml as yaml_proc

# --- Constants ---

_API_GROUP = "koncept.bluesolution.es"
_API_VERSION = "koncept.bluesolution.es/v1alpha1"
_PROVIDER_KUBERNETES = "provider-kubernetes"
_PROVIDER_HELM = "helm-provider"

# --- Pinned versions (from crossplane_v2/) ---

_PROVIDER_KUBERNETES_VERSION = "xpkg.upbound.io/upbound/provider-kubernetes:v1"
_PROVIDER_HELM_VERSION = "xpkg.upbound.io/upbound/provider-helm:v1"
_FUNC_PATCH_AND_TRANSFORM_VERSION = "xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.9.0"
_FUNC_SEQUENCER_VERSION = "xpkg.upbound.io/crossplane-contrib/function-sequencer:v0.2.3"
_FUNC_AUTO_READY_VERSION = "xpkg.upbound.io/crossplane-contrib/function-auto-ready:v0.5.0"

# --- Name sanitization ---

_sanitize = lambda name: str -> str {
    name.lower().replace("_", "-")
}

_to_xr_kind = lambda name: str -> str {
    """Convert a stack name to a CamelCase XR Kind with X prefix.
    e.g. 'erp-back' → 'XErpBack', 'video_streaming' → 'XVideoStreaming'
    """
    _titled = name.replace("-", " ").replace("_", " ").title().replace(" ", "")
    "X${_titled}"
}

# --- Resource naming helpers ---

_ns_resource_name = lambda ns_name: str -> str {
    "ns-${_sanitize(ns_name)}"
}

_manifest_resource_name = lambda prefix: str, module_name: str, manifest: any -> str {
    _kind = manifest.kind.lower() if manifest.kind else "unknown"
    _name = _sanitize(manifest.metadata.name) if manifest.metadata?.name else "unnamed"
    "${prefix}-${_sanitize(module_name)}-${_kind}-${_name}"
}

# --- Wrap K8s manifest in Crossplane Object ---

_wrap_in_object = lambda resource_name: str, manifest: any, meta: any = Undefined -> {str:} {
    _manifest = yaml_proc.apply_stack_metadata(manifest, meta)
    {
        name = resource_name
        base = yaml_proc.apply_stack_metadata({
            apiVersion = "kubernetes.crossplane.io/v1alpha2"
            kind = "Object"
            metadata.name = resource_name
            spec = {
                providerConfigRef.name = _PROVIDER_KUBERNETES
                forProvider.manifest = _manifest
            }
        }, meta)
    }
}

# --- Process module types into Crossplane resources ---

_process_namespaces = lambda namespaces: [k8snamespace.K8sNamespaceInstance], meta: any = Undefined -> [{str:}] {
    [
        _wrap_in_object(
            _ns_resource_name(ns.name)
            m
            meta
        )
        for ns in namespaces
        for m in ns.manifests
    ] if namespaces else []
}

_process_components = lambda components: [component.ComponentInstance], meta: any = Undefined -> [{str:}] {
    [
        _wrap_in_object(
            _manifest_resource_name("comp", comp.name, m)
            m
            meta
        )
        for comp in components
        for m in comp.manifests
    ] if components else []
}

_process_accessories = lambda accessories: [accessory.AccessoryInstance], meta: any = Undefined -> [{str:}] {
    [
        _wrap_in_object(
            _manifest_resource_name("acc", acc.name, m)
            m
            meta
        )
        for acc in accessories
        for m in acc.manifests
    ] if accessories else []
}

# --- Build sequencer rules from dependsOn ---

_dep_resource_pattern = lambda dep: any -> str {
    """Get the resource name pattern for a dependency. Namespaces get exact names,
    components/accessories get regex patterns to match all their resources."""
    _name = _sanitize(dep.name)
    _ns_resource_name(_name) if dep.kind == "Namespace" else ("comp-${_name}-.*" if dep.kind == "APPLICATION" or dep.kind == "INFRASTRUCTURE" else "acc-${_name}-.*")
}

_module_resource_pattern = lambda module_type: str, module_name: str -> str {
    "${module_type}-${_sanitize(module_name)}-.*"
}

_component_resource_names = lambda components: [component.ComponentInstance], module_name: str, module_namespace: str -> [str] {
    [
        _manifest_resource_name("comp", comp.name, m)
        for comp in (components if components else [])
        for m in comp.manifests
        if comp.name == module_name and comp.namespace == module_namespace
    ]
}

_accessory_resource_names = lambda accessories: [accessory.AccessoryInstance], module_name: str, module_namespace: str -> [str] {
    [
        _manifest_resource_name("acc", acc.name, m)
        for acc in (accessories if accessories else [])
        for m in acc.manifests
        if acc.name == module_name and acc.namespace == module_namespace
    ]
}

_namespace_resource_names = lambda namespaces: [k8snamespace.K8sNamespaceInstance], name: str -> [str] {
    [_ns_resource_name(ns.name) for ns in (namespaces if namespaces else []) if ns.name == name]
}

_dependency_resource_names = lambda dep: any, components: [component.ComponentInstance], accessories: [accessory.AccessoryInstance], namespaces: [k8snamespace.K8sNamespaceInstance] -> [str] {
    _ns_names = _namespace_resource_names(namespaces, dep.name) if dep.kind == "Namespace" else []
    _comp_names = _component_resource_names(components, dep.name, dep.namespace) if dep.kind == "APPLICATION" or dep.kind == "INFRASTRUCTURE" else []
    _acc_names = _accessory_resource_names(accessories, dep.name, dep.namespace) if dep.kind == "CRD" or dep.kind == "SECRET" else []
    _resolved = _ns_names + _comp_names + _acc_names
    _resolved if _resolved else [_dep_resource_pattern(dep)]
}

_build_sequencer_rules = lambda components: [component.ComponentInstance], accessories: [accessory.AccessoryInstance], namespaces: [k8snamespace.K8sNamespaceInstance] -> [{str:}] {
    """Build function-sequencer rules from dependsOn chains.
    Each dependency creates sequences using concrete wrapped resource names whenever
    possible (regex fallback only for unresolved dependency references)."""
    _comp_rules = [
        { sequence = [dep_name, dependent_name] }
        for comp in (components if components else [])
        for dep in (comp.dependsOn if comp.dependsOn else [])
        for dep_name in _dependency_resource_names(dep, components, accessories, namespaces)
        for dependent_name in [_manifest_resource_name("comp", comp.name, m) for m in comp.manifests]
    ]
    _acc_rules = [
        { sequence = [dep_name, dependent_name] }
        for acc in (accessories if accessories else [])
        for dep in (acc.dependsOn if acc.dependsOn else [])
        for dep_name in _dependency_resource_names(dep, components, accessories, namespaces)
        for dependent_name in [_manifest_resource_name("acc", acc.name, m) for m in acc.manifests]
    ]
    _comp_rules + _acc_rules
}

# --- Generate XRD ---

generate_xrd = lambda stack_name: str, xr_kind: str, meta: any = Undefined -> {str:} {
    """Generate a CompositeResourceDefinition for a stack."""
    _plural = xr_kind.lower() + "s"
    yaml_proc.apply_stack_metadata({
        apiVersion = "apiextensions.crossplane.io/v2"
        kind = "CompositeResourceDefinition"
        metadata.name = "${_plural}.${_API_GROUP}"
        spec = {
            group = _API_GROUP
            names = {
                kind = xr_kind
                plural = _plural
            }
            claimNames = {
                kind = stack_name.replace("-", " ").replace("_", " ").title().replace(" ", "")
                plural = _sanitize(stack_name) + "s"
            }
            versions = [{
                name = "v1alpha1"
                served = True
                referenceable = True
                schema.openAPIV3Schema = {
                    $type = "object"
                    properties.spec = {
                        $type = "object"
                        properties = {
                            id = {
                                $type = "string"
                                description = "Unique identifier for this deployment"
                            }
                            namespace = {
                                $type = "string"
                                description = "Default namespace for resources"
                            }
                        }
                    }
                }
            }]
        }
    }, meta)
}

# --- Generate Composition ---

generate_composition = lambda xr_kind: str, resources: [{str:}], sequencer_rules: [{str:}], meta: any = Undefined -> {str:} {
    """Generate a Composition with pipeline steps for resource creation, sequencing, and readiness."""
    _pipeline = [
        {
            step = "render-manifests"
            functionRef.name = "function-patch-and-transform"
            input = {
                apiVersion = "pt.fn.crossplane.io/v1beta1"
                kind = "Resources"
                resources = resources
            }
        }
    ]
    _sequencer_step = [
        {
            step = "sequence-creation"
            functionRef.name = "function-sequencer"
            input = {
                apiVersion = "sequencer.fn.crossplane.io/v1beta1"
                kind = "Input"
                rules = sequencer_rules
            }
        }
    ] if sequencer_rules else []
    _ready_step = [
        {
            step = "automatically-detect-readiness"
            functionRef.name = "function-auto-ready"
        }
    ]
    yaml_proc.apply_stack_metadata({
        apiVersion = "apiextensions.crossplane.io/v1"
        kind = "Composition"
        metadata.name = "${xr_kind.lower()}-composition"
        spec = {
            compositeTypeRef = {
                apiVersion = _API_VERSION
                kind = xr_kind
            }
            mode = "Pipeline"
            pipeline = _pipeline + _sequencer_step + _ready_step
        }
    }, meta)
}

# --- Generate XR Instance ---

generate_xr = lambda xr_kind: str, instance_name: str, meta: any = Undefined -> {str:} {
    """Generate a Composite Resource instance to trigger deployment."""
    yaml_proc.apply_stack_metadata({
        apiVersion = _API_VERSION
        kind = xr_kind
        metadata.name = instance_name
        spec.id = instance_name
    }, meta)
}

# --- Generate prerequisites ---

generate_prerequisites = lambda meta: any = Undefined -> [{str:}] {
    """Generate the Crossplane infrastructure prerequisites (providers + functions)."""
    _resources = [
        # Provider: Kubernetes
        {
            apiVersion = "pkg.crossplane.io/v1"
            kind = "Provider"
            metadata.name = "provider-kubernetes"
            spec.package = _PROVIDER_KUBERNETES_VERSION
        }
        {
            apiVersion = "kubernetes.crossplane.io/v1alpha1"
            kind = "ProviderConfig"
            metadata.name = _PROVIDER_KUBERNETES
            spec.credentials.source = "InjectedIdentity"
        }
        # Provider: Helm
        {
            apiVersion = "pkg.crossplane.io/v1"
            kind = "Provider"
            metadata.name = "provider-helm"
            spec.package = _PROVIDER_HELM_VERSION
        }
        {
            apiVersion = "helm.crossplane.io/v1beta1"
            kind = "ProviderConfig"
            metadata.name = _PROVIDER_HELM
            spec.credentials.source = "InjectedIdentity"
        }
        # Functions
        {
            apiVersion = "pkg.crossplane.io/v1beta1"
            kind = "Function"
            metadata.name = "function-patch-and-transform"
            spec.package = _FUNC_PATCH_AND_TRANSFORM_VERSION
        }
        {
            apiVersion = "pkg.crossplane.io/v1beta1"
            kind = "Function"
            metadata.name = "function-sequencer"
            spec.package = _FUNC_SEQUENCER_VERSION
        }
        {
            apiVersion = "pkg.crossplane.io/v1beta1"
            kind = "Function"
            metadata.name = "function-auto-ready"
            spec.package = _FUNC_AUTO_READY_VERSION
        }
    ]
    [yaml_proc.apply_stack_metadata(resource, meta) for resource in _resources]
}

# --- Main entry point ---

generate_crossplane_from_stack = lambda components: [component.ComponentInstance], accessories: [accessory.AccessoryInstance], namespaces: [k8snamespace.K8sNamespaceInstance], stack_name: str, version: str, meta: any = Undefined -> {str:} {
    """Generate complete Crossplane output (XRD + Composition + XR + prerequisites) from stack data.

    Args:
        components: List of ComponentInstance from the stack
        accessories: List of AccessoryInstance from the stack
        namespaces: List of K8sNamespaceInstance from the stack
        stack_name: Human-readable stack name (e.g. 'erp-back')
        version: Stack version (e.g. '1.0.0')

    Returns:
        Dict with keys: xrd, composition, xr, prerequisites, metadata
    """
    _xr_kind = _to_xr_kind(stack_name)
    _instance_name = "${_sanitize(stack_name)}-workload"

    # Process all modules into Crossplane resources (order: namespaces → accessories → components)
    _ns_resources = _process_namespaces(namespaces, meta)
    _acc_resources = _process_accessories(accessories, meta)
    _comp_resources = _process_components(components, meta)
    _all_resources = _ns_resources + _acc_resources + _comp_resources

    # Build sequencer rules from dependsOn chains
    _sequencer_rules = _build_sequencer_rules(components, accessories, namespaces)

    {
        xrd = generate_xrd(stack_name, _xr_kind, meta)
        composition = generate_composition(_xr_kind, _all_resources, _sequencer_rules, meta)
        xr = generate_xr(_xr_kind, _instance_name, meta)
        prerequisites = generate_prerequisites(meta)
        metadata = {
            resourceCount = len(_all_resources)
            sequencerRules = len(_sequencer_rules)
            xrKind = _xr_kind
            version = version
        }
    }
}

generate_crossplane_from_render_stack = lambda input_stack: any, stack_name: str, version: str -> {str:} {
    """Generate complete Crossplane output from a RenderStack, preserving stack metadata."""
    generate_crossplane_from_stack(input_stack.components, input_stack.accessories, input_stack.k8snamespaces, stack_name, version, input_stack.metadata)
}
