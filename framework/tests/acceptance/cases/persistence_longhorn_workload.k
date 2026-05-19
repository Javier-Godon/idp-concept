"""
Acceptance scenario: persistent templates configured to use a Longhorn StorageClass.

This validates the IDP render path for PVC-producing templates with a Longhorn
storage backend. Real reconciliation requires the Flux HelmRelease controller,
Longhorn components, the Longhorn CSI provisioner, and the generated
StorageClass to become ready before dependent PVCs can bind.
"""

import ._helpers as h
import templates.database as database
import templates.longhorn as longhorn
import templates.mongodb as mongo
import templates.postgresql as pg
import templates.rabbitmq as rmq
import templates.redis as redis
import templates.valkey as valkey

_namespace = "idp-acceptance-persistence-longhorn"
_storage_class = "acceptance-longhorn"

_longhorn = longhorn.LonghornModule {
    name = "acceptance-longhorn"
    namespace = _namespace
    configurations = {}
    asset = {version = "1.7.2"}
    dependsOn = []
    longhornName = "acceptance-longhorn"
    chartVersion = "1.7.2"
    storageClassName = _storage_class
    defaultReplicaCount = 1
}.instance

_single_database = database.SingleDatabaseModule {
    name = "acceptance-db-longhorn"
    namespace = _namespace
    configurations = {storageClassName = _storage_class}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = [_longhorn]
    port = 8080
    dataPath = "/data"
    storageSize = "1Gi"
    storageClassName = _storage_class
    createLocalPersistentVolume = False
}.instance

_postgresql = pg.PostgreSQLClusterModule {
    name = "acceptance-postgresql-longhorn"
    namespace = _namespace
    configurations = {}
    asset = {version = "16.4"}
    dependsOn = [_longhorn]
    clusterName = "acceptance-postgresql-longhorn"
    instances = 1
    storageSize = "1Gi"
    storageClass = _storage_class
}.instance

_mongodb = mongo.MongoDBCommunityModule {
    name = "acceptance-mongodb-longhorn"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.0.12"}
    dependsOn = [_longhorn]
    clusterName = "acceptance-mongodb-longhorn"
    members = 1
    mongodbVersion = "7.0.12"
    storageSize = "1Gi"
    storageClassName = _storage_class
}.instance

_rabbitmq = rmq.RabbitMQClusterModule {
    name = "acceptance-rabbitmq-longhorn"
    namespace = _namespace
    configurations = {}
    asset = {version = "3.13.7"}
    dependsOn = [_longhorn]
    clusterName = "acceptance-rabbitmq-longhorn"
    replicas = 1
    storageSize = "1Gi"
    storageClassName = _storage_class
}.instance

_redis = redis.RedisModule {
    name = "acceptance-redis-longhorn"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.0.12"}
    dependsOn = [_longhorn]
    redisName = "acceptance-redis-longhorn"
    storageSize = "1Gi"
    storageClassName = _storage_class
}.instance

_redis_cluster = redis.RedisClusterModule {
    name = "acceptance-redis-cluster-longhorn"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.0.12"}
    dependsOn = [_longhorn]
    clusterName = "acceptance-redis-cluster-longhorn"
    clusterSize = 3
    storageSize = "1Gi"
    storageClassName = _storage_class
}.instance

_valkey = valkey.ValkeyModule {
    name = "acceptance-valkey-longhorn"
    namespace = _namespace
    configurations = {}
    asset = {version = "2.1.3"}
    dependsOn = [_longhorn]
    valkeyName = "acceptance-valkey-longhorn"
    chartVersion = "2.1.3"
    mode = "standalone"
    replicas = 1
    storageSize = "1Gi"
    storageClassName = _storage_class
}.instance

h.render_stack([_namespace], [], [_longhorn, _single_database, _postgresql, _mongodb, _rabbitmq, _redis, _redis_cluster, _valkey])

