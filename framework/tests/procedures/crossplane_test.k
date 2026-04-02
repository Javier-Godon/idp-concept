"""
Crossplane procedure tests — validates XRD, Composition, XR, and prerequisite generation
from stack structures. Tests resource wrapping, sequencer rule generation, and naming.
"""
import procedures.kcl_to_crossplane as xp
import models.modules.component as component
import models.modules.accessory as accessory
import models.modules.k8snamespace as k8snamespace

# --- Test Helpers ---

_xp_mk_component = lambda name: str, ns: str, deps: [any] -> component.ComponentInstance {
    component.ComponentInstance {
        name = name
        kind = "APPLICATION"
        namespace = ns
        configurations = {}
        asset = { version = "1.0.0" }
        leaders = [{ name = name, kind = "Deployment", apiVersion = "apps/v1", namespace = ns }]
        manifests = [
            { apiVersion = "apps/v1", kind = "Deployment", metadata = { name = name, namespace = ns }, spec = { replicas = 1 } }
            { apiVersion = "v1", kind = "Service", metadata = { name = name, namespace = ns }, spec = { ports = [{ port = 8080 }] } }
        ]
        dependsOn = deps
    }
}

_xp_mk_accessory = lambda name: str, ns: str, deps: [any] -> accessory.AccessoryInstance {
    accessory.AccessoryInstance {
        name = name
        kind = "CRD"
        namespace = ns
        configurations = {}
        asset = { version = "16.0" }
        leaders = [{ name = name, kind = "StatefulSet", apiVersion = "apps/v1", namespace = ns }]
        manifests = [
            { apiVersion = "apps/v1", kind = "StatefulSet", metadata = { name = name, namespace = ns }, spec = { replicas = 1 } }
        ]
        dependsOn = deps
    }
}

