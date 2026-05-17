"""
Logstash OSS Template — Kubernetes-native Logstash 7.10.2.

License note: this template pins the last Apache-2.0 Logstash OSS line and avoids
Elastic ECK because ECK is not an OSI-open-source operator.
"""

import builders.configmap as cm
import builders.leader as leader
import builders.pdb as pdb
import builders.service as svc
import models.modules.component as component

_DEFAULT_IMAGE = "docker.elastic.co/logstash/logstash-oss"
_DEFAULT_VERSION = "7.10.2"

schema LogstashResources:
    cpuRequest?: str = "500m"
    cpuLimit?: str = "2"
    memoryRequest?: str = "1Gi"
    memoryLimit?: str = "4Gi"

schema LogstashSpec:
    name: str
    namespace: str
    image?: str = _DEFAULT_IMAGE
    version?: str = _DEFAULT_VERSION
    replicas?: int = 2
    beatsPort?: int = 5044
    monitoringPort?: int = 9600
    serviceType?: str = "ClusterIP"
    pipelineConfig: str
    logstashConfig?: str = "http.host: 0.0.0.0\n"
    pipelinesConfig?: str = "- pipeline.id: main\n  path.config: /usr/share/logstash/pipeline/logstash.conf\n"
    javaOpts?: str = "-Xms1g -Xmx1g"
    env?: [any]
    resources?: LogstashResources = LogstashResources {}
    minAvailable?: int | str = 1

    check:
        len(name) > 0, "Logstash name must not be empty"
        len(namespace) > 0, "Logstash namespace must not be empty"
        len(version) > 0, "Logstash image version must be pinned"
        "latest" not in version, "Logstash image version must not be latest"
        version == "7.10.2", "Logstash OSS template is pinned to the last Apache-2.0 OSS release: 7.10.2"
        replicas >= 1, "Logstash replicas must be >= 1"
        1 <= beatsPort <= 65535, "beatsPort must be between 1 and 65535"
        1 <= monitoringPort <= 65535, "monitoringPort must be between 1 and 65535"
        serviceType in ["ClusterIP", "NodePort", "LoadBalancer"], "serviceType must be ClusterIP, NodePort, or LoadBalancer"
        len(pipelineConfig) > 0, "Logstash pipelineConfig must not be empty"

_logstash_resource_requirements = lambda spec: LogstashResources -> any {
    {
        requests = {cpu = spec.cpuRequest, memory = spec.memoryRequest}
        limits = {cpu = spec.cpuLimit, memory = spec.memoryLimit}
    }
}

build_logstash_configmap = lambda spec: LogstashSpec -> any {
    cm.build_configmap(cm.ConfigMapSpec {
        name = "${spec.name}-config"
        namespace = spec.namespace
        data = {
            "logstash.conf" = spec.pipelineConfig
            "logstash.yml" = spec.logstashConfig
            "pipelines.yml" = spec.pipelinesConfig
        }
    })
}

build_logstash_deployment = lambda spec: LogstashSpec -> any {
    {
        apiVersion = "apps/v1"
        kind = "Deployment"
        metadata = {name = spec.name, namespace = spec.namespace, labels = {app = spec.name, "app.kubernetes.io/component" = "logstash"}}
        spec = {
            replicas = spec.replicas
            strategy = {$type = "RollingUpdate", rollingUpdate = {maxUnavailable = 1, maxSurge = 1}}
            selector = {matchLabels = {app = spec.name}}
            template = {
                metadata = {labels = {app = spec.name}}
                spec = {
                    securityContext = {runAsNonRoot = True, runAsUser = 1000, runAsGroup = 1000, fsGroup = 1000, seccompProfile = {$type = "RuntimeDefault"}}
                    containers = [{
                        name = spec.name
                        image = "${spec.image}:${spec.version}"
                        imagePullPolicy = "IfNotPresent"
                        ports = [{name = "beats", containerPort = spec.beatsPort}, {name = "monitoring", containerPort = spec.monitoringPort}]
                        env = [{name = "LS_JAVA_OPTS", value = spec.javaOpts}] + (spec.env or [])
                        resources = _logstash_resource_requirements(spec.resources)
                        readinessProbe = {httpGet = {path = "/", port = spec.monitoringPort}, initialDelaySeconds = 30, periodSeconds = 10, timeoutSeconds = 5}
                        livenessProbe = {httpGet = {path = "/", port = spec.monitoringPort}, initialDelaySeconds = 90, periodSeconds = 20, timeoutSeconds = 5}
                        securityContext = {allowPrivilegeEscalation = False, capabilities = {drop = ["ALL"]}}
                        volumeMounts = [
                            {name = "config", mountPath = "/usr/share/logstash/config/logstash.yml", subPath = "logstash.yml", readOnly = True}
                            {name = "config", mountPath = "/usr/share/logstash/config/pipelines.yml", subPath = "pipelines.yml", readOnly = True}
                            {name = "config", mountPath = "/usr/share/logstash/pipeline/logstash.conf", subPath = "logstash.conf", readOnly = True}
                        ]
                    }]
                    volumes = [{name = "config", configMap = {name = "${spec.name}-config"}}]
                }
            }
        }
    }
}

build_logstash_service = lambda spec: LogstashSpec -> any {
    svc.build_service(svc.ServiceSpec {name = spec.name, namespace = spec.namespace, port = spec.beatsPort, targetPort = spec.beatsPort, serviceType = spec.serviceType, portName = "beats"})
}

build_logstash_pdb = lambda spec: LogstashSpec -> any {
    pdb.build_pdb(pdb.PDBSpec {name = spec.name, namespace = spec.namespace, matchLabels = {app = spec.name}, minAvailable = spec.minAvailable})
}

build_logstash_resources = lambda spec: LogstashSpec -> [any] {
    _pdbs = [build_logstash_pdb(spec)] if spec.replicas > 1 else []
    [build_logstash_configmap(spec), build_logstash_service(spec), build_logstash_deployment(spec)] + _pdbs
}

schema LogstashModule(component.Component):
    """Component wrapper for Logstash OSS 7.10.2."""
    kind = "INFRASTRUCTURE"

    replicas?: int = 2
    beatsPort?: int = 5044
    monitoringPort?: int = 9600
    serviceType?: str = "ClusterIP"
    pipelineConfig: str
    logstashConfig?: str = "http.host: 0.0.0.0\n"
    pipelinesConfig?: str = "- pipeline.id: main\n  path.config: /usr/share/logstash/pipeline/logstash.conf\n"
    javaOpts?: str = "-Xms1g -Xmx1g"
    env?: [any]
    resources?: LogstashResources = LogstashResources {}

    leaders = [leader.build_component_leader(name, namespace)]
    manifests = build_logstash_resources(LogstashSpec {
        name = name
        namespace = namespace
        image = asset.image if asset.image != Undefined else _DEFAULT_IMAGE
        version = asset.version
        replicas = replicas
        beatsPort = beatsPort
        monitoringPort = monitoringPort
        serviceType = serviceType
        pipelineConfig = pipelineConfig
        logstashConfig = logstashConfig
        pipelinesConfig = pipelinesConfig
        javaOpts = javaOpts
        env = env
        resources = resources
    })
