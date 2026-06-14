"""
Crossplane output procedure — generates XRD, Composition, and XR from stack structures.

Two-track architecture (Phase E2 Convergence):

Track 1: Curated Managed Resources (professional control-plane APIs)
  - For 23 infrastructure services with hand-authored XRDs in crossplane_v2/managed_resources/
  - Generates typed XR/Claim instances referencing the curated APIs
  - Example: MongoDB → XMongoDBInstance Claim

Track 2: Bridge (manifest wrapping, backward compatibility)
  - For unmodeled services and application workloads (WebAppModule, etc.)
  - Wraps K8s manifests in Crossplane Object resources (provider-kubernetes)
  - Wraps Helm charts in Release resources (provider-helm)
  - Uses function-sequencer for dependency ordering from framework's dependsOn chains

Output structure (written by CLI):
    output/crossplane/
    ├── xrd.yaml                  # CompositeResourceDefinition
    ├── composition.yaml          # Composition with pipeline
    ├── xr.yaml                   # Composite Resource instance
    ├── managed_resources/        # Curated XR/Claim instances (Track 1)
    │   ├── <service>_claim.yaml  # e.g., mongodb_claim.yaml
    │   └── ...
    └── prerequisites/
        ├── providers.yaml        # Provider + ProviderConfig manifests
        └── functions.yaml        # Function package manifests

Pipeline architecture:
    Step 1: function-patch-and-transform → creates all bridge resources (Track 2)
    Step 2: function-sequencer → enforces dependsOn ordering
    Step 3: function-auto-ready → detects readiness before marking composite ready

Curated Services (Track 1 — no Object wrapping):
    PostgreSQL, Timescale, Kafka, Keycloak, Cert-Manager, MongoDB, RabbitMQ, Redis, Valkey,
    OpenSearch, MinIO, Vault, OpenBao, QuestDB, Elasticsearch, Kibana, Logstash,
    OpenTelemetry, Data Prepper, Fluent Bit, Ceph, Longhorn, Observability

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

# --- Curated Managed Resources (Phase E2 Convergence) ---
# Services with hand-authored XRDs in crossplane_v2/managed_resources/
# These emit XR/Claim instances instead of Object wrappers

_CURATED_SERVICES = {
    # Tier 0: Platform foundation
    "ceph" = {xrd_kind = "XCephCluster", claim_kind = "CephCluster", api_group = "koncept.bluesolution.es"}
    # Tier 1: Operator-managed infrastructure
    "postgresql" = {xrd_kind = "XPostgresInstance", claim_kind = "PostgresInstance", api_group = "koncept.bluesolution.es"}
    "timescaledb" = {xrd_kind = "XTimescaleDBInstance", claim_kind = "TimescaleDBInstance", api_group = "koncept.bluesolution.es"}
    "kafka" = {xrd_kind = "XKafkaStrimzi", claim_kind = "KafkaStrimzi", api_group = "koncept.bluesolution.es"}
    "keycloak" = {xrd_kind = "XKeycloak", claim_kind = "Keycloak", api_group = "koncept.bluesolution.es"}
    "longhorn" = {xrd_kind = "XLonghornInstance", claim_kind = "LonghornInstance", api_group = "koncept.bluesolution.es"}
    "mongodb" = {xrd_kind = "XMongoDBInstance", claim_kind = "MongoDBInstance", api_group = "koncept.bluesolution.es"}
    "rabbitmq" = {xrd_kind = "XRabbitMQCluster", claim_kind = "RabbitMQCluster", api_group = "koncept.bluesolution.es"}
    "redis" = {xrd_kind = "XRedisInstance", claim_kind = "RedisInstance", api_group = "koncept.bluesolution.es"}
    "valkey" = {xrd_kind = "XValkeyInstance", claim_kind = "ValkeyInstance", api_group = "koncept.bluesolution.es"}
    "opensearch" = {xrd_kind = "XOpenSearchCluster", claim_kind = "OpenSearchCluster", api_group = "koncept.bluesolution.es"}
    "minio" = {xrd_kind = "XMinIOTenant", claim_kind = "MinIOTenant", api_group = "koncept.bluesolution.es"}
    "vault" = {xrd_kind = "XVaultInstance", claim_kind = "VaultInstance", api_group = "koncept.bluesolution.es"}
    "openbao" = {xrd_kind = "XOpenBaoInstance", claim_kind = "OpenBaoInstance", api_group = "koncept.bluesolution.es"}
    # Tier 2: Application-level infrastructure
    "questdb" = {xrd_kind = "XQuestDBInstance", claim_kind = "QuestDBInstance", api_group = "koncept.bluesolution.es"}
    "elasticsearch" = {xrd_kind = "XElasticsearchCluster", claim_kind = "ElasticsearchCluster", api_group = "koncept.bluesolution.es"}
    "kibana" = {xrd_kind = "XKibanaInstance", claim_kind = "KibanaInstance", api_group = "koncept.bluesolution.es"}
    "logstash" = {xrd_kind = "XLogstashInstance", claim_kind = "LogstashInstance", api_group = "koncept.bluesolution.es"}
    "opentelemetry" = {xrd_kind = "XOpenTelemetryCollector", claim_kind = "OpenTelemetryCollector", api_group = "koncept.bluesolution.es"}
    "dataprepper" = {xrd_kind = "XDataPrepperPipeline", claim_kind = "DataPrepperPipeline", api_group = "koncept.bluesolution.es"}
    "fluentbit" = {xrd_kind = "XFluentBitInstance", claim_kind = "FluentBitInstance", api_group = "koncept.bluesolution.es"}
    "observability" = {xrd_kind = "XObservabilityProvisioner", claim_kind = "ObservabilityProvisioner", api_group = "koncept.bluesolution.es"}
}

_is_curated_service = lambda service_name: str -> bool {
    """Check if a service has a curated Crossplane API."""
    service_name.lower() in _CURATED_SERVICES
}

_get_curated_api_info = lambda service_name: str -> {str:} {
    """Get XRD/Claim info for a curated service, or empty dict if not curated."""
    _lower = service_name.lower()
    (_CURATED_SERVICES[_lower] if _lower in _CURATED_SERVICES else {})
}

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

_ns_to_resources = lambda namespace: k8snamespace.K8sNamespaceInstance, meta: any = Undefined -> [{str:}] {
    [_wrap_in_object(_ns_resource_name(ns.name), m, meta) for ns in [namespace] for m in namespace.manifests]
}

_process_namespaces = lambda namespaces: [k8snamespace.K8sNamespaceInstance], meta: any = Undefined -> [{str:}] {
    [r for ns in (namespaces if namespaces else []) for r in _ns_to_resources(ns, meta)]
}

_comp_to_resources = lambda component: component.ComponentInstance, meta: any = Undefined -> [{str:}] {
    [_wrap_in_object(_manifest_resource_name("comp", component.instance.name, m), m, meta) for m in component.instance.manifests]
}

_process_components = lambda components: [component.ComponentInstance], meta: any = Undefined -> [{str:}] {
    [r for comp in (components if components else []) for r in _comp_to_resources(comp, meta)]
}

# --- Convergence Logic: Generate curated XR/Claim or bridge Object ---

_generate_curated_claim = lambda accessory_name: str, namespace: str, component: str, api_info: {str:}, meta: any = Undefined -> {str:} {
    """Generate a Claim instance for a curated managed resource.
    Example: MongoDB accessory → MongoDBInstance Claim"""
    _claim_kind = (api_info["claim_kind"] if "claim_kind" in api_info else "")
    _api_group = (api_info["api_group"] if "api_group" in api_info else "koncept.bluesolution.es")
    yaml_proc.apply_stack_metadata({
        apiVersion = "${_api_group}/v1alpha1"
        kind = _claim_kind
        metadata.name = _sanitize(accessory_name)
        metadata.namespace = namespace
        spec = {}
    }, meta) if _claim_kind else {}
}

_process_accessories = lambda accessories: [accessory.AccessoryInstance], meta: any = Undefined -> [{str:}] {
    """Process accessories into Crossplane resources.

    Track 1 (Curated): Generates Claim instances for infrastructure services with hand-authored XRDs
    Track 2 (Bridge): Wraps remaining manifests in Object resources for backward compatibility
    """
    # Track 1: Curated managed resources (Claims for infrastructure services)
    _curated = [{_type = "claim", _resource = _generate_curated_claim(acc.name, acc.namespace, acc.component, _get_curated_api_info(acc.component), meta)} for acc in (accessories if accessories else []) if _is_curated_service(acc.component) and _get_curated_api_info(acc.component)]

    # Track 2: Bridge objects (for unmodeled services)
    # Collect all manifests from non-curated accessories
    _non_curated_accessories = [acc for acc in (accessories if accessories else []) if not (_is_curated_service(acc.component) and _get_curated_api_info(acc.component))]
    _bridge = [(_wrap_in_object(_manifest_resource_name("acc", acc.name, m), m, meta) | {_type = "bridge"}) for acc in _non_curated_accessories for m in acc.manifests]

    _curated + _bridge
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
    [_manifest_resource_name("comp", comp.name, m) for comp in (components if components else []) if comp.name == module_name and comp.namespace == module_namespace for m in comp.manifests]
}

_accessory_resource_names = lambda accessories: [accessory.AccessoryInstance], module_name: str, module_namespace: str -> [str] {
    [_manifest_resource_name("acc", acc.name, m) for acc in (accessories if accessories else []) if acc.name == module_name and acc.namespace == module_namespace for m in acc.manifests]
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
    _comp_rules = [{ sequence = [dep_name, dependent_name] } for comp in (components if components else []) for dep in (comp.dependsOn if comp.dependsOn else []) for dep_name in _dependency_resource_names(dep, components, accessories, namespaces) for dependent_name in [_manifest_resource_name("comp", comp.name, m) for m in comp.manifests]]
    _acc_rules = [{ sequence = [dep_name, dependent_name] } for acc in (accessories if accessories else []) for dep in (acc.dependsOn if acc.dependsOn else []) for dep_name in _dependency_resource_names(dep, components, accessories, namespaces) for dependent_name in [_manifest_resource_name("acc", acc.name, m) for m in acc.manifests]]
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
                "schema" = {
                    openAPIV3Schema = {
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
    """Generate complete Crossplane output (XRD + Composition + XR + prerequisites + managed resources) from stack data.

    Phase E2 Convergence:
    - Track 1 (Curated): Emits typed Claim instances for 23 infrastructure services with hand-authored XRDs
    - Track 2 (Bridge): Wraps remaining manifests in Object resources for backward compatibility
    - Composition uses only bridge resources; managed resources are returned separately for CLI output

    Args:
        components: List of ComponentInstance from the stack
        accessories: List of AccessoryInstance from the stack
        namespaces: List of K8sNamespaceInstance from the stack
        stack_name: Human-readable stack name (e.g. 'erp-back')
        version: Stack version (e.g. '1.0.0')

    Returns:
        Dict with keys: xrd, composition, xr, prerequisites, managed_resources (curated Claims), metadata
    """
    _xr_kind = _to_xr_kind(stack_name)
    _instance_name = "${_sanitize(stack_name)}-workload"

    # Process all modules into Crossplane resources (order: namespaces → accessories → components)
    _ns_resources = _process_namespaces(namespaces, meta)
    _acc_resources_all = _process_accessories(accessories, meta)
    _comp_resources = _process_components(components, meta)

    # Separate curated (Track 1) from bridge (Track 2) resources
    _managed_resources = [
        r._resource for r in _acc_resources_all
        if r._type == "claim"
    ]
    _bridge_resources = [
        r for r in _acc_resources_all
        if r._type == "bridge"
    ]

    # Bridge resources: namespaces + bridge accessories + components
    _bridge_all_resources = _ns_resources + _bridge_resources + _comp_resources

    # Build sequencer rules from dependsOn chains (only for bridge resources)
    _sequencer_rules = _build_sequencer_rules(components, accessories, namespaces)

    {
        xrd = generate_xrd(stack_name, _xr_kind, meta)
        composition = generate_composition(_xr_kind, _bridge_all_resources, _sequencer_rules, meta)
        xr = generate_xr(_xr_kind, _instance_name, meta)
        prerequisites = generate_prerequisites(meta)
        managed_resources = _managed_resources
        metadata = {
            resourceCount = len(_bridge_all_resources)
            managedResourceCount = len(_managed_resources)
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
