import framework.models.modules.k8snamespace as k8snamespace
import video_streaming.modules.appops.video_collector_mongodb_python as video_collector
import video_streaming.modules.infrastructure.apache_kafka.instances as kafka
import video_streaming.modules.infrastructure.mongodb as mongodb
import framework.models.stack

schema VideoStreamingDevelopmentStack(stack.Stack):
    k8snamespaces = [
        _apps_namespace
        _postgres_namespace
        _certmanager_namespace
        _apache_kafka_namespace
        _mongodb_namespace
    ]

    _apps_namespace = k8snamespace.K8sNamespace {
        name = instanceConfigurations.appsNamespace
        configurations = instanceConfigurations
    }.instance

    _postgres_namespace = k8snamespace.K8sNamespace {
        name = instanceConfigurations.postgresNamespace
        configurations = instanceConfigurations
    }.instance

    _certmanager_namespace = k8snamespace.K8sNamespace {
        name = instanceConfigurations.certmanagerNamespace
        configurations = instanceConfigurations
    }.instance

    _apache_kafka_namespace = k8snamespace.K8sNamespace {
        name = "kafka"
        configurations = instanceConfigurations
    }.instance

    _mongodb_namespace = k8snamespace.K8sNamespace {
        name = "mongodb"
        configurations = instanceConfigurations
    }.instance
    # COMPONENTS
    components = [
        _video_collector_mongodb_python
    ]
    _video_collector_mongodb_python = video_collector.VideoCollectorMongodbPythonModule {
        name = "kafka_video_consumer_mongodb_python"
        namespace = _apps_namespace.name
        asset = {
            image = "ghcr.io/javier-godon/kafka-video-consumer-mongodb-python"
            version = "3b7436a-2024-12-25T17-19"
        }
        configurations = instanceConfigurations
        dependsOn = [_apps_namespace]
    }.instance
    # ACCESSORIES
    accessories = [
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
        configurations = instanceConfigurations
        dependsOn = [_apache_kafka_namespace]
    }.instance

    _mongodb_instance = mongodb.MongoDBSingleInstanceModule {
        name = "blue-mongo-db"
        namespace = "mongodb"
        asset = {
            image = "mongo@sha256"
            version = "cc62438c8ef61ce02f89b4f7c026e735df4580e8cd8857980d12e0eae73bf044"
        }
        configurations = instanceConfigurations
        dependsOn = [_mongodb_namespace, _mongodb_persistence_volume]
    }.instance

    _mongodb_persistence_volume = mongodb.MongoDBPersistenceModule {
        name = "blue-mongo-db"
        namespace = "mongodb"
        asset = {
            image = "mongo@sha256"
            version = "cc62438c8ef61ce02f89b4f7c026e735df4580e8cd8857980d12e0eae73bf044"
        }
        configurations = instanceConfigurations
        dependsOn = [_mongodb_namespace]
    }.instance

