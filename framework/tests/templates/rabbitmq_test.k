"""
RabbitMQ Cluster Template Tests.

Tests the build_rabbitmq_cluster lambda and CNPGScheduledBackupSpec validations.
"""
import templates.rabbitmq as rmq
import runtime

# === Test: build_rabbitmq_cluster generates correct CRD ===
test_build_rabbitmq_cluster_basic = lambda {
    _result = rmq.build_rabbitmq_cluster(rmq.RabbitMQClusterSpec {
        name = "my-rmq"
        namespace = "messaging"
        replicas = 3
        storageSize = "10Gi"
    })
    assert _result.apiVersion == "rabbitmq.com/v1beta1"
    assert _result.kind == "RabbitmqCluster"
    assert _result.metadata.name == "my-rmq"
    assert _result.metadata.namespace == "messaging"
    assert _result.spec.replicas == 3
    assert _result.spec.persistence.storage == "10Gi"
}

# === Test: Cluster with plugins ===
test_build_rabbitmq_cluster_with_plugins = lambda {
    _result = rmq.build_rabbitmq_cluster(rmq.RabbitMQClusterSpec {
        name = "my-rmq"
        namespace = "messaging"
        replicas = 1
        storageSize = "5Gi"
        additionalPlugins = ["rabbitmq_top", "rabbitmq_shovel"]
    })
    assert _result.spec.rabbitmq.additionalPlugins[0] == "rabbitmq_top"
    assert _result.spec.rabbitmq.additionalPlugins[1] == "rabbitmq_shovel"
}

# === Test: Cluster with additionalConfig ===
test_build_rabbitmq_cluster_with_config = lambda {
    _result = rmq.build_rabbitmq_cluster(rmq.RabbitMQClusterSpec {
        name = "my-rmq"
        namespace = "messaging"
        replicas = 1
        storageSize = "5Gi"
        additionalConfig = "channel_max = 1050"
    })
    assert _result.spec.rabbitmq.additionalConfig == "channel_max = 1050"
}

# === Test: Cluster with custom image ===
test_build_rabbitmq_cluster_with_image = lambda {
    _result = rmq.build_rabbitmq_cluster(rmq.RabbitMQClusterSpec {
        name = "my-rmq"
        namespace = "messaging"
        replicas = 1
        storageSize = "5Gi"
        image = "rabbitmq:3.13.7-management"
    })
    assert _result.spec.image == "rabbitmq:3.13.7-management"
}

# === Test: Cluster with storageClassName ===
test_build_rabbitmq_cluster_with_storage_class = lambda {
    _result = rmq.build_rabbitmq_cluster(rmq.RabbitMQClusterSpec {
        name = "my-rmq"
        namespace = "messaging"
        replicas = 1
        storageSize = "20Gi"
        storageClassName = "fast-ssd"
    })
    assert _result.spec.persistence.storageClassName == "fast-ssd"
    assert _result.spec.persistence.storage == "20Gi"
}

# === Test: Cluster with resources ===
test_build_rabbitmq_cluster_with_resources = lambda {
    _result = rmq.build_rabbitmq_cluster(rmq.RabbitMQClusterSpec {
        name = "my-rmq"
        namespace = "messaging"
        replicas = 1
        storageSize = "5Gi"
        resources = {
            requests = {cpu = "1000m", memory = "2Gi"}
            limits = {cpu = "2000m", memory = "2Gi"}
        }
    })
    assert _result.spec.resources.requests.cpu == "1000m"
    assert _result.spec.resources.limits.memory == "2Gi"
}

# === Test: Cluster defaults ===
test_build_rabbitmq_cluster_defaults = lambda {
    _result = rmq.build_rabbitmq_cluster(rmq.RabbitMQClusterSpec {
        name = "my-rmq"
        namespace = "messaging"
        replicas = 1
        storageSize = "5Gi"
    })
    # No image, no rabbitmq block, no resources
    assert _result.spec.replicas == 1
    assert _result.spec.persistence.storage == "5Gi"
}

# === Test: Validation — replicas must be >= 1 ===
test_rabbitmq_rejects_zero_replicas = lambda {
    _err = runtime.catch(lambda {
        rmq.RabbitMQClusterSpec {
            name = "bad"
            namespace = "messaging"
            replicas = 0
            storageSize = "5Gi"
        }
    })
    assert _err, "Expected validation error for replicas=0"
}

# === Test: Validation — storageSize must not be empty ===
test_rabbitmq_rejects_empty_storage = lambda {
    _err = runtime.catch(lambda {
        rmq.RabbitMQClusterSpec {
            name = "bad"
            namespace = "messaging"
            replicas = 1
            storageSize = ""
        }
    })
    assert _err, "Expected validation error for empty storageSize"
}
