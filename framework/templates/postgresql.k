"""
PostgreSQL Cluster Module Template — CloudNativePG operator pattern.
Generates: Cluster CRD + optional ScheduledBackup CRD + optional Pooler CRD.

CRD API: postgresql.cnpg.io/v1
Operator: CloudNativePG (https://cloudnative-pg.io)

Usage:
    import framework.templates.postgresql as pg

    schema MyPostgres(pg.PostgreSQLClusterModule):
        clusterName = "my-pg"
        instances = 3
        storageSize = "10Gi"
        databaseName = "myapp"
        databaseOwner = "myapp_user"
        enablePodMonitor = True
        scheduledBackup = pg.CNPGScheduledBackupSpec {
            name = "my-pg-backup"
            namespace = "data"
            clusterName = "my-pg"
            schedule = "0 0 2 * * *"
        }
"""
import models.modules.accessory as accessory
import builders.leader as leader

schema CNPGClusterSpec:
    """Specification for a CloudNativePG Cluster resource."""
    name: str
    namespace: str
    instances: int = 3
    storageSize: str
    storageClass?: str
    walStorageSize?: str
    walStorageClass?: str
    imageName?: str
    enableSuperuserAccess?: bool = False
    enablePDB?: bool = True
    databaseName?: str
    databaseOwner?: str
    postgresqlParameters?: {str:str}
    enablePodMonitor?: bool
    backupRetentionPolicy?: str
    logLevel?: str
    primaryUpdateStrategy?: str
    resources?: any

    check:
        instances >= 1, "instances must be >= 1"
        len(storageSize) > 0, "storageSize must not be empty"

schema CNPGScheduledBackupSpec:
    """Specification for a CloudNativePG ScheduledBackup resource."""
    name: str
    namespace: str
    clusterName: str
    schedule: str
    immediate?: bool = True
    backupOwnerReference?: str = "cluster"
    method?: str = "barmanObjectStore"
    suspend?: bool = False

schema CNPGPoolerSpec:
    """Specification for a CloudNativePG Pooler (PgBouncer) resource."""
    name: str
    namespace: str
    clusterName: str
    instances?: int = 1
    poolMode?: str = "session"
    poolerType?: str = "rw"
    parameters?: {str:str}

build_cnpg_cluster = lambda spec: CNPGClusterSpec -> any {
    _bootstrap = {if spec.databaseName or spec.databaseOwner: bootstrap = {initdb = {
        if spec.databaseName: database = spec.databaseName
        if spec.databaseOwner: owner = spec.databaseOwner
    }}}
    _postgresql = {if spec.postgresqlParameters: postgresql = {parameters = spec.postgresqlParameters}}
    _monitoring = {if spec.enablePodMonitor != None: monitoring = {enablePodMonitor = spec.enablePodMonitor}}
    _backup = {if spec.backupRetentionPolicy: backup = {retentionPolicy = spec.backupRetentionPolicy}}
    _wal_storage = {if spec.walStorageSize: walStorage = {
        size = spec.walStorageSize
        if spec.walStorageClass: storageClass = spec.walStorageClass
    }}
    _image = {if spec.imageName: imageName = spec.imageName}
    _resources = {if spec.resources: resources = spec.resources}
    _log_level = {if spec.logLevel: logLevel = spec.logLevel}
    _primary_update_strategy = {if spec.primaryUpdateStrategy: primaryUpdateStrategy = spec.primaryUpdateStrategy}
    _storage = {
        size = spec.storageSize
        if spec.storageClass: storageClass = spec.storageClass
    }
    {
        apiVersion = "postgresql.cnpg.io/v1"
        kind = "Cluster"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            instances = spec.instances
            enableSuperuserAccess = spec.enableSuperuserAccess
            enablePDB = spec.enablePDB
            storage = _storage
        } | _bootstrap | _postgresql | _monitoring | _backup | _wal_storage | _image | _resources | _log_level | _primary_update_strategy
    }
}

build_scheduled_backup = lambda spec: CNPGScheduledBackupSpec -> any {
    {
        apiVersion = "postgresql.cnpg.io/v1"
        kind = "ScheduledBackup"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            cluster = {name = spec.clusterName}
            schedule = spec.schedule
            immediate = spec.immediate
            backupOwnerReference = spec.backupOwnerReference
            method = spec.method
            suspend = spec.suspend
        }
    }
}

build_pooler = lambda spec: CNPGPoolerSpec -> any {
    _params = {if spec.parameters: parameters = spec.parameters}
    {
        apiVersion = "postgresql.cnpg.io/v1"
        kind = "Pooler"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            cluster = {name = spec.clusterName}
            instances = spec.instances
            $type = spec.poolerType
            pgbouncer = {
                poolMode = spec.poolMode
            } | _params
        }
    }
}

schema PostgreSQLClusterModule(accessory.Accessory):
    """High-level template for CloudNativePG PostgreSQL clusters.

    Extends Accessory with kind="CRD" and generates Cluster + optional
    ScheduledBackup + optional Pooler CRD manifests.
    """
    kind = "CRD"

    # User-configurable
    clusterName: str
    instances?: int = 3
    storageSize: str
    storageClass?: str
    walStorageSize?: str
    walStorageClass?: str
    imageName?: str
    enableSuperuserAccess?: bool = False
    enablePDB?: bool = True
    databaseName?: str
    databaseOwner?: str
    postgresqlParameters?: {str:str}
    enablePodMonitor?: bool
    backupRetentionPolicy?: str
    logLevel?: str
    primaryUpdateStrategy?: str
    resources?: any
    scheduledBackup?: CNPGScheduledBackupSpec
    pooler?: CNPGPoolerSpec

    # Auto-computed
    leaders = [leader.build_accessory_leader(clusterName, namespace, "Cluster", "postgresql.cnpg.io/v1")]

    _cluster_manifest = build_cnpg_cluster(CNPGClusterSpec {
        name = clusterName
        namespace = namespace
        instances = instances
        storageSize = storageSize
        storageClass = storageClass
        walStorageSize = walStorageSize
        walStorageClass = walStorageClass
        imageName = imageName
        enableSuperuserAccess = enableSuperuserAccess
        enablePDB = enablePDB
        databaseName = databaseName
        databaseOwner = databaseOwner
        postgresqlParameters = postgresqlParameters
        enablePodMonitor = enablePodMonitor
        backupRetentionPolicy = backupRetentionPolicy
        logLevel = logLevel
        primaryUpdateStrategy = primaryUpdateStrategy
        resources = resources
    })

    _backup_manifests = [build_scheduled_backup(scheduledBackup)] if scheduledBackup else []
    _pooler_manifests = [build_pooler(pooler)] if pooler else []

    manifests = [_cluster_manifest] + _backup_manifests + _pooler_manifests
