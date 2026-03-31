import runtime
import builders.service as svc

# === Test: Minimal Service (ClusterIP) ===
test_build_service_clusterip = lambda {
    _spec = svc.ServiceSpec {
        name = "test-svc"
        namespace = "default"
        port = 8080
    }
    _result = svc.build_service(_spec)
    assert _result.metadata.name == "test-svc"
    assert _result.metadata.namespace == "default"
    assert _result.kind == "Service"
    assert _result.apiVersion == "v1"
    assert _result.spec.selector.app == "test-svc"
    assert _result.spec.ports[0].port == 8080
    assert _result.spec.$type == "ClusterIP"
}

# === Test: NodePort Service ===
test_build_service_nodeport = lambda {
    _spec = svc.ServiceSpec {
        name = "web-svc"
        namespace = "apps"
        port = 8080
        serviceType = "NodePort"
        nodePort = 30080
    }
    _result = svc.build_service(_spec)
    assert _result.spec.$type == "NodePort"
    assert _result.spec.ports[0].nodePort == 30080
}

# === Test: Service with targetPort ===
test_build_service_target_port = lambda {
    _spec = svc.ServiceSpec {
        name = "web"
        namespace = "apps"
        port = 80
        targetPort = 8080
    }
    _result = svc.build_service(_spec)
    assert _result.spec.ports[0].port == 80
    assert _result.spec.ports[0].targetPort == 8080
}

# === Test: Service with portName ===
test_build_service_port_name = lambda {
    _spec = svc.ServiceSpec {
        name = "web"
        namespace = "apps"
        port = 8080
        portName = "http"
    }
    _result = svc.build_service(_spec)
    assert _result.spec.ports[0].name == "http"
}

# === Test: Service with labels ===
test_build_service_labels = lambda {
    _spec = svc.ServiceSpec {
        name = "web"
        namespace = "apps"
        port = 8080
        labels = { app = "web", tier = "frontend" }
    }
    _result = svc.build_service(_spec)
    assert _result.metadata.labels.app == "web"
    assert _result.metadata.labels.tier == "frontend"
}

# === Test: LoadBalancer Service ===
test_build_service_loadbalancer = lambda {
    _spec = svc.ServiceSpec {
        name = "api"
        namespace = "apps"
        port = 443
        serviceType = "LoadBalancer"
    }
    _result = svc.build_service(_spec)
    assert _result.spec.$type == "LoadBalancer"
}

# ====================================================================
# Validation Tests (check blocks)
# ====================================================================

# === Test: Invalid port (too high) ===
test_service_invalid_port_high = lambda {
    _msg = runtime.catch(lambda {
        svc.ServiceSpec {
            name = "bad"
            namespace = "ns"
            port = 70000
        }
    })
    assert _msg == "port must be between 1 and 65535"
}

# === Test: Invalid port (zero) ===
test_service_invalid_port_zero = lambda {
    _msg = runtime.catch(lambda {
        svc.ServiceSpec {
            name = "bad"
            namespace = "ns"
            port = 0
        }
    })
    assert _msg == "port must be between 1 and 65535"
}

# === Test: Invalid service type ===
test_service_invalid_type = lambda {
    _msg = runtime.catch(lambda {
        svc.ServiceSpec {
            name = "bad"
            namespace = "ns"
            port = 8080
            serviceType = "InvalidType"
        }
    })
    assert _msg == "serviceType must be ClusterIP, NodePort, or LoadBalancer"
}
