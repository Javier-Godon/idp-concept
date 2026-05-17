"""
Redis Module Template — OT-CONTAINER-KIT Redis Operator pattern.
Generates: Redis (standalone) or RedisCluster CRD manifests.

CRD API: redis.redis.opstreelabs.in/v1beta2
Operator: OT-CONTAINER-KIT Redis Operator (https://github.com/OT-CONTAINER-KIT/redis-operator)

Usage:
    import framework.templates.redis as rd

    # Standalone Redis
    schema MyRedis(rd.RedisModule):
        redisName = "my-redis"
        storageSize = "5Gi"

    # Redis Cluster (3+ nodes)
    schema MyRedisCluster(rd.RedisClusterModule):
        clusterName = "my-redis-cluster"
        clusterSize = 3
        storageSize = "10Gi"
"""
import models.modules.accessory as accessory
import builders.leader as leader

_API_VERSION = "redis.redis.opstreelabs.in/v1beta2"
_DEFAULT_IMAGE = "quay.io/opstree/redis:v7.0.12"

schema RedisSpec:
    """Specification for a standalone Redis resource."""
    name: str
    namespace: str
    storageSize: str
    storageClassName?: str
    image?: str = _DEFAULT_IMAGE
    resources?: any

    check:
        len(storageSize) > 0, "storageSize must not be empty"

schema RedisClusterSpec:
    """Specification for a RedisCluster resource."""
    name: str
    namespace: str
    clusterSize: int = 3
    storageSize: str
    storageClassName?: str
    image?: str = _DEFAULT_IMAGE
    resources?: any

    check:
        clusterSize >= 3, "clusterSize must be >= 3"
        len(storageSize) > 0, "storageSize must not be empty"

_build_storage = lambda storageSize: str, storageClassName: str = None -> any {
    _sc = {if storageClassName: storageClassName = storageClassName}
    {
        volumeClaimTemplate = {
            spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {requests = {storage = storageSize}}
            } | _sc
        }
    }
}

build_redis = lambda spec: RedisSpec -> any {
    _resources = {if spec.resources: resources = spec.resources}
    {
        apiVersion = _API_VERSION
        kind = "Redis"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            kubernetesConfig = {
                image = spec.image
            } | _resources
            storage = _build_storage(spec.storageSize, spec.storageClassName)
        }
    }
}

build_redis_cluster = lambda spec: RedisClusterSpec -> any {
    _resources = {if spec.resources: resources = spec.resources}
    {
        apiVersion = _API_VERSION
        kind = "RedisCluster"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            clusterSize = spec.clusterSize
            kubernetesConfig = {
                image = spec.image
            } | _resources
            storage = _build_storage(spec.storageSize, spec.storageClassName)
        }
    }
}

schema RedisModule(accessory.Accessory):
    """Template for standalone Redis instances via the Redis Operator."""
    kind = "CRD"

    redisName: str
    storageSize: str
    storageClassName?: str
    image?: str = _DEFAULT_IMAGE
    resources?: any

    leaders = [leader.build_accessory_leader(redisName, namespace, "Redis", _API_VERSION)]

    _redis_manifest = build_redis(RedisSpec {
        name = redisName
        namespace = namespace
        storageSize = storageSize
        storageClassName = storageClassName
        image = image
        resources = resources
    })

    manifests = [_redis_manifest]

schema RedisClusterModule(accessory.Accessory):
    """Template for Redis Cluster instances via the Redis Operator."""
    kind = "CRD"

    clusterName: str
    clusterSize?: int = 3
    storageSize: str
    storageClassName?: str
    image?: str = _DEFAULT_IMAGE
    resources?: any

    leaders = [leader.build_accessory_leader(clusterName, namespace, "RedisCluster", _API_VERSION)]

    _cluster_manifest = build_redis_cluster(RedisClusterSpec {
        name = clusterName
        namespace = namespace
        clusterSize = clusterSize
        storageSize = storageSize
        storageClassName = storageClassName
        image = image
        resources = resources
    })

    manifests = [_cluster_manifest]
