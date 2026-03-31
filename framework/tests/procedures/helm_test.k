"""
Helm procedure tests — validates chart generation from stack structures.
Tests the kcl_to_helm module's chart generation lambdas.
TDD: Phase 2 Step 5 — kcl_to_helm expansion.
"""
import procedures.kcl_to_helm as helm_proc
import models.modules.component as component
import models.modules.accessory as accessory
import models.stack as stack

# === Helper: minimal component with deployment + service ===
_test_component = component.ComponentInstance {
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
            spec = {
                replicas = 2
                template.spec.containers = [{
                    name = "api"
                    image = "myregistry/api:1.0.0"
                    imagePullPolicy = "IfNotPresent"
                    ports = [{ containerPort = 8080 }]
                    resources = {
                        requests = { cpu = "250m", memory = "512Mi" }
                        limits = { cpu = "1", memory = "2Gi" }
                    }
                }]
            }
        }
        {
            apiVersion = "v1"
            kind = "Service"
            metadata = { name = "api", namespace = "apps" }
            spec = { $type = "ClusterIP", ports = [{ port = 8080 }] }
        }
    ]
    dependsOn = []
}

_test_accessory = accessory.AccessoryInstance {
    name = "postgres"
    kind = "CRD"
    namespace = "db"
    configurations = {}
    asset = { version = "2.0.0" }
    leaders = [{ name = "postgres", kind = "Deployment", apiVersion = "apps/v1" }]
    manifests = [
        {
            apiVersion = "apps/v1"
            kind = "Deployment"
            metadata = { name = "postgres", namespace = "db" }
            spec = {
                replicas = 1
                template.spec.containers = [{
                    name = "postgres"
                    image = "postgres:16.4-alpine"
                    ports = [{ containerPort = 5432 }]
                    resources = {
                        requests = { cpu = "100m", memory = "256Mi" }
                        limits = { cpu = "500m", memory = "1Gi" }
                    }
                }]
            }
        }
        {
            apiVersion = "v1"
            kind = "Service"
            metadata = { name = "postgres", namespace = "db" }
            spec = { $type = "ClusterIP", ports = [{ port = 5432 }] }
        }
    ]
    dependsOn = []
}

# === Test: generate_chart_data produces chart + values for a component ===
test_generate_chart_data_component = lambda {
    _result = helm_proc.generate_chart_data(_test_component)
    assert _result.chart.name == "api"
    assert _result.chart.version == "1.0.0"
    assert _result.chart.apiVersion == "v2"
    assert _result.values.replicaCount == 2
    assert _result.values.image.repository == "myregistry/api"
    assert _result.values.image.tag == "1.0.0"
    assert _result.values.service.port == 8080
}

# === Test: generate_chart_data works for accessories too ===
test_generate_chart_data_accessory = lambda {
    _result = helm_proc.generate_chart_data(_test_accessory)
    assert _result.chart.name == "postgres"
    assert _result.chart.version == "2.0.0"
    assert _result.values.replicaCount == 1
    assert _result.values.image.repository == "postgres"
    assert _result.values.image.tag == "16.4-alpine"
    assert _result.values.service.port == 5432
}

# === Test: generate_charts_from_stack produces chart data for all modules ===
test_generate_charts_from_stack = lambda {
    _test_stack = stack.Stack {
        instanceConfigurations = {}
        components = [_test_component]
        accessories = [_test_accessory]
        k8snamespaces = []
    }
    _result = helm_proc.generate_charts_from_stack(_test_stack)
    assert len(_result) == 2
    assert _result[0].chart.name == "api"
    assert _result[1].chart.name == "postgres"
}

# === Test: generate_charts_from_stack handles empty accessories ===
test_generate_charts_empty_accessories = lambda {
    _test_stack = stack.Stack {
        instanceConfigurations = {}
        components = [_test_component]
        accessories = []
        k8snamespaces = []
    }
    _result = helm_proc.generate_charts_from_stack(_test_stack)
    assert len(_result) == 1
    assert _result[0].chart.name == "api"
}

# === Test: existing get_helm_components still works (backward compat) ===
test_get_helm_components_backward_compat = lambda {
    _result = helm_proc.get_helm_components([_test_component])
    assert len(_result) == 1
    # Each element is the manifests list
    assert len(_result[0]) == 2
}
