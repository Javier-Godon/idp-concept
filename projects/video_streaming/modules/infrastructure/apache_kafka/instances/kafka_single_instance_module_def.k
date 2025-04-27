import framework.models.accessory as accessory

schema KafkaSingleInstanceModule(accessory.Accessory):
    kind = "CRD"
    leaders = [accessory.AccessoryLeader {
        name = "blue-kafka-cluster"
        kind = "Kafka"
        apiVersion = "kafka.strimzi.io/v1beta2"
        namespace = namespace
    }]
    manifests = [
        {
            apiVersion = "kafka.strimzi.io/v1beta2"
            kind = "Kafka"
            metadata = {
                name = "blue-kafka-cluster"
                namespace = namespace
            }
            spec = {
                kafka = {
                    version = "3.8.0"
                    replicas = 1
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
                        "inter.broker.protocol.version" = "3.8"
                    }
                    storage = {
                        $type = "jbod"
                        volumes = [
                            {
                                id = 0
                                $type = "persistent-claim"
                                size = "100Gi"
                                deleteClaim = False
                            }
                        ]
                    }
                }
                zookeeper = {
                    replicas = 1
                    storage = {
                        $type = "persistent-claim"
                        size = "100Gi"
                        deleteClaim = False
                    }
                }
                entityOperator = {
                    topicOperator = {}
                    userOperator = {}
                }
            }
        }
        {
            apiVersion = "kafka.strimzi.io/v1beta2"
            kind = "KafkaTopic"
            metadata = {
                name = "processed-video"
                labels = {
                    "strimzi.io/cluster" = "blue-kafka-cluster"
                }
                namespace = namespace
            }
            spec = {
                partitions = 3
                replicas = 1
            }
        }
        {
            apiVersion = "kafka.strimzi.io/v1beta2"
            kind = "KafkaTopic"
            metadata = {
                name = "streaming-video"
                labels = {
                    "strimzi.io/cluster" = "blue-kafka-cluster"
                }
                namespace = namespace
            }
            spec = {
                partitions = 3
                replicas = 1
            }
        }
    ]

