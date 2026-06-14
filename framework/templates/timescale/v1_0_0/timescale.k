"""
Timescale Module Template — Time-series database, built on CloudNativePG (CNPG).
Generates: CloudNativePG Cluster CRD with TimescaleDB extension.

Timescale is a PostgreSQL extension that transforms PostgreSQL into a time-series database.
It is deployed as a CloudNativePG cluster with the timescaledb extension pre-loaded in initdb.

CRD API: postgresql.cnpg.io/v1 (same as PostgreSQL, but with TimescaleDB extension)
Operator: CloudNativePG (https://cloudnative-pg.io)

Dependencies: Requires CloudNativePG operator to be installed.

Usage:
    import framework.templates.timescale.v1_0_0.timescale as ts

    schema MyTimescale(ts.TimescaleDBModule):
        clusterName = "my-timescale"
        instances = 3
        storageSize = "50Gi"
        enablePodMonitor = True
"""
import models.modules.accessory as accessory
import builders.leader as leader
import templates.footprints.v1_0_0.footprint as fp

schema TimescaleDBSpec:
    """Specification for a TimescaleDB cluster (PostgreSQL with TimescaleDB extension)."""
    name: str
    namespace: str
    footprint?: str = "production"
    instances?: int
    storageSize?: str
    storageClass?: str
    walStorageSize?: str
    walStorageClass?: str
    imageName?: str = "ghcr.io/cloudnative-pg/postgresql:17.2-1"
    timescaleVersion?: str = "2.15.0"
    enableSuperuserAccess?: bool = False
    enablePDB?: bool = True
    databaseName?: str = "timescaledb"
    databaseOwner?: str = "timescale_user"
    postgresqlParameters?: {str:str}
    enablePodMonitor?: bool = False
    backupRetentionPolicy?: str
    logLevel?: str
    primaryUpdateStrategy?: str
    resources?: any

    check:
        instances >= 1 if instances is not Undefined, "instances must be >= 1"
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"
        len(storageSize) > 0 if storageSize is not Undefined, "storageSize must not be empty"
        len(timescaleVersion) > 0, "timescaleVersion must not be empty"

build_timescaledb_cluster = lambda spec: TimescaleDBSpec -> any {
    _storage_size = spec.storageSize if spec.storageSize is not Undefined else fp.storage_size(spec.footprint, "2Gi", "5Gi", "20Gi", "100Gi")
    _instances = spec.instances if spec.instances is not Undefined else fp.replicas(spec.footprint, 1, 1, 2, 3)

    # TimescaleDB init script
    _init_script = "#!/bin/bash\npsql -U postgres <<EOF\nCREATE EXTENSION IF NOT EXISTS timescaledb;\nEOF"

    _bootstrap = {
        initdb = {
            if spec.databaseName: database = spec.databaseName
            if spec.databaseOwner: owner = spec.databaseOwner
            # TimescaleDB extension setup
            postInitApplicationSQL = [
                "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;"
            ]
            postInitApplicationSQLRefs = {
                if spec.timescaleVersion:
                    configMapRef = {name = "timescale-init", key = "init-timescale.sql"}
            }
        }
    }

    _postgresql = {
        if spec.postgresqlParameters: postgresql = {
            parameters = spec.postgresqlParameters | {
                "max_locks_per_transaction" = "64"
                "shared_preload_libraries" = "timescaledb"
            }
        }
        if not spec.postgresqlParameters: postgresql = {
            parameters = {
                "max_locks_per_transaction" = "64"
                "shared_preload_libraries" = "timescaledb"
            }
        }
    }

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
        size = _storage_size
        if spec.storageClass: storageClass = spec.storageClass
    }

    _manifests = [
        {
            apiVersion = "postgresql.cnpg.io/v1"
            kind = "Cluster"
            metadata = {
                name = spec.name
                namespace = spec.namespace
                labels = {
                    "app.kubernetes.io/name" = "timescaledb"
                    "app.kubernetes.io/instance" = spec.name
                    "app.kubernetes.io/component" = "database"
                }
            }
            spec = {
                instances = _instances
                imageName = spec.imageName
                bootstrap = _bootstrap
                postgresql = _postgresql | {parameters = _postgresql.postgresql.parameters}
                storage = _storage
                if spec.walStorageSize: walStorage = _wal_storage.walStorage
                if spec.enableSuperuserAccess: superuserSecret = {name = "${spec.name}-superuser"}
                monitoring = _monitoring.monitoring if _monitoring.monitoring is not Undefined else {}
                backup = _backup.backup if _backup.backup is not Undefined else {}
                logLevel = _log_level.logLevel if _log_level.logLevel is not Undefined else "info"
                primaryUpdateStrategy = _primary_update_strategy.primaryUpdateStrategy if _primary_update_strategy.primaryUpdateStrategy is not Undefined else "unsupervised"
                if spec.enablePDB:
                    podDisruptionBudget = {
                        maxUnavailable = 1
                    }
            }
        }
    ]

    {
        instance: accessory.AccessoryInstance {
            name = spec.name
            namespace = spec.namespace
            kind = "THIRD_PARTY"
            manifests = _manifests
            leaders = [leader.build_accessory_leader(spec.name, spec.namespace, "Cluster", "postgresql.cnpg.io/v1")]
        }
        instance_manifest: _manifests
    }

schema TimescaleDBModule(accessory.Accessory):
    """
    TimescaleDB Module — Time-series database on PostgreSQL via CloudNativePG operator.

    Use this schema to define a TimescaleDB cluster in your stack.
    All manifests are auto-generated.
    """
    clusterName: str
    namespace: str
    footprint?: str = "production"
    instances?: int
    storageSize?: str
    storageClass?: str
    walStorageSize?: str
    walStorageClass?: str
    imageName?: str = "ghcr.io/cloudnative-pg/postgresql:17.2-1"
    timescaleVersion?: str = "2.15.0"
    enableSuperuserAccess?: bool = False
    enablePDB?: bool = True
    databaseName?: str = "timescaledb"
    databaseOwner?: str = "timescale_user"
    postgresqlParameters?: {str:str}
    enablePodMonitor?: bool = False
    backupRetentionPolicy?: str
    logLevel?: str
    primaryUpdateStrategy?: str
    resources?: any

    # Auto-computed
    _ts_spec = TimescaleDBSpec {
        name = clusterName
        namespace = namespace
        footprint = footprint
        instances = instances
        storageSize = storageSize
        storageClass = storageClass
        walStorageSize = walStorageSize
        walStorageClass = walStorageClass
        imageName = imageName
        timescaleVersion = timescaleVersion
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
    }

    _ts_result = build_timescaledb_cluster(_ts_spec)

    kind = "INFRASTRUCTURE"
    name = clusterName
    namespace = namespace
    configurations = _ts_spec
    asset = {version = timescaleVersion}
    manifests = _ts_result.instance_manifest
    leaders = []
    dependsOn = []

    check:
        len(clusterName) > 0, "clusterName must be non-empty"
        len(namespace) > 0, "namespace must be non-empty"

