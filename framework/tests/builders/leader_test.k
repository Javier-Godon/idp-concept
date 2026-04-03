import builders.leader as leader

# === Test: Unified build_leader with defaults ===
test_build_leader_defaults = lambda {
    _result = leader.build_leader("my-app", "apps")
    assert _result.name == "my-app"
    assert _result.namespace == "apps"
    assert _result.kind == "Deployment"
    assert _result.apiVersion == "apps/v1"
}

# === Test: Unified build_leader custom kind ===
test_build_leader_custom = lambda {
    _result = leader.build_leader("kafka-cluster", "infra", "Kafka", "kafka.strimzi.io/v1beta2")
    assert _result.name == "kafka-cluster"
    assert _result.namespace == "infra"
    assert _result.kind == "Kafka"
    assert _result.apiVersion == "kafka.strimzi.io/v1beta2"
}

# === Test: Component leader defaults (backward compat) ===
test_build_component_leader_defaults = lambda {
    _result = leader.build_component_leader("my-app", "apps")
    assert _result.name == "my-app"
    assert _result.namespace == "apps"
    assert _result.kind == "Deployment"
    assert _result.apiVersion == "apps/v1"
}

# === Test: Component leader custom kind (backward compat) ===
test_build_component_leader_custom = lambda {
    _result = leader.build_component_leader("my-app", "apps", "StatefulSet", "apps/v1")
    assert _result.kind == "StatefulSet"
    assert _result.apiVersion == "apps/v1"
}

# === Test: Accessory leader (backward compat) ===
test_build_accessory_leader = lambda {
    _result = leader.build_accessory_leader("kafka-cluster", "infra", "Kafka", "kafka.strimzi.io/v1beta2")
    assert _result.name == "kafka-cluster"
    assert _result.namespace == "infra"
    assert _result.kind == "Kafka"
    assert _result.apiVersion == "kafka.strimzi.io/v1beta2"
}
