"""
Acceptance fixture: SingleDatabaseModule workload.

Uses the explicit versioned database template import, a local hostPath PV, and
a small pause image so the PVC-backed Deployment can roll out in kind.
"""

import ._helpers as h
import templates.database.v1_0_0.database as database

_db = database.SingleDatabaseModule {
    name = "acceptance-db"
    namespace = "idp-acceptance-database"
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    dataPath = "/data"
    storageSize = "128Mi"
    storageClassName = ""
    createLocalPersistentVolume = True
    storageHostPath = "/tmp/idp-acceptance"
}.instance

h.render_accessory("idp-acceptance-database", _db)
