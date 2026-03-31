import runtime
import builders.deployment as deploy

# === Test: Minimal Deployment ===
test_build_deployment_minimal = lambda {
    _spec = deploy.DeploymentSpec {
        name = "test-app"
        namespace = "default"
        image = "test/image"
        version = "1.0.0"
    }
    _result = deploy.build_deployment(_spec)
    assert _result.metadata.name == "test-app"
    assert _result.metadata.namespace == "default"
    assert _result.kind == "Deployment"
    assert _result.apiVersion == "apps/v1"
    assert _result.spec.replicas == 1
    assert _result.spec.template.spec.containers[0].name == "test-app"
    assert _result.spec.template.spec.containers[0].image == "test/image:1.0.0"
    assert _result.spec.template.spec.containers[0].imagePullPolicy == "IfNotPresent"
    assert _result.spec.selector.matchLabels.app == "test-app"
    assert _result.spec.template.metadata.labels.app == "test-app"
}

# === Test: Deployment with port ===
test_build_deployment_with_port = lambda {
    _spec = deploy.DeploymentSpec {
        name = "web"
        namespace = "apps"
        image = "myregistry/web"
        version = "2.0.0"
        port = 8080
    }
    _result = deploy.build_deployment(_spec)
    _container = _result.spec.template.spec.containers[0]
    assert _container.ports[0].containerPort == 8080
}

# === Test: Deployment with replicas ===
test_build_deployment_replicas = lambda {
    _spec = deploy.DeploymentSpec {
        name = "web"
        namespace = "apps"
        image = "img"
        version = "1.0"
        replicas = 3
    }
    _result = deploy.build_deployment(_spec)
    assert _result.spec.replicas == 3
}

# === Test: Deployment with env vars ===
test_build_deployment_env = lambda {
    _spec = deploy.DeploymentSpec {
        name = "web"
        namespace = "apps"
        image = "img"
        version = "1.0"
        env = [
            { name = "KEY1", value = "val1" }
            { name = "KEY2", value = "val2" }
        ]
    }
    _result = deploy.build_deployment(_spec)
    _container = _result.spec.template.spec.containers[0]
    assert len(_container.env) == 2
    assert _container.env[0].name == "KEY1"
    assert _container.env[0].value == "val1"
}

# === Test: Deployment with resources ===
test_build_deployment_resources = lambda {
    _spec = deploy.DeploymentSpec {
        name = "web"
        namespace = "apps"
        image = "img"
        version = "1.0"
        resources = deploy.ResourceSpec {
            cpuRequest = "500m"
            cpuLimit = "2"
            memoryRequest = "1Gi"
            memoryLimit = "4Gi"
        }
    }
    _result = deploy.build_deployment(_spec)
    _container = _result.spec.template.spec.containers[0]
    assert _container.resources.requests.cpu == "500m"
    assert _container.resources.requests.memory == "1Gi"
    assert _container.resources.limits.cpu == "2"
    assert _container.resources.limits.memory == "4Gi"
}

# === Test: Deployment with resource defaults ===
test_build_deployment_resource_defaults = lambda {
    _spec = deploy.DeploymentSpec {
        name = "web"
        namespace = "apps"
        image = "img"
        version = "1.0"
        resources = deploy.ResourceSpec {}
    }
    _result = deploy.build_deployment(_spec)
    _container = _result.spec.template.spec.containers[0]
    assert _container.resources.requests.cpu == "250m"
    assert _container.resources.requests.memory == "512Mi"
    assert _container.resources.limits.cpu == "1"
    assert _container.resources.limits.memory == "2Gi"
}

# === Test: Deployment with HTTP liveness probe ===
test_build_deployment_http_probe = lambda {
    _spec = deploy.DeploymentSpec {
        name = "web"
        namespace = "apps"
        image = "img"
        version = "1.0"
        livenessProbe = deploy.ProbeSpec {
            probeType = "http"
            path = "/health"
            port = 8080
        }
    }
    _result = deploy.build_deployment(_spec)
    _container = _result.spec.template.spec.containers[0]
    assert _container.livenessProbe.httpGet.path == "/health"
    assert _container.livenessProbe.httpGet.port == 8080
    assert _container.livenessProbe.initialDelaySeconds == 30
    assert _container.livenessProbe.periodSeconds == 5
}

# === Test: Deployment with exec probe ===
test_build_deployment_exec_probe = lambda {
    _spec = deploy.DeploymentSpec {
        name = "web"
        namespace = "apps"
        image = "img"
        version = "1.0"
        readinessProbe = deploy.ProbeSpec {
            probeType = "exec"
            command = ["/bin/health-check"]
        }
    }
    _result = deploy.build_deployment(_spec)
    _container = _result.spec.template.spec.containers[0]
    assert _container.readinessProbe.exec.command == ["/bin/health-check"]
}

# === Test: Deployment with TCP probe ===
test_build_deployment_tcp_probe = lambda {
    _spec = deploy.DeploymentSpec {
        name = "db"
        namespace = "infra"
        image = "img"
        version = "1.0"
        startupProbe = deploy.ProbeSpec {
            probeType = "tcp"
            port = 5432
        }
    }
    _result = deploy.build_deployment(_spec)
    _container = _result.spec.template.spec.containers[0]
    assert _container.startupProbe.tcpSocket.port == 5432
}

