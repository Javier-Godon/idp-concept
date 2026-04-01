"""
Redis Cluster Template Tests.

Tests the build_redis and build_redis_cluster lambdas for the
OT-CONTAINER-KIT Redis Operator (redis.redis.opstreelabs.in).
"""
import templates.redis as rd
import runtime

# === Test: build_redis generates standalone Redis CRD ===
test_build_redis_standalone = lambda {
    _result = rd.build_redis(rd.RedisSpec {
        name = "my-redis"
        namespace = "cache"
        storageSize = "5Gi"
    })
    assert _result.apiVersion == "redis.redis.opstreelabs.in/v1beta2"
    assert _result.kind == "Redis"
    assert _result.metadata.name == "my-redis"
    assert _result.metadata.namespace == "cache"
    assert _result.spec.kubernetesConfig.image == "quay.io/opstree/redis:v7.0.12"
    assert _result.spec.storage.volumeClaimTemplate.spec.resources.requests.storage == "5Gi"
}

# === Test: build_redis with custom image ===
test_build_redis_with_image = lambda {
    _result = rd.build_redis(rd.RedisSpec {
        name = "my-redis"
        namespace = "cache"
        storageSize = "10Gi"
        image = "redis:7.2"
    })
    assert _result.spec.kubernetesConfig.image == "redis:7.2"
}

# === Test: build_redis_cluster generates RedisCluster CRD ===
test_build_redis_cluster = lambda {
    _result = rd.build_redis_cluster(rd.RedisClusterSpec {
        name = "my-redis-cluster"
        namespace = "cache"
        clusterSize = 3
        storageSize = "10Gi"
    })
    assert _result.apiVersion == "redis.redis.opstreelabs.in/v1beta2"
    assert _result.kind == "RedisCluster"
    assert _result.metadata.name == "my-redis-cluster"
    assert _result.metadata.namespace == "cache"
    assert _result.spec.clusterSize == 3
    assert _result.spec.storage.volumeClaimTemplate.spec.resources.requests.storage == "10Gi"
}

# === Test: build_redis_cluster with custom storage class ===
test_build_redis_cluster_with_storage_class = lambda {
    _result = rd.build_redis_cluster(rd.RedisClusterSpec {
        name = "my-redis-cluster"
        namespace = "cache"
        clusterSize = 3
        storageSize = "10Gi"
        storageClassName = "fast-ssd"
    })
    assert _result.spec.storage.volumeClaimTemplate.spec.storageClassName == "fast-ssd"
}

# === Test: build_redis with resources ===
test_build_redis_with_resources = lambda {
    _result = rd.build_redis(rd.RedisSpec {
        name = "my-redis"
        namespace = "cache"
        storageSize = "5Gi"
        resources = {
            requests = {cpu = "100m", memory = "128Mi"}
            limits = {cpu = "500m", memory = "256Mi"}
        }
    })
    assert _result.spec.kubernetesConfig.resources.requests.cpu == "100m"
}

# === Test: Validation — storageSize must not be empty ===
test_redis_rejects_empty_storage = lambda {
    _err = runtime.catch(lambda {
        rd.RedisSpec {
            name = "bad"
            namespace = "cache"
            storageSize = ""
        }
    })
    assert _err, "Expected validation error for empty storageSize"
}

# === Test: Validation — clusterSize must be >= 3 ===
test_redis_cluster_rejects_small_size = lambda {
    _err = runtime.catch(lambda {
        rd.RedisClusterSpec {
            name = "bad"
            namespace = "cache"
            clusterSize = 1
            storageSize = "5Gi"
        }
    })
    assert _err, "Expected validation error for clusterSize < 3"
}
