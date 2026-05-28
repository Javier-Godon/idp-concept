"""
Acceptance fixture: KafkaClusterModule through the IDP render path.
"""

import ._helpers as h
import templates.kafka.v1_0_0.kafka as kafka

_module = kafka.KafkaClusterModule {
    name = "acceptance-kafka"
    namespace = "idp-acceptance-kafka"
    configurations = {}
    asset = {version = "3.8.0"}
    dependsOn = []
    clusterName = "acceptance-kafka"
    kafkaReplicas = 1
    zookeeperReplicas = 1
    storageSize = "1Gi"
    topics = [kafka.KafkaTopicSpec {name = "acceptance-topic", partitions = 1, replicas = 1}]
}.instance

h.render_accessory("idp-acceptance-kafka", _module)

