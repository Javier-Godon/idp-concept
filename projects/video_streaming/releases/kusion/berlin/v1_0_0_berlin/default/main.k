import framework.procedures.kcl_to_kusion as kcl_to_kusion
import framework.models.k8snamespace as k8snamespace
import modules.appops.video_collector_mongodb_python as video_collector
import modules.infrastructure.apache_kafka.instances as kafka
import modules.infrastructure.mongodb as mongodb

# NAMESPACES
_namespaces = [
    _apps_namespace
    _postgres_namespace
    _certmanager_namespace
    _apache_kafka_namespace
    _mongodb_namespace
]

_apps_namespace = k8snamespace.K8sNamespace {
    name = "apps"
}.instance

_postgres_namespace = k8snamespace.K8sNamespace {
    name = "postgres"
}.instance

_certmanager_namespace = k8snamespace.K8sNamespace {
    name = "cert-manager"
}.instance

_apache_kafka_namespace = k8snamespace.K8sNamespace {
    name = "kafka"
}.instance

_mongodb_namespace = k8snamespace.K8sNamespace {
    name = "mongodb"
}.instance
# COMPONENTS
_video_collector_mongodb_python = video_collector.VideoCollectorMongodbPythonModule {
    name = "kafka-video-consumer-mongodb-python"
    namespace = _apps_namespace.name
    asset = {
        image = "ghcr.io/javier-godon/kafka-video-consumer-mongodb-python"
        version = "3b7436a-2024-12-25T17-19"
    }
    dependsOn = [_apps_namespace]
}.instance
# ACCESSORIES
_accessories = [
    _apache_kafka_instance
    _mongodb_instance
    _mongodb_persistence_volume
]

_apache_kafka_instance = kafka.KafkaSingleInstanceModule {
    name = "kafka"
    namespace = "kafka"
    asset = {
        image = "strimzi"
        version = "0.45.0"
    }
    dependsOn = [_apache_kafka_namespace]
}.instance

_mongodb_instance = mongodb.MongoDBSingleInstanceModule {
    name = "blue-mongo-db"
    namespace = "mongodb"
    asset = {
        image = "mongo@sha256"
        version = "cc62438c8ef61ce02f89b4f7c026e735df4580e8cd8857980d12e0eae73bf044"
    }
    dependsOn = [_mongodb_namespace, _mongodb_persistence_volume]
}.instance

_mongodb_persistence_volume = mongodb.MongoDBPersistenceModule {
    name = "blue-mongo-db"
    namespace = "mongodb"
    asset = {
        image = "mongo@sha256"
        version = "cc62438c8ef61ce02f89b4f7c026e735df4580e8cd8857980d12e0eae73bf044"
    }
    dependsOn = [_mongodb_namespace]
}.instance
# STACK
resources = kcl_to_kusion.kusion_spec_stream_components([_video_collector_mongodb_python]) + kcl_to_kusion.kusion_spec_stream_namespaces(_namespaces) + kcl_to_kusion.kusion_spec_stream_accessories(_accessories)
