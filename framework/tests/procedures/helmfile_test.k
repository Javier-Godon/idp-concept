"""
kcl_to_helmfile procedure tests — TDD for Phase 2.
Tests helmfile generation from stack components and accessories.
"""
import procedures.kcl_to_helmfile as helmfile_proc
import models.modules.component as component
import models.modules.accessory as accessory
import models.modules.k8snamespace as k8snamespace

# === Test: Generate helmfile releases from stack components ===
test_helmfile_releases_from_components = lambda {
    _components = [
        component.ComponentInstance {
            name = "api"
            kind = "APPLICATION"
            namespace = "apps"
            configurations = {}
            asset = { version = "1.0.0" }
            leaders = [{ name = "api", kind = "Deployment", apiVersion = "apps/v1" }]
            manifests = [{ apiVersion = "apps/v1", kind = "Deployment", metadata = { name = "api", namespace = "apps" } }]
            dependsOn = []
        }
        component.ComponentInstance {
            name = "web"
            kind = "APPLICATION"
            namespace = "apps"
            configurations = {}
            asset = { version = "2.0.0" }
            leaders = [{ name = "web", kind = "Deployment", apiVersion = "apps/v1" }]
            manifests = [{ apiVersion = "apps/v1", kind = "Deployment", metadata = { name = "web", namespace = "apps" } }]
            dependsOn = []
        }
    ]

    _releases = helmfile_proc.generate_releases_from_components(_components, "./charts")
    assert len(_releases) == 2
    assert _releases[0].name == "api"
    assert _releases[0].namespace == "apps"
    assert _releases[0].chart == "./charts/api"
    assert _releases[1].name == "web"
    assert _releases[1].chart == "./charts/web"
}

# === Test: Generate helmfile releases from accessories ===
test_helmfile_releases_from_accessories = lambda {
    _accessories = [
        accessory.AccessoryInstance {
            name = "postgres"
            kind = "CRD"
            namespace = "data"
            configurations = {}
            asset = { version = "16.0" }
            leaders = [{ name = "postgres", kind = "Deployment", apiVersion = "apps/v1" }]
            manifests = [{ apiVersion = "apps/v1", kind = "Deployment", metadata = { name = "postgres", namespace = "data" } }]
            dependsOn = []
        }
    ]

    _releases = helmfile_proc.generate_releases_from_accessories(_accessories, "./charts")
    assert len(_releases) == 1
    assert _releases[0].name == "postgres"
    assert _releases[0].namespace == "data"
    assert _releases[0].chart == "./charts/postgres"
}

# === Test: Generate full helmfile from stack ===
test_generate_helmfile_full = lambda {
    _components = [component.ComponentInstance {
        name = "api"
        kind = "APPLICATION"
        namespace = "apps"
        configurations = {}
        asset = { version = "1.0.0" }
        leaders = [{ name = "api", kind = "Deployment", apiVersion = "apps/v1" }]
        manifests = [{ apiVersion = "apps/v1", kind = "Deployment", metadata = { name = "api", namespace = "apps" } }]
        dependsOn = []
    }]
    _accessories = [accessory.AccessoryInstance {
        name = "db"
        kind = "CRD"
        namespace = "data"
        configurations = {}
        asset = { version = "16.0" }
        leaders = [{ name = "db", kind = "Deployment", apiVersion = "apps/v1" }]
        manifests = [{ apiVersion = "apps/v1", kind = "Deployment", metadata = { name = "db", namespace = "data" } }]
        dependsOn = []
    }]

    _helmfile = helmfile_proc.generate_helmfile(_components, _accessories, "./charts")
    assert len(_helmfile.releases) == 2
    assert _helmfile.releases[0].name == "api"
    assert _helmfile.releases[1].name == "db"
}

# === Test: Empty components ===
test_helmfile_empty_components = lambda {
    _releases = helmfile_proc.generate_releases_from_components([], "./charts")
    assert len(_releases) == 0
}

# === Test: Releases have createNamespace and values path ===
test_helmfile_release_values_path = lambda {
    _components = [component.ComponentInstance {
        name = "api"
        kind = "APPLICATION"
        namespace = "apps"
        configurations = {}
        asset = { version = "1.0.0" }
        leaders = [{ name = "api", kind = "Deployment", apiVersion = "apps/v1" }]
        manifests = [{ apiVersion = "apps/v1", kind = "Deployment", metadata = { name = "api", namespace = "apps" } }]
        dependsOn = []
    }]

    _releases = helmfile_proc.generate_releases_from_components(_components, "./charts")
    assert _releases[0].createNamespace == True
    assert _releases[0].values[0] == "./charts/api/values.yaml"
}
