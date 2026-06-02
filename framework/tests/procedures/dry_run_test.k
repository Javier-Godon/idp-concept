"""
Dry-run procedure tests.
"""
import procedures.kcl_to_dry_run as dry
import models.modules.component as component
import models.modules.accessory as accessory
import models.modules.k8snamespace as k8snamespace
import models.manifests.renderstack as renderstack
import custom.helmfile.helmfile as hf

_test_ns = k8snamespace.K8sNamespaceInstance {
    name = "apps"
    kind = "Namespace"
    apiVersion = "v1"
    configurations = {}
    leaders = [{ name = "apps", kind = "Namespace", apiVersion = "v1" }]
    manifests = [{ apiVersion = "v1", kind = "Namespace", metadata = { name = "apps" } }]
}

_test_db = accessory.AccessoryInstance {
    name = "postgres"
    kind = "CRD"
    namespace = "data"
    configurations = {}
    asset = { version = "16.0" }
    leaders = [{ name = "postgres", kind = "StatefulSet", apiVersion = "apps/v1" }]
    manifests = [{ apiVersion = "apps/v1", kind = "StatefulSet", metadata = { name = "postgres", namespace = "data" } }]
    dependsOn = [_test_ns]
}

_test_api = component.ComponentInstance {
    name = "api"
    kind = "APPLICATION"
    namespace = "apps"
    configurations = {}
    asset = { version = "1.0.0" }
    leaders = [{ name = "api", kind = "Deployment", apiVersion = "apps/v1" }]
    manifests = [{ apiVersion = "apps/v1", kind = "Deployment", metadata = { name = "api", namespace = "apps" } }]
    dependsOn = [_test_db]
}

test_generate_dry_run_plan_core_fields = lambda {
    _stack = renderstack.RenderStack {
        instanceConfigurations = {
            appName = "acceptance-api"
            imageTag = "1.2.3"
        }
        components = [_test_api]
        accessories = [_test_db]
        k8snamespaces = [_test_ns]
        metadata = {owner = "platform", lifecycle = "production"}
    }

    _plan = dry.generate_dry_run_from_stack(_stack, "erp-back", "1.0.0")
    assert _plan.kind == "DryRunPlan"
    assert _plan.metadata.project == "erp-back"
    assert _plan.spec.mergedConfigurations.appName == "acceptance-api"
    assert _plan.spec.inventory.namespaces[0] == "apps"
    assert _plan.spec.inventory.components[0].dependsOn[0] == "CRD:data:postgres"
    assert _plan.spec.outputs.crossplane.metadata.xrKind == "XErpBack"
}

test_generate_dry_run_helmfile_projection = lambda {
    _stack = renderstack.RenderStack {
        instanceConfigurations = {}
        components = [_test_api]
        accessories = [_test_db]
        k8snamespaces = [_test_ns]
        helmfile = hf.HelmfileRenderOptions {
            chartBasePath = "./charts"
            releaseOverrides = {postgres = hf.ReleasePatch {name = "postgresql", namespace = "platform-data"}}
        }
    }

    _plan = dry.generate_dry_run_from_stack(_stack, "erp-back", "1.0.0")
    _api_release = _plan.spec.outputs.helmfile.releases[0]
    assert _api_release.name == "api"
    assert _api_release.needs[0] == "platform-data/postgresql"
}

