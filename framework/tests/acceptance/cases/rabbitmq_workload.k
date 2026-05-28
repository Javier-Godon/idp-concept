"""
Acceptance fixture: RabbitMQClusterModule through the IDP render path.
"""

import ._helpers as h
import templates.rabbitmq.v1_0_0.rabbitmq as rmq

_module = rmq.RabbitMQClusterModule {
    name = "acceptance-rabbitmq"
    namespace = "idp-acceptance-rabbitmq"
    configurations = {}
    asset = {version = "3.13.7"}
    dependsOn = []
    clusterName = "acceptance-rabbitmq"
    replicas = 1
    storageSize = "1Gi"
}.instance

h.render_accessory("idp-acceptance-rabbitmq", _module)

