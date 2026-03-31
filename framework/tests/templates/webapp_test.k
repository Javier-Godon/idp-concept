"""
WebApp Template Integration Tests.

NOTE: kcl test has a known bug where schemas with auto-computed `instance` fields
(like Component/Accessory) fail when the instance references fields computed from
lambdas. The `instance` default evaluates before child schema's private computed
fields are resolved, causing UndefinedType errors. (Works fine with `kcl run`.)

Workaround: Test the individual builder outputs that WebAppModule composes.
Template integration is validated via `kcl run` in the CI pipeline and erp_back project.
"""
import builders.deployment as deploy
import builders.service as svc
import builders.configmap as cm
import builders.service_account as sa
import builders.leader as leader

# === Test: WebAppModule composed parts - Deployment ===
test_webapp_deployment_output = lambda {
    _result = deploy.build_deployment(deploy.DeploymentSpec {
        name = "api"
        namespace = "apps"
        image = "myregistry/api"
        version = "2.0.0"
        port = 8080
        replicas = 3
        imagePullPolicy = "IfNotPresent"
    })
    assert _result.kind == "Deployment"
    assert _result.spec.replicas == 3
    _container = _result.spec.template.spec.containers[0]
    assert _container.image == "myregistry/api:2.0.0"
    assert _container.imagePullPolicy == "IfNotPresent"
    assert _container.ports[0].containerPort == 8080
}

# === Test: WebAppModule composed parts - Service ===
test_webapp_service_output = lambda {
    _result = svc.build_service(svc.ServiceSpec {
        name = "api"
        namespace = "apps"
        port = 8080
        serviceType = "NodePort"
        nodePort = 30080
    })
    assert _result.kind == "Service"
    assert _result.spec.$type == "NodePort"
    assert _result.spec.ports[0].nodePort == 30080
    assert _result.spec.ports[0].port == 8080
}

# === Test: WebAppModule composed parts - ConfigMap ===
test_webapp_configmap_output = lambda {
    _result = cm.build_configmap(cm.ConfigMapSpec {
        name = "api-configmap"
        namespace = "apps"
        data = { "application.yaml" = "server.port: 8080" }
    })
    assert _result.kind == "ConfigMap"
    assert _result.metadata.name == "api-configmap"
    assert _result.data["application.yaml"] == "server.port: 8080"
}

# === Test: WebAppModule composed parts - ServiceAccount ===
test_webapp_sa_output = lambda {
    _result = sa.build_service_account(sa.ServiceAccountSpec {
        name = "api-sa"
        namespace = "apps"
        imagePullSecretName = "registry-creds"
    })
    assert _result.kind == "ServiceAccount"
    assert _result.metadata.name == "api-sa"
    assert _result.imagePullSecrets[0].name == "registry-creds"
}

# === Test: WebAppModule leader builder ===
test_webapp_leader = lambda {
    _result = leader.build_component_leader("api", "apps")
    assert _result.name == "api"
    assert _result.kind == "Deployment"
    assert _result.apiVersion == "apps/v1"
    assert _result.namespace == "apps"
}

# === Test: WebApp Deployment with configMap auto-wiring ===
test_webapp_deployment_with_configmap_ref = lambda {
    _result = deploy.build_deployment(deploy.DeploymentSpec {
        name = "api"
        namespace = "apps"
        image = "myregistry/api"
        version = "1.0.0"
        port = 8080
        configMapRef = "api-configmap"
        configMapKey = "application.yaml"
        configMountPath = "/config/application.yaml"
    })
    _container = _result.spec.template.spec.containers[0]
    # Check configMap volume mount was auto-wired
    assert _container.volumeMounts[0].name == "application-configuration"
    assert _container.volumeMounts[0].mountPath == "/config/application.yaml"
    assert _container.volumeMounts[0].subPath == "application.yaml"
}

# === Test: WebApp Deployment with probes ===
test_webapp_deployment_with_probes = lambda {
    _result = deploy.build_deployment(deploy.DeploymentSpec {
        name = "api"
        namespace = "apps"
        image = "myregistry/api"
        version = "1.0.0"
        port = 8080
        livenessProbe = deploy.ProbeSpec {
            probeType = "http"
            path = "/actuator/health/liveness"
            port = 8080
            initialDelaySeconds = 60
            periodSeconds = 10
        }
        readinessProbe = deploy.ProbeSpec {
            probeType = "http"
            path = "/actuator/health/readiness"
            port = 8080
            initialDelaySeconds = 30
            periodSeconds = 5
        }
    })
    _container = _result.spec.template.spec.containers[0]
    assert _container.livenessProbe.httpGet.path == "/actuator/health/liveness"
    assert _container.readinessProbe.httpGet.path == "/actuator/health/readiness"
}

# === Test: WebApp Deployment with env vars ===
test_webapp_deployment_with_env = lambda {
    _result = deploy.build_deployment(deploy.DeploymentSpec {
        name = "api"
        namespace = "apps"
        image = "myregistry/api"
        version = "1.0.0"
        port = 8080
        env = [
            { name = "SPRING_PROFILES_ACTIVE", value = "dev" }
            { name = "DB_PASSWORD", valueFrom = { secretKeyRef = { name = "db-creds", key = "password" } } }
        ]
    })
    _container = _result.spec.template.spec.containers[0]
    assert _container.env[0].name == "SPRING_PROFILES_ACTIVE"
    assert _container.env[0].value == "dev"
    assert _container.env[1].name == "DB_PASSWORD"
}
