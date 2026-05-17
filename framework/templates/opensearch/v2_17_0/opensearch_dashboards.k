"""
OpenSearch Dashboards Template — standalone Dashboards deployment.

For clusters managed by opensearch-k8s-operator, prefer the integrated
`dashboards` section in `templates/opensearch.k`. This standalone template is
useful when Dashboards must be managed separately from the OpenSearch cluster.
"""

import builders.configmap as cm
import builders.leader as leader
import builders.pdb as pdb
import builders.service as svc
import models.modules.component as component

_DEFAULT_IMAGE = "opensearchproject/opensearch-dashboards"
_DEFAULT_VERSION = "2.17.0"

schema OpenSearchDashboardsResources:
    cpuRequest?: str = "250m"
    cpuLimit?: str = "1"
    memoryRequest?: str = "512Mi"
    memoryLimit?: str = "2Gi"

schema OpenSearchDashboardsSpec:
    name: str
    namespace: str
    image?: str = _DEFAULT_IMAGE
    version?: str = _DEFAULT_VERSION
    replicas?: int = 2
    port?: int = 5601
    serviceType?: str = "ClusterIP"
    opensearchHosts: [str]
    serverBasePath?: str
    env?: [any]
    extraConfig?: {str:str}
    resources?: OpenSearchDashboardsResources = OpenSearchDashboardsResources {}
    minAvailable?: int | str = 1

    check:
        len(name) > 0, "OpenSearch Dashboards name must not be empty"
        len(namespace) > 0, "OpenSearch Dashboards namespace must not be empty"
        len(version) > 0, "OpenSearch Dashboards image version must be pinned"
        "latest" not in version, "OpenSearch Dashboards image version must not be latest"
        replicas >= 1, "OpenSearch Dashboards replicas must be >= 1"
        1 <= port <= 65535, "OpenSearch Dashboards port must be between 1 and 65535"
        len(opensearchHosts) > 0, "opensearchHosts must not be empty"
        serviceType in ["ClusterIP", "NodePort", "LoadBalancer"], "serviceType must be ClusterIP, NodePort, or LoadBalancer"

_quote_list = lambda values: [str] -> str {
    "[" + ", ".join(["\"${value}\"" for value in values]) + "]"
}

_opensearch_dashboards_resource_requirements = lambda spec: OpenSearchDashboardsResources -> any {
    {
        requests = {cpu = spec.cpuRequest, memory = spec.memoryRequest}
        limits = {cpu = spec.cpuLimit, memory = spec.memoryLimit}
    }
}

build_opensearch_dashboards_config = lambda spec: OpenSearchDashboardsSpec -> str {
    _base = {
        "server.host" = "0.0.0.0"
        "server.port" = str(spec.port)
        "opensearch.hosts" = _quote_list(spec.opensearchHosts)
    }
    _base_path = {
        if spec.serverBasePath != Undefined:
            "server.basePath" = spec.serverBasePath
            "server.rewriteBasePath" = "true"
    }
    _config = _base | _base_path | (spec.extraConfig or {})
    "\n".join(["${key}: ${value}" for key, value in _config]) + "\n"
}

build_opensearch_dashboards_configmap = lambda spec: OpenSearchDashboardsSpec -> any {
    cm.build_configmap(cm.ConfigMapSpec {
        name = "${spec.name}-config"
        namespace = spec.namespace
        data = {"opensearch_dashboards.yml" = build_opensearch_dashboards_config(spec)}
    })
}

build_opensearch_dashboards_deployment = lambda spec: OpenSearchDashboardsSpec -> any {
    {
        apiVersion = "apps/v1"
        kind = "Deployment"
        metadata = {name = spec.name, namespace = spec.namespace, labels = {app = spec.name, "app.kubernetes.io/component" = "opensearch-dashboards"}}
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
                        resources = _opensearch_dashboards_resource_requirements(spec.resources)
                        readinessProbe = {httpGet = {path = "/api/status", port = spec.port}, initialDelaySeconds = 30, periodSeconds = 10, timeoutSeconds = 5}
                        livenessProbe = {httpGet = {path = "/api/status", port = spec.port}, initialDelaySeconds = 90, periodSeconds = 20, timeoutSeconds = 5}
                        securityContext = {allowPrivilegeEscalation = False, capabilities = {drop = ["ALL"]}}
                        volumeMounts = [{name = "config", mountPath = "/usr/share/opensearch-dashboards/config/opensearch_dashboards.yml", subPath = "opensearch_dashboards.yml", readOnly = True}]
                    }]
                    volumes = [{name = "config", configMap = {name = "${spec.name}-config"}}]
                }
            }
        }
    }
}

build_opensearch_dashboards_service = lambda spec: OpenSearchDashboardsSpec -> any {
    svc.build_service(svc.ServiceSpec {name = spec.name, namespace = spec.namespace, port = spec.port, targetPort = spec.port, serviceType = spec.serviceType, portName = "http"})
}

build_opensearch_dashboards_pdb = lambda spec: OpenSearchDashboardsSpec -> any {
    pdb.build_pdb(pdb.PDBSpec {name = spec.name, namespace = spec.namespace, matchLabels = {app = spec.name}, minAvailable = spec.minAvailable})
}

build_opensearch_dashboards_resources = lambda spec: OpenSearchDashboardsSpec -> [any] {
    _pdbs = [build_opensearch_dashboards_pdb(spec)] if spec.replicas > 1 else []
    [build_opensearch_dashboards_configmap(spec), build_opensearch_dashboards_service(spec), build_opensearch_dashboards_deployment(spec)] + _pdbs
}

schema OpenSearchDashboardsModule(component.Component):
    """Component wrapper for standalone OpenSearch Dashboards."""
    kind = "INFRASTRUCTURE"

    replicas?: int = 2
    port?: int = 5601
    serviceType?: str = "ClusterIP"
    opensearchHosts: [str]
    serverBasePath?: str
    env?: [any]
    extraConfig?: {str:str}
    resources?: OpenSearchDashboardsResources = OpenSearchDashboardsResources {}

    leaders = [leader.build_component_leader(name, namespace)]
    manifests = build_opensearch_dashboards_resources(OpenSearchDashboardsSpec {
        name = name
        namespace = namespace
        image = asset.image if asset.image != Undefined else _DEFAULT_IMAGE
        version = asset.version
        replicas = replicas
        port = port
        serviceType = serviceType
        opensearchHosts = opensearchHosts
        serverBasePath = serverBasePath
        env = env
        extraConfig = extraConfig
        resources = resources
    })

