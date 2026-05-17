"""
Kibana OSS Template — Kubernetes-native Kibana 7.10.2.

License note: this template pins the last Apache-2.0 Kibana OSS line and avoids
Elastic ECK because ECK is not an OSI-open-source operator.
"""

import builders.configmap as cm
import builders.leader as leader
import builders.pdb as pdb
import builders.service as svc
import models.modules.component as component

_DEFAULT_IMAGE = "docker.elastic.co/kibana/kibana-oss"
_DEFAULT_VERSION = "7.10.2"

schema KibanaResources:
    cpuRequest?: str = "250m"
    cpuLimit?: str = "1"
    memoryRequest?: str = "512Mi"
    memoryLimit?: str = "2Gi"

schema KibanaSpec:
    name: str
    namespace: str
    image?: str = _DEFAULT_IMAGE
    version?: str = _DEFAULT_VERSION
    replicas?: int = 2
    port?: int = 5601
    serviceType?: str = "ClusterIP"
    elasticsearchHosts: [str]
    serverBasePath?: str
    env?: [any]
    extraConfig?: {str:str}
    resources?: KibanaResources = KibanaResources {}
    minAvailable?: int | str = 1

    check:
        len(name) > 0, "Kibana name must not be empty"
        len(namespace) > 0, "Kibana namespace must not be empty"
        len(version) > 0, "Kibana image version must be pinned"
        "latest" not in version, "Kibana image version must not be latest"
        version == "7.10.2", "Kibana OSS template is pinned to the last Apache-2.0 OSS release: 7.10.2"
        replicas >= 1, "Kibana replicas must be >= 1"
        1 <= port <= 65535, "Kibana port must be between 1 and 65535"
        len(elasticsearchHosts) > 0, "elasticsearchHosts must not be empty"
        serviceType in ["ClusterIP", "NodePort", "LoadBalancer"], "serviceType must be ClusterIP, NodePort, or LoadBalancer"

_kibana_quote_list = lambda values: [str] -> str {
    "[" + ", ".join(["\"${value}\"" for value in values]) + "]"
}

_kibana_resource_requirements = lambda spec: KibanaResources -> any {
    {
        requests = {cpu = spec.cpuRequest, memory = spec.memoryRequest}
        limits = {cpu = spec.cpuLimit, memory = spec.memoryLimit}
    }
}

build_kibana_config = lambda spec: KibanaSpec -> str {
    _base = {
        "server.host" = "0.0.0.0"
        "server.port" = str(spec.port)
        "elasticsearch.hosts" = _kibana_quote_list(spec.elasticsearchHosts)
    }
    _base_path = {
        if spec.serverBasePath != Undefined:
            "server.basePath" = spec.serverBasePath
            "server.rewriteBasePath" = "true"
    }
    _config = _base | _base_path | (spec.extraConfig or {})
    "\n".join(["${key}: ${value}" for key, value in _config]) + "\n"
}

build_kibana_configmap = lambda spec: KibanaSpec -> any {
    cm.build_configmap(cm.ConfigMapSpec {name = "${spec.name}-config", namespace = spec.namespace, data = {"kibana.yml" = build_kibana_config(spec)}})
}

build_kibana_deployment = lambda spec: KibanaSpec -> any {
    {
        apiVersion = "apps/v1"
        kind = "Deployment"
        metadata = {name = spec.name, namespace = spec.namespace, labels = {app = spec.name, "app.kubernetes.io/component" = "kibana"}}
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
                        ports = [{name = "http", containerPort = spec.port}]
                        if spec.env:
                            env = spec.env
                        resources = _kibana_resource_requirements(spec.resources)
                        readinessProbe = {httpGet = {path = "/api/status", port = spec.port}, initialDelaySeconds = 30, periodSeconds = 10, timeoutSeconds = 5}
                        livenessProbe = {httpGet = {path = "/api/status", port = spec.port}, initialDelaySeconds = 90, periodSeconds = 20, timeoutSeconds = 5}
                        securityContext = {allowPrivilegeEscalation = False, capabilities = {drop = ["ALL"]}}
                        volumeMounts = [{name = "config", mountPath = "/usr/share/kibana/config/kibana.yml", subPath = "kibana.yml", readOnly = True}]
                    }]
                    volumes = [{name = "config", configMap = {name = "${spec.name}-config"}}]
                }
            }
        }
    }
}

build_kibana_service = lambda spec: KibanaSpec -> any {
    svc.build_service(svc.ServiceSpec {name = spec.name, namespace = spec.namespace, port = spec.port, targetPort = spec.port, serviceType = spec.serviceType, portName = "http"})
}

build_kibana_pdb = lambda spec: KibanaSpec -> any {
    pdb.build_pdb(pdb.PDBSpec {name = spec.name, namespace = spec.namespace, matchLabels = {app = spec.name}, minAvailable = spec.minAvailable})
}

build_kibana_resources = lambda spec: KibanaSpec -> [any] {
    _pdbs = [build_kibana_pdb(spec)] if spec.replicas > 1 else []
    [build_kibana_configmap(spec), build_kibana_service(spec), build_kibana_deployment(spec)] + _pdbs
}

schema KibanaModule(component.Component):
    """Component wrapper for Kibana OSS 7.10.2."""
    kind = "INFRASTRUCTURE"

    replicas?: int = 2
    port?: int = 5601
    serviceType?: str = "ClusterIP"
    elasticsearchHosts: [str]
    serverBasePath?: str
    env?: [any]
    extraConfig?: {str:str}
    resources?: KibanaResources = KibanaResources {}

    leaders = [leader.build_component_leader(name, namespace)]
    manifests = build_kibana_resources(KibanaSpec {
        name = name
        namespace = namespace
        image = asset.image if asset.image != Undefined else _DEFAULT_IMAGE
        version = asset.version
        replicas = replicas
        port = port
        serviceType = serviceType
        elasticsearchHosts = elasticsearchHosts
        serverBasePath = serverBasePath
        env = env
        extraConfig = extraConfig
        resources = resources
    })
