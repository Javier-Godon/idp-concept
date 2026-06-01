"""
Acceptance fixture: Helmfile generation from a WebApp + Database stack.

Exercises the full helmfile procedure path:
  template instances -> RenderStack -> kcl_to_helmfile.generate_helmfile_from_stack
  -> helmfile.yaml document output.

Validates:
- WebAppModule and SingleDatabaseModule produce correct Helmfile releases
- dependsOn relationships translate to Helmfile needs: entries
- Stack metadata (owner, lifecycle) flows into top-level labels and release labels
- Helmfile options (repositories, environments, helmDefaults) are preserved
"""

import manifests
import templates.webapp.v1_0_0.webapp as webapp
import templates.database.v1_0_0.database as database
import models.manifests.renderstack as rs
import models.metadata as meta
import custom.helmfile.helmfile as hf
import procedures.kcl_to_helmfile as helmfile_proc

_namespace = "idp-acceptance-helmfile"

_db = database.SingleDatabaseModule {
    name = "acceptance-helmfile-db"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    port = 5432
    dataPath = "/data"
    storageSize = "256Mi"
    storageClassName = ""
    createLocalPersistentVolume = False
    dependsOn = []
}.instance

# webapp depends on the database — this wires a Helmfile needs: entry so Helmfile
# deploys the database release before the webapp release.
_app = webapp.WebAppModule {
    name = "acceptance-helmfile-webapp"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "message: helmfile acceptance\n"}
    env = [{name = "DB_HOST", value = "acceptance-helmfile-db"}]
    dependsOn = [_db]
}.instance

_stack = rs.RenderStack {
    instanceConfigurations = {}
    components = [_app]
    accessories = [_db]
    k8snamespaces = []
    metadata = meta.Metadata {
        owner = "platform-team"
        team = "platform"
        lifecycle = "experimental"
        tier = "2"
    }
    helmfile = hf.HelmfileRenderOptions {
        chartBasePath = "./charts"
        includeGeneratedReleases = True
        repositories = [hf.Repository {
            name = "bitnami"
            url = "https://charts.bitnami.com/bitnami"
        }]
        environments = {
            acceptance = hf.Environment {
                values = ["environments/acceptance.yaml"]
            }
        }
        helmDefaults = hf.HelmDefaults {
            wait = True
            timeout = 600
            atomic = True
        }
        releaseDefaults = hf.ReleasePatch {
            createNamespace = True
        }
    }
}

_helmfile = helmfile_proc.generate_helmfile_from_stack(_stack)

manifests.yaml_stream([_helmfile])
