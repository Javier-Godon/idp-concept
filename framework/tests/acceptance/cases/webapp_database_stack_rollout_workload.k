"""
Runtime rollout fixture: WebAppModule + SingleDatabaseModule co-deployed in one stack.

This is the primary "mixture" rollout test. Both modules are rendered through a
single RenderStack via render_stack, exercising the full multi-component IDP
stack path with two simultaneous Deployments in the same namespace.

The webapp Deployment and database Deployment both use the pause image and must
roll out cleanly. The database PVC binds using a local hostPath PV so no
external storage provisioner is required.

Covers:
- Multi-module IDP stack assembled via render_stack
- Two Deployments in the same namespace rolling out simultaneously
- PVC/PV binding from SingleDatabaseModule under rollout
- Cross-module env-var wiring (webapp sets DB_HOST pointing at database Service)
"""

import ._helpers as h
import templates.webapp as webapp
import templates.database as database

_namespace = "idp-acceptance-stack-rollout"

_app = webapp.WebAppModule {
    name = "acceptance-stack-webapp"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "message: stack-rollout acceptance\n"}
    env = [{name = "DB_HOST", value = "acceptance-stack-db"}]
}.instance

_db = database.SingleDatabaseModule {
    name = "acceptance-stack-db"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 5432
    dataPath = "/data"
    storageSize = "128Mi"
    storageClassName = ""
    createLocalPersistentVolume = True
    storageHostPath = "/tmp/idp-acceptance"
}.instance

h.render_stack([_namespace], [_app], [_db])

