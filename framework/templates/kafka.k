"""
Kafka Cluster Module Template — pre-built Strimzi Kafka cluster pattern.
Generates: Kafka CRD + KafkaTopic CRDs.

Usage:
    import framework.templates.kafka as kafka

    schema MyKafka(kafka.KafkaClusterModule):
        clusterName = "my-cluster"
        topics = [kafka.KafkaTopicSpec { name = "my-topic", partitions = 3 }]
"""
import models.modules.accessory as accessory
import builders.leader as leader

schema KafkaTopicSpec:
    name: str
    partitions?: int = 3
    replicas?: int = 1

schema KafkaClusterModule(accessory.Accessory):
    kind = "CRD"

    # User-configurable
    clusterName: str
    kafkaVersion?: str = "3.8.0"
    kafkaReplicas?: int = 1
    zookeeperReplicas?: int = 1
    storageSize?: str = "100Gi"
    topics?: [KafkaTopicSpec] = []
    interBrokerProtocolVersion?: str = "3.8"

    # Auto-computed
    leaders = [leader.build_accessory_leader(clusterName, namespace, "Kafka", "kafka.strimzi.io/v1beta2")]

    _kafka_manifest = {
        apiVersion = "kafka.strimzi.io/v1beta2"
        kind = "Kafka"
        metadata = {
            name = clusterName
            namespace = namespace
        }
        spec = {
            kafka = {
                version = kafkaVersion
                replicas = kafkaReplicas
                listeners = [
                    {
                        name = "plain"
                        port = 9092
                        $type = "internal"
                        tls = False
                    }
                    {
                        name = "tls"
                        port = 9093
                        $type = "internal"
                        tls = True
                    }
                    {
                        name = "external"
                        port = 9094
                        $type = "nodeport"
                        tls = False
                    }
                ]
                config = {
                    "offsets.topic.replication.factor" = 1
                    "transaction.state.log.replication.factor" = 1
                    "transaction.state.log.min.isr" = 1
                    "default.replication.factor" = 1
                    "min.insync.replicas" = 1
                    "inter.broker.protocol.version" = interBrokerProtocolVersion
                }
                storage = {
                    $type = "jbod"
                    volumes = [{
                        id = 0
                        $type = "persistent-claim"
                        size = storageSize
                        deleteClaim = False
                    }]
                }
            }
            zookeeper = {
                replicas = zookeeperReplicas
                storage = {
                    $type = "persistent-claim"
                    size = storageSize
                    deleteClaim = False
                }
            }
            entityOperator = {
                topicOperator = {}
                userOperator = {}
            }
        }
    }

    _topic_manifests = [{
        apiVersion = "kafka.strimzi.io/v1beta2"
        kind = "KafkaTopic"
        metadata = {
            name = topic.name
            labels = {
                "strimzi.io/cluster" = clusterName
            }
            namespace = namespace
        }
        spec = {
            partitions = topic.partitions
            replicas = topic.replicas
        }
    } for topic in topics]

    manifests = [_kafka_manifest] + _topic_manifests
