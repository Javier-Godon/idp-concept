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

_wrap_in_object = lambda resource_name: str, manifest: any -> {str:} {
    {
        name = resource_name
        base = {
            apiVersion = "kubernetes.crossplane.io/v1alpha2"
            kind = "Object"
            metadata.name = resource_name
            spec = {
                providerConfigRef.name = _PROVIDER_KUBERNETES
                forProvider.manifest = manifest
            }
        }
    }
}

# --- Process module types into Crossplane resources ---

_process_namespaces = lambda namespaces: [k8snamespace.K8sNamespaceInstance] -> [{str:}] {
    [
        _wrap_in_object(
            _ns_resource_name(ns.name)
            m
        )
        for ns in namespaces
        for m in ns.manifests
    ] if namespaces else []
}

_process_components = lambda components: [component.ComponentInstance] -> [{str:}] {
    [
        _wrap_in_object(
            _manifest_resource_name("comp", comp.name, m)
            m
        )
        for comp in components
        for m in comp.manifests
    ] if components else []
}

_process_accessories = lambda accessories: [accessory.AccessoryInstance] -> [{str:}] {
    [
        _wrap_in_object(
            _manifest_resource_name("acc", acc.name, m)
            m
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
    _name if dep.kind == "Namespace" else ("comp-${_name}-.*" if dep.kind == "APPLICATION" or dep.kind == "INFRASTRUCTURE" else "acc-${_name}-.*")
}

_module_resource_pattern = lambda module_type: str, module_name: str -> str {
    "${module_type}-${_sanitize(module_name)}-.*"
}

_build_sequencer_rules = lambda components: [component.ComponentInstance], accessories: [accessory.AccessoryInstance] -> [{str:}] {
    """Build function-sequencer rules from dependsOn chains.
    Each dependency creates a sequence: [dependency-pattern, dependent-pattern].
    The sequencer ensures dependency resources are ready before dependent resources are created."""
    _comp_rules = [
        { sequence = [_dep_resource_pattern(dep), _module_resource_pattern("comp", comp.name)] }
        for comp in (components if components else [])
        for dep in (comp.dependsOn if comp.dependsOn else [])
    ]
    _acc_rules = [
        { sequence = [_dep_resource_pattern(dep), _module_resource_pattern("acc", acc.name)] }
        for acc in (accessories if accessories else [])
        for dep in (acc.dependsOn if acc.dependsOn else [])
    ]
    _comp_rules + _acc_rules
}

# --- Generate XRD ---

generate_xrd = lambda stack_name: str, xr_kind: str -> {str:} {
    """Generate a CompositeResourceDefinition for a stack."""
    _plural = xr_kind.lower() + "s"
    {
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
    }
}

# --- Generate Composition ---

generate_composition = lambda xr_kind: str, resources: [{str:}], sequencer_rules: [{str:}] -> {str:} {
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
    {
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
    }
}

# --- Generate XR Instance ---

generate_xr = lambda xr_kind: str, instance_name: str -> {str:} {
    """Generate a Composite Resource instance to trigger deployment."""
    {
        apiVersion = _API_VERSION
        kind = xr_kind
        metadata.name = instance_name
        spec.id = instance_name
    }
}

# --- Generate prerequisites ---

generate_prerequisites = lambda -> [{str:}] {
    """Generate the Crossplane infrastructure prerequisites (providers + functions)."""
    [
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
}

# --- Main entry point ---

generate_crossplane_from_stack = lambda components: [component.ComponentInstance], accessories: [accessory.AccessoryInstance], namespaces: [k8snamespace.K8sNamespaceInstance], stack_name: str, version: str -> {str:} {
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
    _ns_resources = _process_namespaces(namespaces)
    _acc_resources = _process_accessories(accessories)
    _comp_resources = _process_components(components)
    _all_resources = _ns_resources + _acc_resources + _comp_resources

    # Build sequencer rules from dependsOn chains
    _sequencer_rules = _build_sequencer_rules(components, accessories)

    {
        xrd = generate_xrd(stack_name, _xr_kind)
        composition = generate_composition(_xr_kind, _all_resources, _sequencer_rules)
        xr = generate_xr(_xr_kind, _instance_name)
        prerequisites = generate_prerequisites()
        metadata = {
            resourceCount = len(_all_resources)
            sequencerRules = len(_sequencer_rules)
            xrKind = _xr_kind
            version = version
        }
    }
}
