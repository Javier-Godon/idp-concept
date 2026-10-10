"""
PostgreSQL Cluster Module Template — CloudNativePG operator pattern.
Generates: Cluster CRD + optional ScheduledBackup CRD + optional Pooler CRD.

CRD API: postgresql.cnpg.io/v1
Operator: CloudNativePG (https://cloudnative-pg.io)

Usage:
    import framework.templates.postgresql.v1_0_0.postgresql as pg

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
import templates.footprints.v1_0_0.footprint as fp
import templates.admin.v1_0_0.data_admin as admin

schema CNPGClusterSpec:
    """Specification for a CloudNativePG Cluster resource."""
    name: str
    namespace: str
    footprint?: str = "production"
    instances?: int
    storageSize?: str
    storageClass?: str
    walStorageSize?: str
    walStorageClass?: str
    imageName?: str
    enableSuperuserAccess?: bool = False
    superuserSecretName?: str
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
        instances >= 1 if instances is not Undefined, "instances must be >= 1"
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"
        len(storageSize) > 0 if storageSize is not Undefined, "storageSize must not be empty"

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
    _storage_size = spec.storageSize if spec.storageSize is not Undefined else fp.storage_size(spec.footprint, "1Gi", "2Gi", "10Gi", "50Gi")
    _instances = spec.instances if spec.instances is not Undefined else fp.replicas(spec.footprint, 1, 1, 2, 3)
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
    _superuser_secret = {if spec.superuserSecretName: superuserSecret = {name = spec.superuserSecretName}}
    _storage = {
        size = _storage_size
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
            instances = _instances
            enableSuperuserAccess = True if spec.superuserSecretName else spec.enableSuperuserAccess
            enablePDB = spec.enablePDB
            storage = _storage
        } | _superuser_secret | _bootstrap | _postgresql | _monitoring | _backup | _wal_storage | _image | _resources | _log_level | _primary_update_strategy
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

_FOOTPRINT_RESOURCES = {
    "local" = {cpuRequest = "100m", memoryRequest = "256Mi", cpuLimit = "500m", memoryLimit = "512Mi"}
    "development" = {cpuRequest = "100m", memoryRequest = "256Mi", cpuLimit = "1", memoryLimit = "1Gi"}
    "staging" = {cpuRequest = "250m", memoryRequest = "512Mi", cpuLimit = "2", memoryLimit = "2Gi"}
    "production" = {cpuRequest = "500m", memoryRequest = "1Gi", cpuLimit = "2", memoryLimit = "4Gi"}
}

build_cnpg_xr_spec = lambda spec: CNPGClusterSpec, nodePort: int = 0 -> {str:} {
    """XPostgresInstance spec (crossplane_v2/managed_resources/postgres) for the crossplane output.
    Explicit `resources` win over the footprint defaults; pooler/backup/WAL settings are not part of the curated API."""
    _res = _FOOTPRINT_RESOURCES[spec.footprint]
    _requests = spec.resources?.requests or {}
    _limits = spec.resources?.limits or {}
    {
        clusterName = spec.name
        dbName = spec.databaseName if spec.databaseName else spec.name.replace("-", "_")
        if spec.databaseOwner:
            ownerUsername = spec.databaseOwner
        instances = spec.instances if spec.instances is not Undefined else fp.replicas(spec.footprint, 1, 1, 2, 3)
        storageSize = spec.storageSize if spec.storageSize is not Undefined else fp.storage_size(spec.footprint, "1Gi", "2Gi", "10Gi", "50Gi")
        if spec.storageClass:
            storageClass = spec.storageClass
        if spec.imageName:
            image = spec.imageName
        if spec.superuserSecretName:
            superuserSecretName = spec.superuserSecretName
        if nodePort:
            nodePort = nodePort
        resourceCpuRequest = _requests.cpu or _res.cpuRequest
        resourceMemoryRequest = _requests.memory or _res.memoryRequest
        resourceCpuLimit = _limits.cpu or _res.cpuLimit
        resourceMemoryLimit = _limits.memory or _res.memoryLimit
        environment = spec.footprint
    }
}

build_nodeport_service = lambda name: str, namespace: str, clusterName: str, nodePort: int -> any {
    """NodePort Service for the CNPG primary, for development clusters reached from outside."""
    {
        apiVersion = "v1"
        kind = "Service"
        metadata = {
            name = name
            namespace = namespace
        }
        spec = {
            $type = "NodePort"
            selector = {
                "cnpg.io/cluster" = clusterName
                "cnpg.io/instanceRole" = "primary"
            }
            ports = [{
                name = "postgres"
                port = 5432
                targetPort = 5432
                nodePort = nodePort
            }]
        }
    }
}

schema PostgreSQLClusterModule(accessory.Accessory):
    """High-level template for CloudNativePG PostgreSQL clusters.

    Extends Accessory with kind="CRD" and generates Cluster + optional
    ScheduledBackup + optional Pooler CRD manifests. The crossplane output
    emits an XPostgresInstance XR instead.
    """
    kind = "CRD"
    component = "postgresql"

    # User-configurable
    footprint?: str = "production"
    clusterName: str
    instances?: int
    storageSize?: str
    storageClass?: str
    walStorageSize?: str
    walStorageClass?: str
    imageName?: str
    enableSuperuserAccess?: bool = False
    superuserSecretName?: str
    nodePort?: int
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
    pgAdmin?: admin.PgAdminSpec

    # Auto-computed
    leaders = [leader.build_accessory_leader(clusterName, namespace, "Cluster", "postgresql.cnpg.io/v1")]

    _cluster_spec = CNPGClusterSpec {
        name = clusterName
        namespace = namespace
        footprint = footprint
        instances = instances
        storageSize = storageSize
        storageClass = storageClass
        walStorageSize = walStorageSize
        walStorageClass = walStorageClass
        imageName = imageName
        enableSuperuserAccess = enableSuperuserAccess
        superuserSecretName = superuserSecretName
        enablePDB = enablePDB
        databaseName = databaseName
        databaseOwner = databaseOwner
        postgresqlParameters = postgresqlParameters
        enablePodMonitor = enablePodMonitor
        backupRetentionPolicy = backupRetentionPolicy
        logLevel = logLevel
        primaryUpdateStrategy = primaryUpdateStrategy
        resources = resources
    }
    _cluster_manifest = build_cnpg_cluster(_cluster_spec)
    crossplaneSpec = build_cnpg_xr_spec(_cluster_spec, nodePort if nodePort else 0)

    _backup_manifests = [build_scheduled_backup(scheduledBackup)] if scheduledBackup else []
    _pooler_manifests = [build_pooler(pooler)] if pooler else []
    _pgadmin_manifests = admin.build_pgadmin_resources(pgAdmin) if pgAdmin else []

    _nodeport_manifests = [build_nodeport_service("${clusterName}-nodeport", namespace, clusterName, nodePort)] if nodePort else []

    manifests = [_cluster_manifest] + _nodeport_manifests + _backup_manifests + _pooler_manifests + _pgadmin_manifests
