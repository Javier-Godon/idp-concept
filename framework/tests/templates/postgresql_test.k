"""
PostgreSQL (CloudNativePG) Template Tests.

NOTE: kcl test has a known bug where schemas with auto-computed `instance` fields
(like Component/Accessory) fail when the instance references fields computed from
lambdas. See webapp_test.k for full explanation.

Workaround: Test the build_* lambdas and schema fields indirectly.
Template integration is validated via `kcl run` in the CI pipeline.
"""
import templates.postgresql as pg
import runtime

# === Test: build_cnpg_cluster generates correct Cluster CRD ===
test_build_cnpg_cluster_basic = lambda {
    _result = pg.build_cnpg_cluster(pg.CNPGClusterSpec {
        name = "my-pg"
        namespace = "data"
        instances = 3
        storageSize = "10Gi"
    })
    assert _result.apiVersion == "postgresql.cnpg.io/v1"
    assert _result.kind == "Cluster"
    assert _result.metadata.name == "my-pg"
    assert _result.metadata.namespace == "data"
    assert _result.spec.instances == 3
    assert _result.spec.storage.size == "10Gi"
}

# === Test: Cluster with imageName ===
test_build_cnpg_cluster_with_image = lambda {
    _result = pg.build_cnpg_cluster(pg.CNPGClusterSpec {
        name = "my-pg"
        namespace = "data"
        instances = 2
        storageSize = "20Gi"
        imageName = "ghcr.io/cloudnative-pg/postgresql:16.4"
    })
    assert _result.spec.imageName == "ghcr.io/cloudnative-pg/postgresql:16.4"
}

# === Test: Cluster with postgresql parameters ===
test_build_cnpg_cluster_with_pg_params = lambda {
    _result = pg.build_cnpg_cluster(pg.CNPGClusterSpec {
        name = "my-pg"
        namespace = "data"
        instances = 1
        storageSize = "5Gi"
        postgresqlParameters = {
            "shared_buffers" = "256MB"
            "max_connections" = "100"
        }
    })
    assert _result.spec.postgresql.parameters["shared_buffers"] == "256MB"
    assert _result.spec.postgresql.parameters["max_connections"] == "100"
}

# === Test: Cluster with monitoring enabled ===
test_build_cnpg_cluster_with_monitoring = lambda {
    _result = pg.build_cnpg_cluster(pg.CNPGClusterSpec {
        name = "my-pg"
        namespace = "data"
        instances = 1
        storageSize = "5Gi"
        enablePodMonitor = True
    })
    assert _result.spec.monitoring.enablePodMonitor == True
}

# === Test: Cluster with backup configuration ===
test_build_cnpg_cluster_with_backup = lambda {
    _result = pg.build_cnpg_cluster(pg.CNPGClusterSpec {
        name = "my-pg"
        namespace = "data"
        instances = 1
        storageSize = "5Gi"
        backupRetentionPolicy = "30d"
    })
    assert _result.spec.backup.retentionPolicy == "30d"
}

# === Test: Cluster defaults — enableSuperuserAccess false, enablePDB true ===
test_build_cnpg_cluster_defaults = lambda {
    _result = pg.build_cnpg_cluster(pg.CNPGClusterSpec {
        name = "my-pg"
        namespace = "data"
        instances = 1
        storageSize = "5Gi"
    })
    assert _result.spec.enableSuperuserAccess == False
    assert _result.spec.enablePDB == True
    # Default: no imageName, no postgresql, no monitoring, no backup
}

# === Test: Cluster with WAL storage ===
test_build_cnpg_cluster_with_wal_storage = lambda {
    _result = pg.build_cnpg_cluster(pg.CNPGClusterSpec {
        name = "my-pg"
        namespace = "data"
        instances = 3
        storageSize = "10Gi"
        walStorageSize = "2Gi"
    })
    assert _result.spec.walStorage.size == "2Gi"
}

# === Test: Cluster with bootstrap database/owner ===
test_build_cnpg_cluster_with_bootstrap = lambda {
    _result = pg.build_cnpg_cluster(pg.CNPGClusterSpec {
        name = "my-pg"
        namespace = "data"
        instances = 1
        storageSize = "5Gi"
        databaseName = "myapp"
        databaseOwner = "myapp_user"
    })
    assert _result.spec.bootstrap.initdb.database == "myapp"
    assert _result.spec.bootstrap.initdb.owner == "myapp_user"
}

# === Test: build_scheduled_backup generates ScheduledBackup CRD ===
test_build_scheduled_backup = lambda {
    _result = pg.build_scheduled_backup(pg.CNPGScheduledBackupSpec {
        name = "my-pg-backup"
        namespace = "data"
        clusterName = "my-pg"
        schedule = "0 0 2 * * *"
    })
    assert _result.apiVersion == "postgresql.cnpg.io/v1"
    assert _result.kind == "ScheduledBackup"
    assert _result.metadata.name == "my-pg-backup"
    assert _result.metadata.namespace == "data"
    assert _result.spec.cluster.name == "my-pg"
    assert _result.spec.schedule == "0 0 2 * * *"
    assert _result.spec.backupOwnerReference == "cluster"
    assert _result.spec.immediate == True
}

# === Test: build_pooler generates Pooler CRD ===
test_build_pooler = lambda {
    _result = pg.build_pooler(pg.CNPGPoolerSpec {
        name = "my-pg-pooler"
        namespace = "data"
        clusterName = "my-pg"
        instances = 2
    })
    assert _result.apiVersion == "postgresql.cnpg.io/v1"
    assert _result.kind == "Pooler"
    assert _result.metadata.name == "my-pg-pooler"
    assert _result.metadata.namespace == "data"
    assert _result.spec.cluster.name == "my-pg"
    assert _result.spec.instances == 2
    assert _result.spec.pgbouncer.poolMode == "session"
    assert _result.spec.$type == "rw"
}

# === Test: Validation — instances must be >= 1 ===
test_cnpg_cluster_spec_rejects_zero_instances = lambda {
    _err = runtime.catch(lambda {
        pg.CNPGClusterSpec {
            name = "bad"
            namespace = "data"
            instances = 0
            storageSize = "5Gi"
        }
    })
    assert _err, "Expected validation error for instances=0"
}

# === Test: Validation — storageSize must not be empty ===
test_cnpg_cluster_spec_rejects_empty_storage = lambda {
    _err = runtime.catch(lambda {
        pg.CNPGClusterSpec {
            name = "bad"
            namespace = "data"
            instances = 1
            storageSize = ""
        }
    })
    assert _err, "Expected validation error for empty storageSize"
}
