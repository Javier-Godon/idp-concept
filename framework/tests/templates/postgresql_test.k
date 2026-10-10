"""
PostgreSQL (CloudNativePG) Template Tests.

NOTE: kcl test has a known bug where schemas with auto-computed `instance` fields
(like Component/Accessory) fail when the instance references fields computed from
lambdas. See webapp_test.k for full explanation.

Workaround: Test the build_* lambdas and schema fields indirectly.
Template integration is validated via `kcl run` in the CI pipeline.
"""
import templates.postgresql.v1_0_0.postgresql as pg
import procedures.kcl_to_crossplane as crossplane_proc
import models.modules.accessory as accessory
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

# === Test: superuser secret enables superuser access in the YAML Cluster ===
test_build_cnpg_cluster_superuser_secret = lambda {
    _result = pg.build_cnpg_cluster(pg.CNPGClusterSpec {
        name = "db"
        namespace = "data"
        superuserSecretName = "db-superuser"
    })
    assert _result.spec.enableSuperuserAccess == True
    assert _result.spec.superuserSecret.name == "db-superuser"
}

# === Test: crossplane XR spec for a development single instance ===
test_cnpg_xr_spec_development = lambda {
    _xr = pg.build_cnpg_xr_spec(pg.CNPGClusterSpec {
        name = "erp-postgres"
        namespace = "erp-postgres"
        footprint = "development"
        databaseName = "blue_postgres"
        superuserSecretName = "erp-postgres-superuser"
    }, 31543)
    assert _xr.clusterName == "erp-postgres"
    assert _xr.dbName == "blue_postgres"
    assert _xr.instances == 1
    assert _xr.storageSize == "2Gi"
    assert _xr.superuserSecretName == "erp-postgres-superuser"
    assert _xr.nodePort == 31543
    assert _xr.resourceMemoryLimit == "1Gi"
    assert _xr.environment == "development"
    assert "storageClass" not in _xr
    assert "ownerUsername" not in _xr
}

# === Test: explicit resources win over footprint defaults; nodePort omitted when unset ===
test_cnpg_xr_spec_explicit_resources = lambda {
    _xr = pg.build_cnpg_xr_spec(pg.CNPGClusterSpec {
        name = "db"
        namespace = "data"
        instances = 3
        storageClass = "fast-ssd"
        imageName = "ghcr.io/cloudnative-pg/postgresql:17.9"
        resources = {requests = {cpu = "2", memory = "4Gi"}}
    })
    assert _xr.instances == 3
    assert _xr.storageClass == "fast-ssd"
    assert _xr.image == "ghcr.io/cloudnative-pg/postgresql:17.9"
    assert _xr.resourceCpuRequest == "2"
    assert _xr.resourceMemoryRequest == "4Gi"
    assert _xr.resourceCpuLimit == "2"
    assert _xr.dbName == "db"
    assert "nodePort" not in _xr
}

# === Test: NodePort Service targets the CNPG primary ===
test_cnpg_nodeport_service = lambda {
    _svc = pg.build_nodeport_service("db-nodeport", "data", "db", 30543)
    assert _svc.kind == "Service"
    assert _svc.spec["type"] == "NodePort"
    assert _svc.spec.ports[0].nodePort == 30543
    assert _svc.spec.selector["cnpg.io/cluster"] == "db"
    assert _svc.spec.selector["cnpg.io/instanceRole"] == "primary"
}

# === Test: crossplane output emits a typed XPostgresInstance from crossplaneSpec (no Object wrapping) ===
test_postgresql_crossplane_output_uses_xr_spec = lambda {
    _spec = pg.CNPGClusterSpec {
        name = "db"
        namespace = "data"
        footprint = "development"
        databaseName = "app"
    }
    _acc = accessory.AccessoryInstance {
        name = "db"
        kind = "CRD"
        namespace = "data"
        component = "postgresql"
        crossplaneSpec = pg.build_cnpg_xr_spec(_spec, 30543)
        configurations = {}
        asset = {version = "18.4"}
        leaders = []
        manifests = [pg.build_cnpg_cluster(_spec)]
        dependsOn = []
    }
    _out = crossplane_proc.generate_crossplane_from_stack([], [_acc], [], "erp", "0.1.0")
    assert len(_out.managed_resources) == 1
    _xr = _out.managed_resources[0]
    assert _xr.kind == "XPostgresInstance"
    assert _xr.spec.namespace == "data"
    assert _xr.spec.dbName == "app"
    assert _xr.spec.nodePort == 30543
    assert _out.metadata.resourceCount == 0
}
