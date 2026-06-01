"""
kcl_to_helmfile procedure tests — TDD for Phase 2.
Tests helmfile generation from stack components and accessories.
"""
import procedures.kcl_to_helmfile as helmfile_proc
import models.modules.component as component
import models.modules.accessory as accessory
import models.manifests.renderstack as renderstack
import custom.helmfile.helmfile as hf

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

test_generate_helmfile_with_options = lambda {
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

    _helmfile = helmfile_proc.generate_helmfile_with_options(_components, [], hf.HelmfileRenderOptions {
        chartBasePath = "./dist/charts"
        repositories = [hf.Repository {name = "bitnami", url = "https://charts.bitnami.com/bitnami"}]
        environments = {dev = hf.Environment {values = ["environments/dev.yaml"]}}
        helmDefaults = hf.HelmDefaults {wait = True, timeout = 600, atomic = True}
        values = ["global.yaml"]
        secrets = ["secrets.yaml"]
        commonLabels = {team = "platform"}
        releaseDefaults = hf.ReleasePatch {wait = True, timeout = 300, labels = {tier = "app"}}
        releaseOverrides = {
            api = hf.ReleasePatch {
                namespace = "custom-apps"
                chart = "oci://registry.example.com/charts/api"
                version = "1.2.3"
                values = ["values/api.yaml", {replicaCount = 2}]
                needs = ["data/postgres"]
                set = [hf.SetValue {name = "image.tag", value = "1.2.3"}]
            }
        }
        extraReleases = [hf.Release {name = "metrics-server", namespace = "kube-system", chart = "bitnami/metrics-server", version = "7.2.0"}]
    })

    assert _helmfile.repositories[0].name == "bitnami"
    assert _helmfile.environments.dev.values[0] == "environments/dev.yaml"
    assert _helmfile.helmDefaults.timeout == 600
    assert _helmfile.commonLabels.team == "platform"
    assert len(_helmfile.releases) == 2
    assert _helmfile.releases[0].namespace == "custom-apps"
    assert _helmfile.releases[0].chart == "oci://registry.example.com/charts/api"
    assert _helmfile.releases[0].version == "1.2.3"
    assert _helmfile.releases[0].wait == True
    assert _helmfile.releases[0].timeout == 300
    assert _helmfile.releases[0].needs[0] == "data/postgres"
    assert _helmfile.releases[0].set[0].name == "image.tag"
    assert _helmfile.releases[1].name == "metrics-server"
}

test_generate_helmfile_from_stack_options = lambda {
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
    _stack = renderstack.RenderStack {
        instanceConfigurations = {}
        components = _components
        accessories = []
        k8snamespaces = []
        helmfile = hf.HelmfileRenderOptions {
            chartBasePath = "./custom-charts"
            namespace = "all-apps"
            releaseOverrides = {api = hf.ReleasePatch {installed = False}}
        }
    }
    _helmfile = helmfile_proc.generate_helmfile_from_stack(_stack, "./charts")
    assert _helmfile.releases[0].chart == "./custom-charts/api"
    assert _helmfile.releases[0].namespace == "all-apps"
    assert _helmfile.releases[0].installed == False
}

test_generate_helmfile_from_stack_metadata_labels = lambda {
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
    _stack = renderstack.RenderStack {
        instanceConfigurations = {}
        components = _components
        accessories = []
        k8snamespaces = []
        metadata = {
            owner = "platform-team"
            lifecycle = "production"
            sloTier = "gold"
            labels = {
                "app.kubernetes.io/managed-by" = "koncept"
                "company.io/team" = "payments"
            }
        }
        helmfile = hf.HelmfileRenderOptions {
            labels = {environment = "dev"}
            commonLabels = {"company.io/cost-center" = "CC-4821"}
        }
    }
    _helmfile = helmfile_proc.generate_helmfile_from_stack(_stack, "./charts")
    assert _helmfile.labels.owner == "platform-team"
    assert _helmfile.labels.lifecycle == "production"
    assert _helmfile.labels.sloTier == "gold"
    assert _helmfile.labels["app.kubernetes.io/managed-by"] == "koncept"
    assert _helmfile.labels["company.io/team"] == "payments"
    assert _helmfile.labels.environment == "dev"
    assert _helmfile.commonLabels["company.io/cost-center"] == "CC-4821"
    assert _helmfile.commonLabels["company.io/team"] == "payments"
    assert _helmfile.releases[0].labels.owner == "platform-team"
    assert _helmfile.releases[0].labels["app.kubernetes.io/managed-by"] == "koncept"
    assert _helmfile.releases[0].labels.environment == "dev"
}

test_generate_helmfile_extra_only = lambda {
    _helmfile = helmfile_proc.generate_helmfile_with_options([], [], hf.HelmfileRenderOptions {
        includeGeneratedReleases = False
        extraReleases = [hf.Release {name = "external-dns", namespace = "platform", chart = "external-dns/external-dns", version = "1.15.0"}]
    })
    assert len(_helmfile.releases) == 1
    assert _helmfile.releases[0].name == "external-dns"
}