_xp_mk_namespace = lambda name: str -> k8snamespace.K8sNamespaceInstance {
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

# === Test: _to_xr_kind ===
test_xr_kind_simple = lambda {
    _result = xp._to_xr_kind("erp-back")
    assert _result == "XErpBack", "Expected XErpBack, got ${_result}"
}

test_xr_kind_underscore = lambda {
    _result = xp._to_xr_kind("video_streaming")
    assert _result == "XVideoStreaming", "Expected XVideoStreaming, got ${_result}"
}

test_xr_kind_single_word = lambda {
    _result = xp._to_xr_kind("pokedex")
    assert _result == "XPokedex", "Expected XPokedex, got ${_result}"
}

# === Test: generate_xrd ===
test_xrd_structure = lambda {
    _result = xp.generate_xrd("my-stack", "XMyStack")
    assert _result.apiVersion == "apiextensions.crossplane.io/v2"
    assert _result.kind == "CompositeResourceDefinition"
    assert _result.metadata.name == "xmystacks.koncept.bluesolution.es"
    assert _result.spec.group == "koncept.bluesolution.es"
    assert _result.spec.names.kind == "XMyStack"
    assert _result.spec.names.plural == "xmystacks"
}

test_xrd_has_claim_names = lambda {
    _result = xp.generate_xrd("erp-back", "XErpBack")
    assert _result.spec.claimNames.plural == "erp-backs"
}

test_xrd_has_version = lambda {
    _result = xp.generate_xrd("test", "XTest")
    assert _result.spec.versions[0].name == "v1alpha1"
    assert _result.spec.versions[0].served == True
    assert _result.spec.versions[0].referenceable == True
}

# === Test: generate_composition with empty resources ===
test_composition_empty = lambda {
    _result = xp.generate_composition("XTest", [], [])
    assert _result.apiVersion == "apiextensions.crossplane.io/v1"
    assert _result.kind == "Composition"
    assert _result.metadata.name == "xtest-composition"
    assert _result.spec.compositeTypeRef.kind == "XTest"
    assert _result.spec.mode == "Pipeline"
    # Should have 2 steps: render-manifests + auto-ready (no sequencer with empty rules)
    assert len(_result.spec.pipeline) == 2
    assert _result.spec.pipeline[0].step == "render-manifests"
    assert _result.spec.pipeline[1].step == "automatically-detect-readiness"
}

test_composition_with_sequencer = lambda {
    _resources = [{ name = "ns-apps", base = {} }]
    _rules = [{ sequence = ["ns-apps", "comp-api-.*"] }]
    _result = xp.generate_composition("XTest", _resources, _rules)
    # Should have 3 steps: render + sequencer + auto-ready
    assert len(_result.spec.pipeline) == 3
    assert _result.spec.pipeline[0].step == "render-manifests"
    assert _result.spec.pipeline[1].step == "sequence-creation"
    assert _result.spec.pipeline[2].step == "automatically-detect-readiness"
}

test_composition_sequencer_rules = lambda {
    _rules = [{ sequence = ["ns-apps", "comp-api-.*"] }]
    _result = xp.generate_composition("XTest", [], _rules)
    _sequencer = _result.spec.pipeline[1]
    assert _sequencer.input.apiVersion == "sequencer.fn.crossplane.io/v1beta1"
    assert _sequencer.input.kind == "Input"
    assert len(_sequencer.input.rules) == 1
}

# === Test: generate_xr ===
test_xr_instance = lambda {
    _result = xp.generate_xr("XMyStack", "my-stack-workload")
    assert _result.apiVersion == "koncept.bluesolution.es/v1alpha1"
    assert _result.kind == "XMyStack"
    assert _result.metadata.name == "my-stack-workload"
    assert _result.spec.id == "my-stack-workload"
}

# === Test: generate_prerequisites ===
test_prerequisites_count = lambda {
    _result = xp.generate_prerequisites()
    # 2 providers + 2 provider configs + 3 functions = 7
    assert len(_result) == 7
}

test_prerequisites_providers = lambda {
    _result = xp.generate_prerequisites()
    _providers = [r for r in _result if r.kind == "Provider"]
    assert len(_providers) == 2
    _provider_names = [p.metadata.name for p in _providers]
    assert "provider-kubernetes" in _provider_names
    assert "provider-helm" in _provider_names
}

test_prerequisites_functions = lambda {
    _result = xp.generate_prerequisites()
    _functions = [r for r in _result if r.kind == "Function"]
    assert len(_functions) == 3
    _func_names = [f.metadata.name for f in _functions]
    assert "function-patch-and-transform" in _func_names
    assert "function-sequencer" in _func_names
    assert "function-auto-ready" in _func_names
}

# === Test: process namespaces wrapping ===
test_namespace_wrapping = lambda {
    _ns = _xp_mk_namespace("apps")
    _result = xp._process_namespaces([_ns])
    assert len(_result) == 1
    assert _result[0].name == "ns-apps"
    assert _result[0].base.kind == "Object"
    assert _result[0].base.apiVersion == "kubernetes.crossplane.io/v1alpha2"
    assert _result[0].base.spec.providerConfigRef.name == "provider-kubernetes"
    assert _result[0].base.spec.forProvider.manifest.kind == "Namespace"
}

# === Test: process components wrapping ===
test_component_wrapping = lambda {
    _comp = _xp_mk_component("api", "apps", [])
    _result = xp._process_components([_comp])
    # Component has 2 manifests (Deployment + Service)
    assert len(_result) == 2
    assert _result[0].name == "comp-api-deployment-api"
    assert _result[1].name == "comp-api-service-api"
    assert _result[0].base.spec.forProvider.manifest.kind == "Deployment"
    assert _result[1].base.spec.forProvider.manifest.kind == "Service"
}

# === Test: process accessories wrapping ===
test_accessory_wrapping = lambda {
    _acc = _xp_mk_accessory("postgres", "data", [])
    _result = xp._process_accessories([_acc])
    assert len(_result) == 1
    assert _result[0].name == "acc-postgres-statefulset-postgres"
    assert _result[0].base.spec.forProvider.manifest.kind == "StatefulSet"
}

# === Test: sequencer rules from dependsOn ===
test_sequencer_no_deps = lambda {
    _comp = _xp_mk_component("api", "apps", [])
    _result = xp._build_sequencer_rules([_comp], [])
    assert len(_result) == 0
}

test_sequencer_namespace_dep = lambda {
    _ns = _xp_mk_namespace("apps")
    _comp = _xp_mk_component("api", "apps", [_ns])
    _result = xp._build_sequencer_rules([_comp], [])
    assert len(_result) == 1
    assert _result[0].sequence[0] == "apps"
    assert _result[0].sequence[1] == "comp-api-.*"
}

test_sequencer_accessory_dep = lambda {
    _ns = _xp_mk_namespace("data")
    _acc = _xp_mk_accessory("postgres", "data", [_ns])
    _comp = _xp_mk_component("api", "apps", [_acc])
    _result = xp._build_sequencer_rules([_comp], [_acc])
    # comp depends on acc, acc depends on ns
    assert len(_result) == 2
}

test_sequencer_component_dep_pattern = lambda {
    _ns = _xp_mk_namespace("apps")
    _acc = _xp_mk_accessory("postgres", "data", [_ns])
    _comp = _xp_mk_component("api", "apps", [_acc])
    _result = xp._build_sequencer_rules([_comp], [_acc])
    # Find the rule where comp depends on acc
    _comp_rule = [r for r in _result if r.sequence[1] == "comp-api-.*"][0]
    assert _comp_rule.sequence[0] == "acc-postgres-.*"
}

# === Test: full generate_crossplane_from_stack ===
test_full_stack_simple = lambda {
    _ns = _xp_mk_namespace("apps")
    _comp = _xp_mk_component("api", "apps", [_ns])
    _result = xp.generate_crossplane_from_stack([_comp], [], [_ns], "my-app", "1.0.0")
    assert _result.metadata.resourceCount == 3  # 1 ns + 2 comp manifests
    assert _result.metadata.sequencerRules == 1  # comp depends on ns
    assert _result.metadata.xrKind == "XMyApp"
    assert _result.xrd.kind == "CompositeResourceDefinition"
    assert _result.composition.kind == "Composition"
    assert _result.xr.kind == "XMyApp"
}

test_full_stack_with_deps = lambda {
    _ns = _xp_mk_namespace("data")
    _acc = _xp_mk_accessory("postgres", "data", [_ns])
    _comp = _xp_mk_component("api", "apps", [_acc])
    _result = xp.generate_crossplane_from_stack([_comp], [_acc], [_ns], "erp-back", "2.0.0")
    # 1 ns + 1 acc + 2 comp = 4 resources
    assert _result.metadata.resourceCount == 4
    # comp→acc, acc→ns = 2 rules
    assert _result.metadata.sequencerRules == 2
    assert _result.metadata.xrKind == "XErpBack"
    # Composition should have 3 pipeline steps (with sequencer)
    assert len(_result.composition.spec.pipeline) == 3
}

test_full_stack_empty = lambda {
    _result = xp.generate_crossplane_from_stack([], [], [], "empty", "0.1.0")
    assert _result.metadata.resourceCount == 0
    assert _result.metadata.sequencerRules == 0
    assert _result.metadata.version == "0.1.0"
}

test_full_stack_resource_ordering = lambda {
    _ns = _xp_mk_namespace("apps")
    _acc = _xp_mk_accessory("db", "apps", [])
    _comp = _xp_mk_component("web", "apps", [])
    _result = xp.generate_crossplane_from_stack([_comp], [_acc], [_ns], "test", "1.0.0")
    _resources = _result.composition.spec.pipeline[0].input.resources
    # Order should be: namespaces first, then accessories, then components
    assert _resources[0].name == "ns-apps"
    assert _resources[1].name == "acc-db-statefulset-db"
    assert _resources[2].name == "comp-web-deployment-web"
}

test_prerequisites_pinned_versions = lambda {
    _result = xp.generate_prerequisites()
    _k8s_provider = [r for r in _result if r.kind == "Provider" and r.metadata.name == "provider-kubernetes"][0]
    assert _k8s_provider.spec.package == "xpkg.upbound.io/upbound/provider-kubernetes:v1"
    _helm_provider = [r for r in _result if r.kind == "Provider" and r.metadata.name == "provider-helm"][0]
    assert _helm_provider.spec.package == "xpkg.upbound.io/upbound/provider-helm:v1"
}
