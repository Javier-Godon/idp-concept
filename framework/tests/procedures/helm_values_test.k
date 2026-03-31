"""
Helm values extraction tests — TDD for Phase 2.
Tests the extract_helm_values lambda that pulls configurable values from component manifests.
"""
import procedures.helm_values as hv
import models.modules.component as component

# === Test: Extract values from component with deployment + service ===
test_extract_values_basic = lambda {
    _comp = component.ComponentInstance {
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
                spec = {
                    $type = "ClusterIP"
                    ports = [{ port = 8080 }]
                }
            }
        ]
        dependsOn = []
    }

    _values = hv.extract_helm_values(_comp)
    assert _values.replicaCount == 2
    assert _values.image.repository == "myregistry/api"
    assert _values.image.tag == "1.0.0"
    assert _values.image.pullPolicy == "IfNotPresent"
    assert _values.service.$type == "ClusterIP"
    assert _values.service.port == 8080
    assert _values.resources.requests.cpu == "250m"
    assert _values.resources.limits.memory == "2Gi"
}

# === Test: Extract values with env vars (only direct values, not secretRefs) ===
test_extract_values_env = lambda {
    _comp = component.ComponentInstance {
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
                    replicas = 1
                    template.spec.containers = [{
                        name = "api"
                        image = "myregistry/api:1.0.0"
                        env = [
                            { name = "SPRING_PROFILES_ACTIVE", value = "dev" }
                            { name = "DB_HOST", value = "localhost" }
                            { name = "DB_PASSWORD", valueFrom = { secretKeyRef = { name = "creds", key = "pw" } } }
                        ]
                    }]
                }
            }
        ]
        dependsOn = []
    }

    _values = hv.extract_helm_values(_comp)
    # Only direct value env vars should be extracted
    assert _values.env.SPRING_PROFILES_ACTIVE == "dev"
    assert _values.env.DB_HOST == "localhost"
}

# === Test: Extract values from image without tag ===
test_extract_values_image_no_tag = lambda {
    _comp = component.ComponentInstance {
        name = "db"
        kind = "APPLICATION"
        namespace = "data"
        configurations = {}
        asset = { version = "16.4" }
        leaders = [{ name = "db", kind = "Deployment", apiVersion = "apps/v1" }]
        manifests = [
            {
                apiVersion = "apps/v1"
                kind = "Deployment"
                metadata = { name = "db", namespace = "data" }
                spec = {
                    replicas = 1
                    template.spec.containers = [{
                        name = "db"
                        image = "postgres"
                    }]
                }
            }
        ]
        dependsOn = []
    }

    _values = hv.extract_helm_values(_comp)
    assert _values.image.repository == "postgres"
    assert _values.image.tag == "latest"
}

# === Test: Extract values — no service manifest ===
test_extract_values_no_service = lambda {
    _comp = component.ComponentInstance {
        name = "worker"
        kind = "APPLICATION"
        namespace = "apps"
        configurations = {}
        asset = { version = "1.0.0" }
        leaders = [{ name = "worker", kind = "Deployment", apiVersion = "apps/v1" }]
        manifests = [
            {
                apiVersion = "apps/v1"
                kind = "Deployment"
                metadata = { name = "worker", namespace = "apps" }
                spec = {
                    replicas = 1
                    template.spec.containers = [{
                        name = "worker"
                        image = "myregistry/worker:1.0.0"
                    }]
                }
            }
        ]
        dependsOn = []
    }

    _values = hv.extract_helm_values(_comp)
    assert _values.replicaCount == 1
    assert _values.image.repository == "myregistry/worker"
    assert _values.service is Undefined
}

# === Test: Generate Chart.yaml from component ===
test_generate_chart = lambda {
    _comp = component.ComponentInstance {
        name = "erp-api"
        kind = "APPLICATION"
        namespace = "apps"
        configurations = {}
        asset = { version = "1.0.0" }
        leaders = [{ name = "erp-api", kind = "Deployment", apiVersion = "apps/v1" }]
        manifests = []
        dependsOn = []
    }

    _chart = hv.generate_chart(_comp, "1.0.0")
    assert _chart.apiVersion == "v2"
    assert _chart.name == "erp-api"
    assert _chart.version == "1.0.0"
    assert _chart.appVersion == "1.0.0"
}
