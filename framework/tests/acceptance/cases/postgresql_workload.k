"""
Acceptance fixture: PostgreSQLClusterModule through the IDP render path.
"""

import ._helpers as h
import templates.postgresql.v1_0_0.postgresql as pg

_module = pg.PostgreSQLClusterModule {
    name = "acceptance-postgresql"
    namespace = "idp-acceptance-postgresql"
    configurations = {}
    asset = {version = "16.4"}
    dependsOn = []
    clusterName = "acceptance-postgresql"
    instances = 1
    storageSize = "1Gi"
    databaseName = "acceptance"
    databaseOwner = "acceptance"
    scheduledBackup = pg.CNPGScheduledBackupSpec {
        name = "acceptance-postgresql-backup"
        namespace = "idp-acceptance-postgresql"
        clusterName = "acceptance-postgresql"
        schedule = "0 0 2 * * *"
        suspend = True
    }
    pooler = pg.CNPGPoolerSpec {
        name = "acceptance-postgresql-pooler"
        namespace = "idp-acceptance-postgresql"
        clusterName = "acceptance-postgresql"
        instances = 1
    }
}.instance

h.render_accessory("idp-acceptance-postgresql", _module)

