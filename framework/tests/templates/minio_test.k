import templates.minio as mn
import models.modules.thirdparty_helm as th

test_minio_default = lambda {
    _spec = mn.MinIOTenantSpec {
        name = "my-minio"
        namespace = "storage"
    }
    _result = mn.build_minio_tenant(_spec)
    assert _result.apiVersion == "minio.min.io/v2"
    assert _result.kind == "Tenant"
    assert _result.metadata.name == "my-minio"
    assert _result.metadata.namespace == "storage"
    assert _result.spec.pools[0].servers == 4
    assert _result.spec.pools[0].volumesPerServer == 4
    assert _result.spec.pools[0].volumeClaimTemplate.spec.resources.requests.storage == "10Gi"
    assert _result.spec.image == "minio/minio:RELEASE.2025-03-12T18-04-18Z"
    assert _result.spec.requestAutoCert == True
}

test_minio_custom_pools = lambda {
    _spec = mn.MinIOTenantSpec {
        name = "big-minio"
        namespace = "storage"
        servers = 8
        volumesPerServer = 2
        storageSize = "100Gi"
        image = "minio/minio:RELEASE.2025-01-01T00-00-00Z"
    }
    _result = mn.build_minio_tenant(_spec)
    assert _result.spec.pools[0].servers == 8
    assert _result.spec.pools[0].volumesPerServer == 2
    assert _result.spec.pools[0].volumeClaimTemplate.spec.resources.requests.storage == "100Gi"
    assert _result.spec.image == "minio/minio:RELEASE.2025-01-01T00-00-00Z"
}

test_minio_resources = lambda {
    _spec = mn.MinIOTenantSpec {
        name = "my-minio"
        namespace = "storage"
        cpuRequest = "500m"
        memoryRequest = "2Gi"
        cpuLimit = "2"
        memoryLimit = "8Gi"
    }
    _result = mn.build_minio_tenant(_spec)
    _pool = _result.spec.pools[0]
    assert _pool.resources.requests.cpu == "500m"
    assert _pool.resources.requests.memory == "2Gi"
    assert _pool.resources.limits.cpu == "2"
    assert _pool.resources.limits.memory == "8Gi"
}

test_minio_storage_class = lambda {
    _spec = mn.MinIOTenantSpec {
        name = "my-minio"
        namespace = "storage"
        storageClassName = "fast-ssd"
    }
    _result = mn.build_minio_tenant(_spec)
    assert _result.spec.pools[0].volumeClaimTemplate.spec.storageClassName == "fast-ssd"
}

test_minio_no_autocert = lambda {
    _spec = mn.MinIOTenantSpec {
        name = "my-minio"
        namespace = "storage"
        requestAutoCert = False
    }
    _result = mn.build_minio_tenant(_spec)
    assert _result.spec.requestAutoCert == False
}

test_minio_env_vars = lambda {
    _spec = mn.MinIOTenantSpec {
        name = "my-minio"
        namespace = "storage"
        env = [
            { name = "MINIO_BROWSER", value = "on" }
        ]
    }
    _result = mn.build_minio_tenant(_spec)
    assert _result.spec.env[0].name == "MINIO_BROWSER"
    assert _result.spec.env[0].value == "on"
}

test_minio_validation = lambda {
    import runtime
    _err = runtime.catch(lambda {
        mn.MinIOTenantSpec {
            name = "bad"
            namespace = "storage"
            servers = 0
        }
    })
    assert _err != Undefined, "expected check block to fail for servers=0"
}

test_minio_helm_fallback = lambda {
    _spec = mn.MinIOHelmSpec {
        name = "minio-helm"
        namespace = "storage"
        storageSize = "50Gi"
    }
    _result = mn.build_minio_helm(_spec)
    assert _result.apiVersion == "helm.toolkit.fluxcd.io/v2beta1" or _result.kind == "HelmRelease"
    assert _result.metadata.name == "minio-helm"
}