# === Test: Deployment with ConfigMap auto-wiring ===
test_build_deployment_configmap_autowiring = lambda {
    _spec = deploy.DeploymentSpec {
        name = "web"
        namespace = "apps"
        image = "img"
        version = "1.0"
        configMapRef = "my-config"
    }
    _result = deploy.build_deployment(_spec)
    _container = _result.spec.template.spec.containers[0]
    # Verify volume mount auto-created
    assert _container.volumeMounts[0].name == "application-configuration"
    assert _container.volumeMounts[0].mountPath == "/config/application.yaml"
    assert _container.volumeMounts[0].subPath == "application.yaml"
    # Verify volume auto-created
    assert _result.spec.template.spec.volumes[0].name == "application-configuration"
    assert _result.spec.template.spec.volumes[0].configMap.name == "my-config"
}

# === Test: Deployment with custom ConfigMap key ===
test_build_deployment_custom_configmap_key = lambda {
    _spec = deploy.DeploymentSpec {
        name = "web"
        namespace = "apps"
        image = "img"
        version = "1.0"
        configMapRef = "my-config"
        configMapKey = "config.properties"
        configMountPath = "/etc/app/config.properties"
    }
    _result = deploy.build_deployment(_spec)
    _container = _result.spec.template.spec.containers[0]
    assert _container.volumeMounts[0].mountPath == "/etc/app/config.properties"
    assert _container.volumeMounts[0].subPath == "config.properties"
}

# === Test: Deployment with serviceAccountName ===
test_build_deployment_service_account = lambda {
    _spec = deploy.DeploymentSpec {
        name = "web"
        namespace = "apps"
        image = "img"
        version = "1.0"
        serviceAccountName = "web-sa"
    }
    _result = deploy.build_deployment(_spec)
    assert _result.spec.template.spec.serviceAccountName == "web-sa"
}

# === Test: Deployment with command and args ===
test_build_deployment_command_args = lambda {
    _spec = deploy.DeploymentSpec {
        name = "worker"
        namespace = "apps"
        image = "img"
        version = "1.0"
        command = ["/bin/sh", "-c"]
        args = ["echo hello"]
    }
    _result = deploy.build_deployment(_spec)
    _container = _result.spec.template.spec.containers[0]
    assert _container.command == ["/bin/sh", "-c"]
    assert _container.args == ["echo hello"]
}

# === Test: Deployment with custom imagePullPolicy ===
test_build_deployment_image_pull_policy = lambda {
    _spec = deploy.DeploymentSpec {
        name = "web"
        namespace = "apps"
        image = "img"
        version = "1.0"
        imagePullPolicy = "Always"
    }
    _result = deploy.build_deployment(_spec)
    _container = _result.spec.template.spec.containers[0]
    assert _container.imagePullPolicy == "Always"
}

# === Test: Deployment with strategy and minReadySeconds ===
test_build_deployment_strategy = lambda {
    _spec = deploy.DeploymentSpec {
        name = "web"
        namespace = "apps"
        image = "img"
        version = "1.0"
        minReadySeconds = 30
        strategy = {
            $type = "RollingUpdate"
            rollingUpdate = {
                maxSurge = 1
                maxUnavailable = 0
            }
        }
    }
    _result = deploy.build_deployment(_spec)
    assert _result.spec.minReadySeconds == 30
    assert _result.spec.strategy.$type == "RollingUpdate"
}

# === Test: Deployment with ephemeral storage ===
test_build_deployment_ephemeral_storage = lambda {
    _spec = deploy.DeploymentSpec {
        name = "web"
        namespace = "apps"
        image = "img"
        version = "1.0"
        resources = deploy.ResourceSpec {
            ephemeralStorage = "5Gi"
        }
    }
    _result = deploy.build_deployment(_spec)
    _container = _result.spec.template.spec.containers[0]
    assert _container.resources.requests["ephemeral-storage"] == "5Gi"
    assert _container.resources.limits["ephemeral-storage"] == "5Gi"
}

# ====================================================================
# Validation Tests (check blocks) — TDD: these test check block errors
# ====================================================================

# === Test: Invalid port (too high) ===
test_deployment_invalid_port_high = lambda {
    _msg = runtime.catch(lambda {
        deploy.DeploymentSpec {
            name = "bad"
            namespace = "ns"
            image = "img"
            version = "1.0"
            port = 99999
        }
    })
    assert _msg == "port must be between 1 and 65535"
}

# === Test: Invalid port (zero) ===
test_deployment_invalid_port_zero = lambda {
    _msg = runtime.catch(lambda {
        deploy.DeploymentSpec {
            name = "bad"
            namespace = "ns"
            image = "img"
            version = "1.0"
            port = 0
        }
    })
    assert _msg == "port must be between 1 and 65535"
}

# === Test: Invalid replicas (zero) ===
test_deployment_invalid_replicas = lambda {
    _msg = runtime.catch(lambda {
        deploy.DeploymentSpec {
            name = "bad"
            namespace = "ns"
            image = "img"
            version = "1.0"
            replicas = 0
        }
    })
    assert _msg == "replicas must be at least 1"
}

# === Test: Valid port boundary (1) ===
test_deployment_valid_port_min = lambda {
    _spec = deploy.DeploymentSpec {
        name = "ok"
        namespace = "ns"
        image = "img"
        version = "1.0"
        port = 1
    }
    _result = deploy.build_deployment(_spec)
    assert _result.spec.template.spec.containers[0].ports[0].containerPort == 1
}

# === Test: Valid port boundary (65535) ===
test_deployment_valid_port_max = lambda {
    _spec = deploy.DeploymentSpec {
        name = "ok"
        namespace = "ns"
        image = "img"
        version = "1.0"
        port = 65535
    }
    _result = deploy.build_deployment(_spec)
    assert _result.spec.template.spec.containers[0].ports[0].containerPort == 65535
}
