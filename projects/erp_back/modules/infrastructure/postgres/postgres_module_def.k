"""
PostgreSQL Module — CloudNativePG operator-based PostgreSQL cluster.
Uses framework PostgreSQLClusterModule for production-ready primitives.
"""
import framework.templates.postgresql as postgresql

schema PostgresModule(postgresql.PostgreSQLClusterModule):
    clusterName = name
    instances = 3
    storageSize = "20Gi"
    storageClass = Undefined
    databaseName = configurations.postgresDatabase if configurations.postgresDatabase else "erp_db"
    databaseOwner = "erp_app"
    enablePodMonitor = True
    backupRetentionPolicy = "7d"
    primaryUpdateStrategy = "unsupervised"
    imageName = "${asset.image}:${asset.version}" if asset.image and asset.version else Undefined

    resources = {
        requests = {
            cpu = "500m"
            memory = "1Gi"
        }
        limits = {
            cpu = "2"
            memory = "4Gi"
        }
    }

    scheduledBackup = postgresql.CNPGScheduledBackupSpec {
        name = "${name}-daily-backup"
        namespace = namespace
        clusterName = name
        schedule = "0 0 2 * * *"
    }

    pooler = postgresql.CNPGPoolerSpec {
        name = "${name}-rw"
        namespace = namespace
        clusterName = name
        instances = 2
        poolMode = "session"
        poolerType = "rw"
    }
