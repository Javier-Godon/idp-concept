"""
Fluent Bit v3.2.10 native Kubernetes templates.

Deployment modes in this file use only built-in Kubernetes resources:
- single instance: ConfigMap + Deployment + Service + optional PDB
- daemonset: ConfigMap + DaemonSet + Service
"""

import builders.configmap as cm
import builders.leader as leader
import builders.pdb as pdb
import builders.service as svc
import models.modules.component as component
import templates.observability.v1_0_0.telemetry_config as telemetry

_DEFAULT_IMAGE = "cr.fluentbit.io/fluent/fluent-bit"
_DEFAULT_VERSION = "3.2.10"
_DEFAULT_HTTP_PORT = 2020

schema FluentBitResources:
    cpuRequest?: str = "100m"
    cpuLimit?: str = "500m"
    memoryRequest?: str = "128Mi"
    memoryLimit?: str = "512Mi"

schema FluentBitNativeSpec:
    name: str
    namespace: str
    image?: str = _DEFAULT_IMAGE
    version?: str = _DEFAULT_VERSION
    mode?: str = "deployment"
    replicas?: int = 1
    metricsPort?: int = _DEFAULT_HTTP_PORT
    serviceType?: str = "ClusterIP"
    pipeline?: telemetry.LogPipelineSpec = telemetry.LogPipelineSpec {}
    configData?: {str:str}
    env?: [any]
    resources?: FluentBitResources = FluentBitResources {}
    minAvailable?: int | str = 1
    mountHostLogs?: bool = False

    check:
        len(name) > 0, "Fluent Bit name must not be empty"
        len(namespace) > 0, "Fluent Bit namespace must not be empty"
        len(version) > 0, "Fluent Bit image version must be pinned"
        "latest" not in version, "Fluent Bit image version must not be latest"
        mode in ["deployment", "daemonset"], "mode must be deployment or daemonset"
        replicas >= 1 if mode == "deployment", "replicas must be at least 1 for deployment mode"
        1 <= metricsPort <= 65535, "metricsPort must be between 1 and 65535"
        serviceType in ["ClusterIP", "NodePort", "LoadBalancer"], "serviceType must be ClusterIP, NodePort, or LoadBalancer"

_resource_requirements = lambda spec: FluentBitResources -> any {
    {
        requests = {cpu = spec.cpuRequest, memory = spec.memoryRequest}
        limits = {cpu = spec.cpuLimit, memory = spec.memoryLimit}
    }
}

_config_data = lambda spec: FluentBitNativeSpec -> {str:str} {
    spec.configData or telemetry.build_fluentbit_classic_config(spec.pipeline)
}

build_fluentbit_configmap = lambda spec: FluentBitNativeSpec -> any {
    cm.build_configmap(cm.ConfigMapSpec {
        name = "${spec.name}-config"
        namespace = spec.namespace
        data = _config_data(spec)
    })
}

_container = lambda spec: FluentBitNativeSpec -> any {
    {
        name = "fluent-bit"
        image = "${spec.image}:${spec.version}"
        imagePullPolicy = "IfNotPresent"
        args = ["-c", "/fluent-bit/etc/fluent-bit.conf"]
        ports = [{name = "http", containerPort = spec.metricsPort}]
        if spec.env:
            env = spec.env
        resources = _resource_requirements(spec.resources)
        readinessProbe = {httpGet = {path = "/api/v1/health", port = spec.metricsPort}, initialDelaySeconds = 5, periodSeconds = 10, timeoutSeconds = 3}
        livenessProbe = {httpGet = {path = "/api/v1/health", port = spec.metricsPort}, initialDelaySeconds = 15, periodSeconds = 20, timeoutSeconds = 3}
        securityContext = {
            allowPrivilegeEscalation = False
            capabilities = {drop = ["ALL"]}
        }
        volumeMounts = [
            {name = "config", mountPath = "/fluent-bit/etc/fluent-bit.conf", subPath = "fluent-bit.conf", readOnly = True}
            {name = "config", mountPath = "/fluent-bit/etc/parsers.conf", subPath = "parsers.conf", readOnly = True}
        ] + ([{name = "varlog", mountPath = "/var/log", readOnly = True}] if spec.mountHostLogs else [])
    }
}

