"""
Optional data admin UI companions.

These templates create lightweight native Kubernetes Deployments and Services for
visual administration tools that can be deployed next to data templates when a
site/profile needs them. They are opt-in and avoid hardcoded passwords by using
Secret references for sensitive values.
"""

import builders.deployment as deploy
import builders.service as svc
import builders.leader as leader
import models.modules.component as component
import models.modules.common as common
import templates.footprints.v1_0_0.footprint as fp

schema AdminUiResources:
    cpuRequest?: str = "50m"
    cpuLimit?: str = "500m"
    memoryRequest?: str = "128Mi"
    memoryLimit?: str = "512Mi"

_resource_spec = lambda spec: AdminUiResources, footprint: str -> deploy.ResourceSpec {
    _values = fp.resource_values(footprint, spec.cpuRequest, spec.cpuLimit, spec.memoryRequest, spec.memoryLimit)
    deploy.ResourceSpec {
        cpuRequest = _values.requests.cpu
        cpuLimit = _values.limits.cpu
        memoryRequest = _values.requests.memory
        memoryLimit = _values.limits.memory
    }
}

schema PgAdminSpec:
    name: str
    namespace: str
    footprint?: str = "development"
    image?: str = "dpage/pgadmin4"
    version?: str = "8.12"
    port?: int = 80
    serviceType?: str = "ClusterIP"
    adminEmail?: str = "admin@example.local"
    passwordSecretName: str
    passwordSecretKey?: str = "password"
    targetHost?: str
    resources?: AdminUiResources = AdminUiResources {}

    check:
        len(name) > 0, "pgAdmin name must not be empty"
        len(namespace) > 0, "pgAdmin namespace must not be empty"
        len(version) > 0 and "latest" not in version, "pgAdmin image version must be pinned and not latest"
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"
        1 <= port <= 65535, "pgAdmin port must be between 1 and 65535"
        len(passwordSecretName) > 0, "pgAdmin passwordSecretName must not be empty"

schema MongoExpressSpec:
    name: str
    namespace: str
    footprint?: str = "development"
    image?: str = "mongo-express"
    version?: str = "1.0.2-20"
    port?: int = 8081
    serviceType?: str = "ClusterIP"
    mongoHost: str
    mongoPort?: int = 27017
    mongoAuthDatabase?: str = "admin"
    mongoUsernameSecretName?: str
    mongoUsernameSecretKey?: str = "username"
    mongoPasswordSecretName?: str
    mongoPasswordSecretKey?: str = "password"
    basicAuthEnabled?: bool = True
    basicAuthUsernameSecretName?: str
    basicAuthUsernameSecretKey?: str = "username"
    basicAuthPasswordSecretName?: str
    basicAuthPasswordSecretKey?: str = "password"
    resources?: AdminUiResources = AdminUiResources {}

    check:
        len(name) > 0, "mongo-express name must not be empty"
        len(namespace) > 0, "mongo-express namespace must not be empty"
        len(version) > 0 and "latest" not in version, "mongo-express image version must be pinned and not latest"
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"
        1 <= port <= 65535, "mongo-express port must be between 1 and 65535"
        len(mongoHost) > 0, "mongoHost must not be empty"
        mongoUsernameSecretName is not Undefined and mongoPasswordSecretName is not Undefined if footprint == "production", "production mongo-express requires MongoDB credential Secret references"
        basicAuthUsernameSecretName is not Undefined and basicAuthPasswordSecretName is not Undefined if basicAuthEnabled and footprint in ["staging", "production"], "staging/production mongo-express basic auth requires Secret references"

schema RedisInsightSpec:
    name: str
    namespace: str
    footprint?: str = "development"
    image?: str = "redis/redisinsight"
    version?: str = "2.60"
    port?: int = 5540
    serviceType?: str = "ClusterIP"
    targetHost?: str
    targetPort?: int = 6379
    resources?: AdminUiResources = AdminUiResources {}

    check:
        len(name) > 0, "RedisInsight name must not be empty"
        len(namespace) > 0, "RedisInsight namespace must not be empty"
        len(version) > 0 and "latest" not in version, "RedisInsight image version must be pinned and not latest"
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"
        1 <= port <= 65535, "RedisInsight port must be between 1 and 65535"

