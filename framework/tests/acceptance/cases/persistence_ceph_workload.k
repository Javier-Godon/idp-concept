"""
Acceptance scenario: persistent templates configured to use a Rook Ceph StorageClass.

This validates the IDP render path for PVC-producing templates with a Ceph/Rook
storage backend. Real reconciliation requires the Flux HelmRelease controller,
Rook Ceph operator, CephCluster, CephBlockPool, CSI secrets, and generated
StorageClass to become ready before dependent PVCs can bind.
"""

import ._helpers as h
import templates.ceph.v1_0_0.ceph as ceph
import templates.database.v1_0_0.database as database
import templates.mongodb.v1_0_0.mongodb as mongo
import templates.postgresql.v1_0_0.postgresql as pg
import templates.rabbitmq.v1_0_0.rabbitmq as rmq
import templates.redis.v1_0_0.redis as redis
import templates.valkey.v1_0_0.valkey as valkey

_namespace = "idp-acceptance-persistence-ceph"
_storage_class = "acceptance-ceph-block"

_ceph = ceph.CephModule {
    name = "acceptance-ceph"
    namespace = _namespace
    configurations = {}
    asset = {version = "1.15.2"}
    dependsOn = []
    cephName = "acceptance-ceph"
    clusterName = "acceptance-ceph"
    chartVersion = "1.15.2"
    monCount = 1
    mgrCount = 1
    blockPoolReplicatedSize = 1
    storageUseAllNodes = False
    storageUseAllDevices = False
    createBlockPoolAndStorageClass = True
    storageClassName = _storage_class
}.instance

_single_database = database.SingleDatabaseModule {
    name = "acceptance-db-ceph"
    namespace = _namespace
    configurations = {storageClassName = _storage_class}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = [_ceph]
    port = 8080
    dataPath = "/data"
    storageSize = "1Gi"
    storageClassName = _storage_class
    createLocalPersistentVolume = False
}.instance

_postgresql = pg.PostgreSQLClusterModule {
    name = "acceptance-postgresql-ceph"
    namespace = _namespace
    configurations = {}
    asset = {version = "16.4"}
    dependsOn = [_ceph]
    clusterName = "acceptance-postgresql-ceph"
    instances = 1
    storageSize = "1Gi"
    storageClass = _storage_class
}.instance

_mongodb = mongo.MongoDBCommunityModule {
    name = "acceptance-mongodb-ceph"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.0.12"}
    dependsOn = [_ceph]
    clusterName = "acceptance-mongodb-ceph"
    members = 1
    mongodbVersion = "7.0.12"
    storageSize = "1Gi"
    storageClassName = _storage_class
}.instance

_rabbitmq = rmq.RabbitMQClusterModule {
    name = "acceptance-rabbitmq-ceph"
    namespace = _namespace
    configurations = {}
    asset = {version = "3.13.7"}
    dependsOn = [_ceph]
    clusterName = "acceptance-rabbitmq-ceph"
    replicas = 1
    storageSize = "1Gi"
    storageClassName = _storage_class
}.instance

_redis = redis.RedisModule {
    name = "acceptance-redis-ceph"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.0.12"}
    dependsOn = [_ceph]
    redisName = "acceptance-redis-ceph"
    storageSize = "1Gi"
    storageClassName = _storage_class
}.instance

_redis_cluster = redis.RedisClusterModule {
    name = "acceptance-redis-cluster-ceph"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.0.12"}
    dependsOn = [_ceph]
    clusterName = "acceptance-redis-cluster-ceph"
    clusterSize = 3
    storageSize = "1Gi"
    storageClassName = _storage_class
}.instance

_valkey = valkey.ValkeyModule {
    name = "acceptance-valkey-ceph"
    namespace = _namespace
    configurations = {}
    asset = {version = "2.1.3"}
    dependsOn = [_ceph]
    valkeyName = "acceptance-valkey-ceph"
    chartVersion = "2.1.3"
    mode = "standalone"
    replicas = 1
    storageSize = "1Gi"
    storageClassName = _storage_class
}.instance

h.render_stack([_namespace], [], [_ceph, _single_database, _postgresql, _mongodb, _rabbitmq, _redis, _redis_cluster, _valkey])