_pod_spec = lambda spec: FluentBitNativeSpec -> any {
    {
        securityContext = {
            runAsNonRoot = True
            runAsUser = 1000
            runAsGroup = 1000
            fsGroup = 1000
            seccompProfile = {$type = "RuntimeDefault"}
        }
        containers = [_container(spec)]
        volumes = [{name = "config", configMap = {name = "${spec.name}-config"}}] + ([{name = "varlog", hostPath = {path = "/var/log", $type = "Directory"}}] if spec.mountHostLogs else [])
    }
}

build_fluentbit_deployment = lambda spec: FluentBitNativeSpec -> any {
    {
        apiVersion = "apps/v1"
        kind = "Deployment"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {app = spec.name, "app.kubernetes.io/name" = spec.name, "app.kubernetes.io/component" = "fluent-bit", "app.kubernetes.io/managed-by" = "idp-concept"}
        }
        spec = {
            replicas = spec.replicas
            selector = {matchLabels = {app = spec.name}}
            template = {
                metadata = {labels = {app = spec.name}}
                spec = _pod_spec(spec)
            }
        }
    }
}

build_fluentbit_daemonset = lambda spec: FluentBitNativeSpec -> any {
    {
        apiVersion = "apps/v1"
        kind = "DaemonSet"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {app = spec.name, "app.kubernetes.io/name" = spec.name, "app.kubernetes.io/component" = "fluent-bit", "app.kubernetes.io/managed-by" = "idp-concept"}
        }
        spec = {
            selector = {matchLabels = {app = spec.name}}
            template = {
                metadata = {labels = {app = spec.name}}
                spec = _pod_spec(spec)
            }
        }
    }
}

build_fluentbit_service = lambda spec: FluentBitNativeSpec -> any {
    svc.build_service(svc.ServiceSpec {
        name = spec.name
        namespace = spec.namespace
        port = spec.metricsPort
        targetPort = spec.metricsPort
        serviceType = spec.serviceType
        portName = "http"
    })
}

build_fluentbit_pdb = lambda spec: FluentBitNativeSpec -> any {
    pdb.build_pdb(pdb.PDBSpec {
        name = spec.name
        namespace = spec.namespace
        matchLabels = {app = spec.name}
        minAvailable = spec.minAvailable
    })
}

build_fluentbit_resources = lambda spec: FluentBitNativeSpec -> [any] {
    _workload = build_fluentbit_deployment(spec) if spec.mode == "deployment" else build_fluentbit_daemonset(spec)
    _pdbs = [build_fluentbit_pdb(spec)] if spec.mode == "deployment" and spec.replicas > 1 else []
    [build_fluentbit_configmap(spec), build_fluentbit_service(spec), _workload] + _pdbs
}

schema FluentBitSingleInstanceModule(component.Component):
    kind = "INFRASTRUCTURE"

    replicas?: int = 1
    metricsPort?: int = _DEFAULT_HTTP_PORT
    serviceType?: str = "ClusterIP"
    pipeline?: telemetry.LogPipelineSpec = telemetry.LogPipelineSpec {}
    configData?: {str:str}
    env?: [any]
    resources?: FluentBitResources = FluentBitResources {}

    leaders = [leader.build_component_leader(name, namespace)]

    manifests = build_fluentbit_resources(FluentBitNativeSpec {
        name = name
        namespace = namespace
        image = asset.image if asset.image != Undefined else _DEFAULT_IMAGE
        version = asset.version
        mode = "deployment"
        replicas = replicas
        metricsPort = metricsPort
        serviceType = serviceType
        pipeline = pipeline
        configData = configData
        env = env
        resources = resources
    })

schema FluentBitDaemonSetModule(component.Component):
    kind = "INFRASTRUCTURE"

    metricsPort?: int = _DEFAULT_HTTP_PORT
    serviceType?: str = "ClusterIP"
    pipeline?: telemetry.LogPipelineSpec = telemetry.LogPipelineSpec {
        input = "tail"
    }
    configData?: {str:str}
    env?: [any]
    resources?: FluentBitResources = FluentBitResources {}
    mountHostLogs?: bool = True

    leaders = [leader.build_component_leader(name, namespace, "DaemonSet", "apps/v1")]

    manifests = build_fluentbit_resources(FluentBitNativeSpec {
        name = name
        namespace = namespace
        image = asset.image if asset.image != Undefined else _DEFAULT_IMAGE
        version = asset.version
        mode = "daemonset"
        metricsPort = metricsPort
        serviceType = serviceType
        pipeline = pipeline
        configData = configData
        env = env
        resources = resources
        mountHostLogs = mountHostLogs
    })