_build_admin_deployment = lambda name: str, namespace: str, image: str, version: str, port: int, env: [any], resources: AdminUiResources, footprint: str -> any {
    deploy.build_deployment(deploy.DeploymentSpec {
        name = name
        namespace = namespace
        image = image
        version = version
        replicas = fp.replicas(footprint, 1, 1, 1, 2)
        port = port
        env = env
        resources = _resource_spec(resources, footprint)
        livenessProbe = deploy.ProbeSpec {probeType = "http", path = "/", port = port, initialDelaySeconds = 30, periodSeconds = 10}
        readinessProbe = deploy.ProbeSpec {probeType = "http", path = "/", port = port, initialDelaySeconds = 10, periodSeconds = 5}
    })
}

_build_admin_service = lambda name: str, namespace: str, port: int, serviceType: str -> any {
    svc.build_service(svc.ServiceSpec {
        name = name
        namespace = namespace
        port = port
        targetPort = port
        serviceType = serviceType
        portName = "http"
    })
}

build_pgadmin_resources = lambda spec: PgAdminSpec -> [any] {
    _env: [any] = [
        common.EnvVar {name = "PGADMIN_DEFAULT_EMAIL", value = spec.adminEmail}
        common.EnvVar {name = "PGADMIN_DEFAULT_PASSWORD", valueFrom = common.EnvVarSource {secretKeyRef = common.KeySelector {name = spec.passwordSecretName, key = spec.passwordSecretKey}}}
    ] + ([common.EnvVar {name = "PGADMIN_CONFIG_SERVER_MODE", value = "False"}] if spec.footprint in ["local", "development"] else []) + ([common.EnvVar {name = "PGADMIN_DEFAULT_SERVER", value = spec.targetHost}] if spec.targetHost else [])
    [
        _build_admin_deployment(spec.name, spec.namespace, spec.image, spec.version, spec.port, _env, spec.resources, spec.footprint)
        _build_admin_service(spec.name, spec.namespace, spec.port, spec.serviceType)
    ]
}

build_mongo_express_resources = lambda spec: MongoExpressSpec -> [any] {
    _mongo_env: [any] = [
        common.EnvVar {name = "ME_CONFIG_MONGODB_SERVER", value = spec.mongoHost}
        common.EnvVar {name = "ME_CONFIG_MONGODB_PORT", value = str(spec.mongoPort)}
        common.EnvVar {name = "ME_CONFIG_MONGODB_AUTH_DATABASE", value = spec.mongoAuthDatabase}
    ] + ([common.EnvVar {name = "ME_CONFIG_MONGODB_ADMINUSERNAME", valueFrom = common.EnvVarSource {secretKeyRef = common.KeySelector {name = spec.mongoUsernameSecretName, key = spec.mongoUsernameSecretKey}}}] if spec.mongoUsernameSecretName else []) + ([common.EnvVar {name = "ME_CONFIG_MONGODB_ADMINPASSWORD", valueFrom = common.EnvVarSource {secretKeyRef = common.KeySelector {name = spec.mongoPasswordSecretName, key = spec.mongoPasswordSecretKey}}}] if spec.mongoPasswordSecretName else [])
    _basic_auth_env: [any] = [common.EnvVar {name = "ME_CONFIG_BASICAUTH", value = "false"}] if not spec.basicAuthEnabled else ([
        common.EnvVar {name = "ME_CONFIG_BASICAUTH_USERNAME", valueFrom = common.EnvVarSource {secretKeyRef = common.KeySelector {name = spec.basicAuthUsernameSecretName, key = spec.basicAuthUsernameSecretKey}}}
        common.EnvVar {name = "ME_CONFIG_BASICAUTH_PASSWORD", valueFrom = common.EnvVarSource {secretKeyRef = common.KeySelector {name = spec.basicAuthPasswordSecretName, key = spec.basicAuthPasswordSecretKey}}}
    ] if spec.basicAuthUsernameSecretName and spec.basicAuthPasswordSecretName else [])
    [
        _build_admin_deployment(spec.name, spec.namespace, spec.image, spec.version, spec.port, _mongo_env + _basic_auth_env, spec.resources, spec.footprint)
        _build_admin_service(spec.name, spec.namespace, spec.port, spec.serviceType)
    ]
}

