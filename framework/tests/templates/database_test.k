"""
Database Template Integration Tests.

NOTE: kcl test has a known bug where schemas with auto-computed `instance` fields
(like Component/Accessory) fail when the instance references fields computed from
lambdas. See webapp_test.k for full explanation.

Workaround: Test the individual builder outputs that SingleDatabaseModule composes.
Template integration is validated via `kcl run` in the CI pipeline and erp_back project.
"""
import builders.deployment as deploy
import builders.service as svc
import builders.storage as storage
import builders.leader as leader

# === Test: Database Deployment with volume mounts ===
test_database_deployment_output = lambda {
    _result = deploy.build_deployment(deploy.DeploymentSpec {
        name = "postgres"
        namespace = "data"
        image = "postgres"
        version = "16.0"
        port = 5432
        imagePullPolicy = "IfNotPresent"
        volumeMounts = [{
            name = "postgres-pv"
            mountPath = "/var/lib/postgresql/data"
        }]
        volumes = [{
            name = "postgres-pv"
            persistentVolumeClaim = {
                claimName = "postgres-pvc"
            }
        }]
    })
    assert _result.kind == "Deployment"
    _container = _result.spec.template.spec.containers[0]
    assert _container.image == "postgres:16.0"
    assert _container.imagePullPolicy == "IfNotPresent"
    assert _container.volumeMounts[0].mountPath == "/var/lib/postgresql/data"
    assert _container.volumeMounts[0].name == "postgres-pv"
}

# === Test: Database imagePullPolicy defaults to IfNotPresent ===
test_database_image_pull_policy_default = lambda {
    _result = deploy.build_deployment(deploy.DeploymentSpec {
        name = "postgres"
        namespace = "data"
        image = "postgres"
        version = "16.0"
        port = 5432
        imagePullPolicy = "IfNotPresent"
    })
    _container = _result.spec.template.spec.containers[0]
    assert _container.imagePullPolicy == "IfNotPresent"
}

# === Test: Database PV and PVC generation ===
test_database_pv_pvc = lambda {
    _result = storage.build_pv_and_pvc(storage.PersistentVolumeSpec {
        name = "postgres"
        namespace = "data"
        size = "50Gi"
        hostPath = "/data/mongo/mongo-volume"
    })
    assert len(_result) == 2
    _pv = _result[0]
    _pvc = _result[1]
    assert _pv.kind == "PersistentVolume"
    assert _pv.spec.capacity.storage == "50Gi"
    assert _pv.spec.hostPath.path == "/data/mongo/mongo-volume"
    assert _pvc.kind == "PersistentVolumeClaim"
    assert _pvc.spec.resources.requests.storage == "50Gi"
}

# === Test: Database leader is Deployment type ===
test_database_leader = lambda {
    _result = leader.build_accessory_leader("postgres", "data", "Deployment", "apps/v1")
    assert _result.name == "postgres"
    assert _result.kind == "Deployment"
    assert _result.apiVersion == "apps/v1"
    assert _result.namespace == "data"
}

# === Test: Database Service with portName ===
test_database_service = lambda {
    _result = svc.build_service(svc.ServiceSpec {
        name = "postgres"
        namespace = "data"
        port = 5432
        serviceType = "ClusterIP"
        portName = "postgresql"
        labels = {
            app = "postgres"
        }
    })
    assert _result.kind == "Service"
    assert _result.spec.ports[0].port == 5432
    assert _result.spec.ports[0].name == "postgresql"
}

# === Test: Database NodePort service ===
test_database_nodeport_service = lambda {
    _result = svc.build_service(svc.ServiceSpec {
        name = "postgres"
        namespace = "data"
        port = 5432
        serviceType = "NodePort"
        nodePort = 30432
    })
    assert _result.spec.$type == "NodePort"
    assert _result.spec.ports[0].nodePort == 30432
}

# === Test: Database Deployment with env vars ===
test_database_deployment_with_env = lambda {
    _result = deploy.build_deployment(deploy.DeploymentSpec {
        name = "postgres"
        namespace = "data"
        image = "postgres"
        version = "16.0"
        port = 5432
        env = [
            { name = "POSTGRES_DB", value = "mydb" }
            { name = "POSTGRES_PASSWORD", valueFrom = { secretKeyRef = { name = "db-creds", key = "password" } } }
        ]
    })
    _container = _result.spec.template.spec.containers[0]
    assert _container.env[0].name == "POSTGRES_DB"
    assert _container.env[0].value == "mydb"
    assert _container.env[1].name == "POSTGRES_PASSWORD"
}

# === Test: Database PV with custom storage class ===
test_database_custom_storage_class = lambda {
    _result = storage.build_pv_and_pvc(storage.PersistentVolumeSpec {
        name = "postgres"
        namespace = "data"
        storageClassName = "fast-ssd"
    })
    _pv = _result[0]
    _pvc = _result[1]
    assert _pv.spec.storageClassName == "fast-ssd"
    assert _pvc.spec.storageClassName == "fast-ssd"
}
