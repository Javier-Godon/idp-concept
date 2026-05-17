"""
Elasticsearch OSS Template — Kubernetes-native Elasticsearch 7.10.2.

License note: Elastic ECK is not an OSI-open-source operator, so this template
does not use it. It pins the last Apache-2.0 Elasticsearch OSS line and uses
Kubernetes-native controllers (StatefulSet/Services/PDB).
"""

import builders.configmap as cm
import builders.leader as leader
import builders.pdb as pdb
import models.modules.component as component

_DEFAULT_IMAGE = "docker.elastic.co/elasticsearch/elasticsearch-oss"
_DEFAULT_VERSION = "7.10.2"

schema ElasticsearchResources:
    cpuRequest?: str = "1"
    cpuLimit?: str = "2"
    memoryRequest?: str = "2Gi"
    memoryLimit?: str = "4Gi"

schema ElasticsearchSpec:
    name: str
    namespace: str
    image?: str = _DEFAULT_IMAGE
    version?: str = _DEFAULT_VERSION
    replicas?: int = 3
    httpPort?: int = 9200
    transportPort?: int = 9300
    storageSize?: str = "100Gi"
    storageClassName?: str = "rook-ceph-block"
    javaOpts?: str = "-Xms2g -Xmx2g"
    clusterName?: str
    extraConfig?: {str:str}
    env?: [any]
    resources?: ElasticsearchResources = ElasticsearchResources {}
    minAvailable?: int | str = 2

    check:
        len(name) > 0, "Elasticsearch name must not be empty"
        len(namespace) > 0, "Elasticsearch namespace must not be empty"
        len(version) > 0, "Elasticsearch image version must be pinned"
        "latest" not in version, "Elasticsearch image version must not be latest"
        version == "7.10.2", "Elasticsearch OSS template is pinned to the last Apache-2.0 OSS release: 7.10.2"
        replicas >= 3, "Elasticsearch production replicas must be >= 3"
        1 <= httpPort <= 65535, "httpPort must be between 1 and 65535"
        1 <= transportPort <= 65535, "transportPort must be between 1 and 65535"
        len(storageSize) > 0, "storageSize must not be empty"

_elasticsearch_resource_requirements = lambda spec: ElasticsearchResources -> any {
    {
        requests = {cpu = spec.cpuRequest, memory = spec.memoryRequest}
        limits = {cpu = spec.cpuLimit, memory = spec.memoryLimit}
    }
}

_elasticsearch_seed_hosts = lambda spec: ElasticsearchSpec -> str {
    ",".join(["${spec.name}-${i}.${spec.name}-headless.${spec.namespace}.svc.cluster.local" for i in range(spec.replicas)])
}

_elasticsearch_initial_masters = lambda spec: ElasticsearchSpec -> str {
    ",".join(["${spec.name}-${i}" for i in range(spec.replicas)])
}

build_elasticsearch_config = lambda spec: ElasticsearchSpec -> str {
    _base = {
        "cluster.name" = spec.clusterName if spec.clusterName != Undefined else spec.name
        "network.host" = "0.0.0.0"
        "discovery.seed_hosts" = _elasticsearch_seed_hosts(spec)
        "cluster.initial_master_nodes" = _elasticsearch_initial_masters(spec)
        "xpack.security.enabled" = "false"
    }
    _config = _base | (spec.extraConfig or {})
    "\n".join(["${key}: ${value}" for key, value in _config]) + "\n"
}

build_elasticsearch_configmap = lambda spec: ElasticsearchSpec -> any {
    cm.build_configmap(cm.ConfigMapSpec {
        name = "${spec.name}-config"
        namespace = spec.namespace
        data = {"elasticsearch.yml" = build_elasticsearch_config(spec)}
    })
}

build_elasticsearch_service = lambda spec: ElasticsearchSpec -> any {
    {
        apiVersion = "v1"
        kind = "Service"
        metadata = {name = spec.name, namespace = spec.namespace, labels = {app = spec.name}}
        spec = {
            selector = {app = spec.name}
            ports = [
                {name = "http", port = spec.httpPort, targetPort = spec.httpPort}
                {name = "transport", port = spec.transportPort, targetPort = spec.transportPort}
            ]
            $type = "ClusterIP"
        }
    }
}

