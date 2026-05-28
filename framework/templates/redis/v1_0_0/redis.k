"""
Redis Module Template — OT-CONTAINER-KIT Redis Operator pattern.
Generates: Redis (standalone) or RedisCluster CRD manifests.

CRD API: redis.redis.opstreelabs.in/v1beta2
Operator: OT-CONTAINER-KIT Redis Operator (https://github.com/OT-CONTAINER-KIT/redis-operator)

Usage:
    import framework.templates.redis.v1_0_0.redis as rd

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
import templates.footprints.v1_0_0.footprint as fp
import templates.admin.v1_0_0.data_admin as admin

_API_VERSION = "redis.redis.opstreelabs.in/v1beta2"
_DEFAULT_IMAGE = "quay.io/opstree/redis:v7.0.12"

schema RedisSpec:
    """Specification for a standalone Redis resource."""
    name: str
    namespace: str
    footprint?: str = "production"
    storageSize?: str
    storageClassName?: str
    image?: str = _DEFAULT_IMAGE
    resources?: any

    check:
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"
        len(storageSize) > 0 if storageSize is not Undefined, "storageSize must not be empty"

schema RedisClusterSpec:
    """Specification for a RedisCluster resource."""
    name: str
    namespace: str
    footprint?: str = "production"
    clusterSize?: int
    storageSize?: str
    storageClassName?: str
    image?: str = _DEFAULT_IMAGE
    resources?: any

    check:
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"
        clusterSize >= 3 if clusterSize is not Undefined, "clusterSize must be >= 3"
        len(storageSize) > 0 if storageSize is not Undefined, "storageSize must not be empty"

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
    _storage_size = spec.storageSize if spec.storageSize is not Undefined else fp.storage_size(spec.footprint, "512Mi", "1Gi", "4Gi", "8Gi")
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
            storage = _build_storage(_storage_size, spec.storageClassName)
        }
    }
}

build_redis_cluster = lambda spec: RedisClusterSpec -> any {
    _resources = {if spec.resources: resources = spec.resources}
    _cluster_size = spec.clusterSize if spec.clusterSize is not Undefined else fp.replicas(spec.footprint, 3, 3, 3, 3)
    _storage_size = spec.storageSize if spec.storageSize is not Undefined else fp.storage_size(spec.footprint, "512Mi", "1Gi", "4Gi", "10Gi")
    {
        apiVersion = _API_VERSION
        kind = "RedisCluster"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            clusterSize = _cluster_size
            kubernetesConfig = {
                image = spec.image
            } | _resources
            storage = _build_storage(_storage_size, spec.storageClassName)
        }
    }
}

schema RedisModule(accessory.Accessory):
    """Template for standalone Redis instances via the Redis Operator."""
    kind = "CRD"

    redisName: str
    footprint?: str = "production"
    storageSize?: str
    storageClassName?: str
    image?: str = _DEFAULT_IMAGE
    resources?: any
    redisInsight?: admin.RedisInsightSpec

    leaders = [leader.build_accessory_leader(redisName, namespace, "Redis", _API_VERSION)]

    _redis_manifest = build_redis(RedisSpec {
        name = redisName
        namespace = namespace
        footprint = footprint
        storageSize = storageSize
        storageClassName = storageClassName
        image = image
        resources = resources
    })

    _redis_insight_manifests = admin.build_redis_insight_resources(redisInsight) if redisInsight else []

    manifests = [_redis_manifest] + _redis_insight_manifests

schema RedisClusterModule(accessory.Accessory):
    """Template for Redis Cluster instances via the Redis Operator."""
    kind = "CRD"

    clusterName: str
    footprint?: str = "production"
    clusterSize?: int
    storageSize?: str
    storageClassName?: str
    image?: str = _DEFAULT_IMAGE
    resources?: any
    redisInsight?: admin.RedisInsightSpec

    leaders = [leader.build_accessory_leader(clusterName, namespace, "RedisCluster", _API_VERSION)]

    _cluster_manifest = build_redis_cluster(RedisClusterSpec {
        name = clusterName
        namespace = namespace
        footprint = footprint
        clusterSize = clusterSize
        storageSize = storageSize
        storageClassName = storageClassName
        image = image
        resources = resources
    })

    _redis_insight_manifests = admin.build_redis_insight_resources(redisInsight) if redisInsight else []

    manifests = [_cluster_manifest] + _redis_insight_manifests
