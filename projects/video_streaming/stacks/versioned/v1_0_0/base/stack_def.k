import framework.models.modules.k8snamespace as k8snamespace
import modules.appops.video_collector_mongodb_python as video_collector
import modules.infrastructure.apache_kafka.instances as kafka
import modules.infrastructure.mongodb as mongodb
import framework.models.stack
import framework.models.profile as fmwk_profile
import framework.configs.models.profile_config
import framework.configs.configurations as full_config
import versioned.v1_0_0.base.configurations as base_config

schema VideoStreamingv1_0_0_BaseStack(stack.Stack):

    _instance_configurations = full_config.Configurations {
        kernelConfigurations = kernelConfigurations
        siteConfigurations = site.configurations
        profileConfigurations = profile.configurations
    }

    profile = fmwk_profile.Profile {
        name = "v1_0_0"
        configurations = base_config.video_streaming_v1_0_0_base_profile_configurations
    }

    # NAMESPACES
    k8snamespaces = [
        _apps_namespace
        _postgres_namespace
        _certmanager_namespace
        _apache_kafka_namespace
        _mongodb_namespace
    ]

    _apps_namespace = k8snamespace.K8sNamespace {
        name = "apps"
        configurations = _instance_configurations
    }.instance

    _postgres_namespace = k8snamespace.K8sNamespace {
        name = "postgres"
        configurations = _instance_configurations
    }.instance

    _certmanager_namespace = k8snamespace.K8sNamespace {
        name = "cert-manager"
        configurations = _instance_configurations
    }.instance

    _apache_kafka_namespace = k8snamespace.K8sNamespace {
        name = "kafka"
        configurations = _instance_configurations
    }.instance

    _mongodb_namespace = k8snamespace.K8sNamespace {
        name = "mongodb"
        configurations = _instance_configurations
    }.instance
    # COMPONENTS
    components = [
        _video_collector_mongodb_python
    ]
    _video_collector_mongodb_python = video_collector.VideoCollectorMongodbPythonModule {
        name = "kafka-video-consumer-mongodb-python"
        namespace = _apps_namespace.name
        asset = {
            image = "ghcr.io/javier-godon/kafka-video-consumer-mongodb-python"
            version = "3b7436a-2024-12-25T17-19"
        }
        configurations = _instance_configurations
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
        configurations = _instance_configurations
        dependsOn = [_apache_kafka_namespace]
    }.instance

    _mongodb_instance = mongodb.MongoDBSingleInstanceModule {
        name = "blue-mongo-db"
        namespace = "mongodb"
        asset = {
            image = "mongo@sha256"
            version = "cc62438c8ef61ce02f89b4f7c026e735df4580e8cd8857980d12e0eae73bf044"
        }
        configurations = _instance_configurations
        dependsOn = [_mongodb_namespace, _mongodb_persistence_volume]
    }.instance

    _mongodb_persistence_volume = mongodb.MongoDBPersistenceModule {
        name = "blue-mongo-db"
        namespace = "mongodb"
        asset = {
            image = "mongo@sha256"
            version = "cc62438c8ef61ce02f89b4f7c026e735df4580e8cd8857980d12e0eae73bf044"
        }
        configurations = _instance_configurations
        dependsOn = [_mongodb_namespace]
    }.instance