build_elasticsearch_headless_service = lambda spec: ElasticsearchSpec -> any {
    {
        apiVersion = "v1"
        kind = "Service"
        metadata = {name = "${spec.name}-headless", namespace = spec.namespace, labels = {app = spec.name}}
        spec = {
            clusterIP = "None"
            publishNotReadyAddresses = True
            selector = {app = spec.name}
            ports = [
                {name = "http", port = spec.httpPort, targetPort = spec.httpPort}
                {name = "transport", port = spec.transportPort, targetPort = spec.transportPort}
            ]
        }
    }
}

build_elasticsearch_statefulset = lambda spec: ElasticsearchSpec -> any {
    {
        apiVersion = "apps/v1"
        kind = "StatefulSet"
        metadata = {name = spec.name, namespace = spec.namespace, labels = {app = spec.name, "app.kubernetes.io/component" = "elasticsearch"}}
        spec = {
            serviceName = "${spec.name}-headless"
            replicas = spec.replicas
            podManagementPolicy = "Parallel"
            updateStrategy = {$type = "RollingUpdate"}
            selector = {matchLabels = {app = spec.name}}
            template = {
                metadata = {labels = {app = spec.name}}
                spec = {
                    securityContext = {runAsNonRoot = True, runAsUser = 1000, runAsGroup = 1000, fsGroup = 1000, seccompProfile = {$type = "RuntimeDefault"}}
                    terminationGracePeriodSeconds = 120
                    containers = [{
                        name = spec.name
                        image = "${spec.image}:${spec.version}"
                        imagePullPolicy = "IfNotPresent"
                        ports = [{name = "http", containerPort = spec.httpPort}, {name = "transport", containerPort = spec.transportPort}]
                        env = [{name = "ES_JAVA_OPTS", value = spec.javaOpts}] + (spec.env or [])
                        resources = _elasticsearch_resource_requirements(spec.resources)
                        readinessProbe = {httpGet = {path = "/_cluster/health?local=true", port = spec.httpPort}, initialDelaySeconds = 30, periodSeconds = 10, timeoutSeconds = 5}
                        livenessProbe = {tcpSocket = {port = spec.transportPort}, initialDelaySeconds = 120, periodSeconds = 20, timeoutSeconds = 5}
                        securityContext = {allowPrivilegeEscalation = False, capabilities = {drop = ["ALL"]}}
                        volumeMounts = [
                            {name = "data", mountPath = "/usr/share/elasticsearch/data"}
                            {name = "config", mountPath = "/usr/share/elasticsearch/config/elasticsearch.yml", subPath = "elasticsearch.yml", readOnly = True}
                        ]
                    }]
                    volumes = [{name = "config", configMap = {name = "${spec.name}-config"}}]
                }
            }
            volumeClaimTemplates = [{
                metadata = {name = "data"}
                spec = {
                    accessModes = ["ReadWriteOnce"]
                    if spec.storageClassName != Undefined:
                        storageClassName = spec.storageClassName
                    resources = {requests = {storage = spec.storageSize}}
                }
            }]
        }
    }
}

build_elasticsearch_pdb = lambda spec: ElasticsearchSpec -> any {
    pdb.build_pdb(pdb.PDBSpec {name = spec.name, namespace = spec.namespace, matchLabels = {app = spec.name}, minAvailable = spec.minAvailable})
}

build_elasticsearch_resources = lambda spec: ElasticsearchSpec -> [any] {
    [build_elasticsearch_configmap(spec), build_elasticsearch_headless_service(spec), build_elasticsearch_service(spec), build_elasticsearch_statefulset(spec), build_elasticsearch_pdb(spec)]
}

schema ElasticsearchModule(component.Component):
    """Component wrapper for Elasticsearch OSS 7.10.2 StatefulSet."""
    kind = "INFRASTRUCTURE"

    replicas?: int = 3
    httpPort?: int = 9200
    transportPort?: int = 9300
    storageSize?: str = "100Gi"
    storageClassName?: str = "rook-ceph-block"
    javaOpts?: str = "-Xms2g -Xmx2g"
    clusterName?: str
    extraConfig?: {str:str}
    env?: [any]
    resources?: ElasticsearchResources = ElasticsearchResources {}

    leaders = [leader.build_component_leader(name, namespace, "StatefulSet", "apps/v1")]
    manifests = build_elasticsearch_resources(ElasticsearchSpec {
        name = name
        namespace = namespace
        image = asset.image if asset.image != Undefined else _DEFAULT_IMAGE
        version = asset.version
        replicas = replicas
        httpPort = httpPort
        transportPort = transportPort
        storageSize = storageSize
        storageClassName = storageClassName
        javaOpts = javaOpts
        clusterName = clusterName
        extraConfig = extraConfig
        env = env
        resources = resources
    })
