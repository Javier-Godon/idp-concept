"""
Acceptance fixture: WebAppModule + KafkaClusterModule co-deployed in one stack.

Models an event-driven web application IDP stack: a webapp Deployment wired to
a Strimzi Kafka cluster CR in the same namespace. Both modules are rendered
through a single RenderStack via render_stack.

The webapp uses the pause image and sets KAFKA_BOOTSTRAP_SERVERS to the Strimzi
bootstrap service name pattern (<clusterName>-kafka-bootstrap:9092).

Dry-run-only in acceptance_kind.sh. Real apply requires Strimzi Kafka Operator
and a working StorageClass (see docs/ACCEPTANCE_DEPENDENCIES.md).

Covers:
- Application + event-streaming IDP stack via render_stack
- WebApp Component + Kafka Accessory in the same namespace
- Strimzi Kafka + KafkaTopic CRs alongside Deployment resources in one manifest
- Cross-module env wiring: KAFKA_BOOTSTRAP_SERVERS points at Strimzi bootstrap service
"""

import ._helpers as h
import templates.webapp.v1_0_0.webapp as webapp
import templates.kafka.v1_0_0.kafka as kafka

_namespace = "idp-acceptance-webapp-kafka-stack"

_app = webapp.WebAppModule {
    name = "acceptance-webapp-kafka"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "server.port: 8080\nkafka.bootstrap: acceptance-kafka-stack-kafka-bootstrap:9092\nkafka.topic: events\n"}
    env = [
        {name = "KAFKA_BOOTSTRAP_SERVERS", value = "acceptance-kafka-stack-kafka-bootstrap:9092"}
        {name = "KAFKA_TOPIC", value = "events"}
    ]
}.instance

_kafka = kafka.KafkaClusterModule {
    name = "acceptance-kafka-stack"
    namespace = _namespace
    configurations = {}
    asset = {version = "3.8.0"}
    dependsOn = []
    clusterName = "acceptance-kafka-stack"
    kafkaReplicas = 1
    zookeeperReplicas = 1
    storageSize = "1Gi"
    topics = [kafka.KafkaTopicSpec {name = "events", partitions = 1, replicas = 1}]
}.instance

h.render_stack([_namespace], [_app], [_kafka])

