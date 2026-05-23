"""
Acceptance fixture: WebAppModule + RabbitMQClusterModule co-deployed in one stack.

Models a message-broker web application IDP stack: a webapp Deployment wired to
a RabbitMQ Cluster CR in the same namespace. Both modules are rendered through a
single RenderStack via render_stack.

The webapp uses the pause image and sets RABBITMQ_HOST to the RabbitMQ service
name pattern (<clusterName>:5672).

Dry-run-only in acceptance_kind.sh. Real apply requires RabbitMQ Cluster Operator
and a working StorageClass (see docs/ACCEPTANCE_DEPENDENCIES.md).

Covers:
- Application + message-broker IDP stack via render_stack
- WebApp Component + RabbitMQ Accessory in the same namespace
- RabbitMQCluster CR shape alongside Deployment resources in one manifest
- Cross-module env wiring: RABBITMQ_HOST points at RabbitMQ service
"""

import ._helpers as h
import templates.webapp as webapp
import templates.rabbitmq as rmq

_namespace = "idp-acceptance-webapp-rabbitmq-stack"

_app = webapp.WebAppModule {
    name = "acceptance-webapp-rmq"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "server.port: 8080\nrabbitmq.host: acceptance-rabbitmq-stack\nrabbitmq.port: 5672\n"}
    env = [
        {name = "RABBITMQ_HOST", value = "acceptance-rabbitmq-stack"}
        {name = "RABBITMQ_PORT", value = "5672"}
    ]
}.instance

_rmq = rmq.RabbitMQClusterModule {
    name = "acceptance-rabbitmq-stack"
    namespace = _namespace
    configurations = {}
    asset = {version = "3.13.7"}
    dependsOn = []
    clusterName = "acceptance-rabbitmq-stack"
    replicas = 1
    storageSize = "1Gi"
}.instance

h.render_stack([_namespace], [_app], [_rmq])