build_redis_insight_resources = lambda spec: RedisInsightSpec -> [any] {
    _target_env: [any] = ([common.EnvVar {name = "RI_REDIS_HOST", value = spec.targetHost}, common.EnvVar {name = "RI_REDIS_PORT", value = str(spec.targetPort)}] if spec.targetHost else [])
    [
        _build_admin_deployment(spec.name, spec.namespace, spec.image, spec.version, spec.port, _target_env, spec.resources, spec.footprint)
        _build_admin_service(spec.name, spec.namespace, spec.port, spec.serviceType)
    ]
}

schema PgAdminModule(component.Component):
    kind = "INFRASTRUCTURE"
    adminEmail?: str = "admin@example.local"
    passwordSecretName: str
    passwordSecretKey?: str = "password"
    footprint?: str = "development"
    port?: int = 80
    serviceType?: str = "ClusterIP"
    targetHost?: str
    resources?: AdminUiResources = AdminUiResources {}
    leaders = [leader.build_component_leader(name, namespace)]
    manifests = build_pgadmin_resources(PgAdminSpec {name = name, namespace = namespace, image = asset.image if asset.image != Undefined else "dpage/pgadmin4", version = asset.version, adminEmail = adminEmail, passwordSecretName = passwordSecretName, passwordSecretKey = passwordSecretKey, footprint = footprint, port = port, serviceType = serviceType, targetHost = targetHost, resources = resources})

schema MongoExpressModule(component.Component):
    kind = "INFRASTRUCTURE"
    footprint?: str = "development"
    port?: int = 8081
    serviceType?: str = "ClusterIP"
    mongoHost: str
    mongoPort?: int = 27017
    mongoAuthDatabase?: str = "admin"
    mongoUsernameSecretName?: str
    mongoUsernameSecretKey?: str = "username"
    mongoPasswordSecretName?: str
    mongoPasswordSecretKey?: str = "password"
    basicAuthEnabled?: bool = True
    basicAuthUsernameSecretName?: str
    basicAuthUsernameSecretKey?: str = "username"
    basicAuthPasswordSecretName?: str
    basicAuthPasswordSecretKey?: str = "password"
    resources?: AdminUiResources = AdminUiResources {}
    leaders = [leader.build_component_leader(name, namespace)]
    manifests = build_mongo_express_resources(MongoExpressSpec {name = name, namespace = namespace, image = asset.image if asset.image != Undefined else "mongo-express", version = asset.version, footprint = footprint, port = port, serviceType = serviceType, mongoHost = mongoHost, mongoPort = mongoPort, mongoAuthDatabase = mongoAuthDatabase, mongoUsernameSecretName = mongoUsernameSecretName, mongoUsernameSecretKey = mongoUsernameSecretKey, mongoPasswordSecretName = mongoPasswordSecretName, mongoPasswordSecretKey = mongoPasswordSecretKey, basicAuthEnabled = basicAuthEnabled, basicAuthUsernameSecretName = basicAuthUsernameSecretName, basicAuthUsernameSecretKey = basicAuthUsernameSecretKey, basicAuthPasswordSecretName = basicAuthPasswordSecretName, basicAuthPasswordSecretKey = basicAuthPasswordSecretKey, resources = resources})

schema RedisInsightModule(component.Component):
    kind = "INFRASTRUCTURE"
    footprint?: str = "development"
    port?: int = 5540
    serviceType?: str = "ClusterIP"
    targetHost?: str
    targetPort?: int = 6379
    resources?: AdminUiResources = AdminUiResources {}
    leaders = [leader.build_component_leader(name, namespace)]
    manifests = build_redis_insight_resources(RedisInsightSpec {name = name, namespace = namespace, image = asset.image if asset.image != Undefined else "redis/redisinsight", version = asset.version, footprint = footprint, port = port, serviceType = serviceType, targetHost = targetHost, targetPort = targetPort, resources = resources})
