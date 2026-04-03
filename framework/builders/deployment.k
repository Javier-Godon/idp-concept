"""
Deployment Builder — generates a Kubernetes Deployment from a high-level spec.
Eliminates ~80 lines of boilerplate per module.
"""
import k8s.api.apps.v1 as apps

schema DeploymentSpec:
    name: str
    namespace: str
    image: str
    version: str
    replicas?: int = 1
    port?: int
    command?: [str]
    args?: [str]
    env?: [any]
    configMapRef?: str
    configMapKey?: str = "application.yaml"
    configMountPath?: str = "/config/application.yaml"
    resources?: ResourceSpec
    livenessProbe?: ProbeSpec
    readinessProbe?: ProbeSpec
    startupProbe?: ProbeSpec
    serviceAccountName?: str
    imagePullPolicy?: str = "IfNotPresent"
    volumes?: [any]
    volumeMounts?: [any]
    strategy?: any
    minReadySeconds?: int
    annotations?: {str:str}

    check:
        1 <= port <= 65535 if port is not Undefined, "port must be between 1 and 65535"
        replicas >= 1 if replicas is not Undefined, "replicas must be at least 1"

schema ResourceSpec:
    cpuRequest?: str = "250m"
    cpuLimit?: str = "1"
    memoryRequest?: str = "512Mi"
    memoryLimit?: str = "2Gi"
    ephemeralStorage?: str

schema ProbeSpec:
    probeType?: str = "exec"
    path?: str
    port?: int
    command?: [str] = ["/bin/sh", "-c", "echo ok"]
    initialDelaySeconds?: int = 30
    periodSeconds?: int = 5
    failureThreshold?: int = 3
    successThreshold?: int = 1
    timeoutSeconds?: int = 10

_build_probe = lambda spec: ProbeSpec -> any {
    _probe = {
        if spec.probeType == "exec":
            exec = {
                command = spec.command
            }
        if spec.probeType == "http":
            httpGet = {
                path = spec.path
                port = spec.port
            }
        if spec.probeType == "tcp":
            tcpSocket = {
                port = spec.port
            }
        failureThreshold = spec.failureThreshold
        initialDelaySeconds = spec.initialDelaySeconds
        periodSeconds = spec.periodSeconds
        successThreshold = spec.successThreshold
        timeoutSeconds = spec.timeoutSeconds
    }
}

_build_resources = lambda spec: ResourceSpec -> any {
    _res = {
        limits = {
            cpu = spec.cpuLimit
            memory = spec.memoryLimit
            if spec.ephemeralStorage:
                "ephemeral-storage" = spec.ephemeralStorage
        }
        requests = {
            cpu = spec.cpuRequest
            memory = spec.memoryRequest
            if spec.ephemeralStorage:
                "ephemeral-storage" = spec.ephemeralStorage
        }
    }
}

_compute_volumes = lambda spec: DeploymentSpec -> [any] {
    _vols = spec.volumes if spec.volumes else []
    if spec.configMapRef and not spec.volumes:
        _vols = [{
            configMap = {
                name = spec.configMapRef
                items = [{
                    key = spec.configMapKey
                    path = spec.configMapKey
                }]
            }
            name = "application-configuration"
        }]
    _vols
}

_compute_volume_mounts = lambda spec: DeploymentSpec -> [any] {
    _mounts = spec.volumeMounts if spec.volumeMounts else []
    if spec.configMapRef and not spec.volumeMounts:
        _mounts = [{
            mountPath = spec.configMountPath
            name = "application-configuration"
            subPath = spec.configMapKey
        }]
    _mounts
}

build_deployment = lambda spec: DeploymentSpec -> apps.Deployment {
    _volumes = _compute_volumes(spec)
    _volume_mounts = _compute_volume_mounts(spec)
    _container = {
        name = spec.name
        image = "${spec.image}:${spec.version}"
        imagePullPolicy = spec.imagePullPolicy
        if spec.port:
            ports = [{
                containerPort = spec.port
            }]
        if spec.command:
            command = spec.command
        if spec.args:
            args = spec.args
        if spec.env:
            env = spec.env
        if spec.livenessProbe:
            livenessProbe = _build_probe(spec.livenessProbe)
        if spec.readinessProbe:
            readinessProbe = _build_probe(spec.readinessProbe)
        if spec.startupProbe:
            startupProbe = _build_probe(spec.startupProbe)
        if spec.resources:
            resources = _build_resources(spec.resources)
        if _volume_mounts:
            volumeMounts = _volume_mounts
    }
    apps.Deployment {
        apiVersion = "apps/v1"
        kind = "Deployment"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            if spec.annotations:
                annotations = spec.annotations
        }
        spec = {
            replicas = spec.replicas
            if spec.minReadySeconds:
                minReadySeconds = spec.minReadySeconds
            if spec.strategy:
                strategy = spec.strategy
            selector = {
                matchLabels = {
                    app = spec.name
                }
            }
            template = {
                metadata = {
                    labels = {
                        app = spec.name
                    }
                }
                spec = {
                    containers = [_container]
                    if spec.serviceAccountName:
                        serviceAccountName = spec.serviceAccountName
                    if _volumes:
                        volumes = _volumes
                }
            }
        }
    }
}
