"""
RabbitMQ Cluster Module Template — RabbitMQ Cluster Operator pattern.
Generates: RabbitmqCluster CRD manifest.

CRD API: rabbitmq.com/v1beta1
Operator: RabbitMQ Cluster Operator (https://www.rabbitmq.com/kubernetes/operator/operator-overview)

Usage:
    import framework.templates.rabbitmq as rmq

    schema MyRabbitMQ(rmq.RabbitMQClusterModule):
        clusterName = "my-rmq"
        replicas = 3
        storageSize = "10Gi"
        additionalPlugins = ["rabbitmq_top"]
"""
import models.modules.accessory as accessory
import builders.leader as leader

schema RabbitMQClusterSpec:
    """Specification for a RabbitmqCluster resource."""
    name: str
    namespace: str
    replicas: int = 3
    storageSize: str
    storageClassName?: str
    image?: str
    additionalPlugins?: [str]
    additionalConfig?: str
    resources?: any
    serviceType?: str

    check:
        replicas >= 1, "replicas must be >= 1"
        len(storageSize) > 0, "storageSize must not be empty"

build_rabbitmq_cluster = lambda spec: RabbitMQClusterSpec -> any {
    _image = {if spec.image: image = spec.image}
    _resources = {if spec.resources: resources = spec.resources}
    _service = {if spec.serviceType: service = {$type = spec.serviceType}}
    _storage_class = {if spec.storageClassName: storageClassName = spec.storageClassName}
    _rabbitmq_plugins = {if spec.additionalPlugins: additionalPlugins = spec.additionalPlugins}
    _rabbitmq_config = {if spec.additionalConfig: additionalConfig = spec.additionalConfig}
    _rabbitmq = {if spec.additionalPlugins or spec.additionalConfig: rabbitmq = {} | _rabbitmq_plugins | _rabbitmq_config}
    {
        apiVersion = "rabbitmq.com/v1beta1"
        kind = "RabbitmqCluster"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            replicas = spec.replicas
            persistence = {
                storage = spec.storageSize
            } | _storage_class
        } | _image | _resources | _service | _rabbitmq
    }
}

schema RabbitMQClusterModule(accessory.Accessory):
    """High-level template for RabbitMQ clusters via the Cluster Operator.

    Extends Accessory with kind="CRD" and generates RabbitmqCluster CRD manifest.
    """
    kind = "CRD"

    # User-configurable
    clusterName: str
    replicas?: int = 3
    storageSize: str
    storageClassName?: str
    image?: str
    additionalPlugins?: [str]
    additionalConfig?: str
    resources?: any
    serviceType?: str

    # Auto-computed
    leaders = [leader.build_accessory_leader(clusterName, namespace, "RabbitmqCluster", "rabbitmq.com/v1beta1")]

    _cluster_manifest = build_rabbitmq_cluster(RabbitMQClusterSpec {
        name = clusterName
        namespace = namespace
        replicas = replicas
        storageSize = storageSize
        storageClassName = storageClassName
        image = image
        additionalPlugins = additionalPlugins
        additionalConfig = additionalConfig
        resources = resources
        serviceType = serviceType
    })

    manifests = [_cluster_manifest]
