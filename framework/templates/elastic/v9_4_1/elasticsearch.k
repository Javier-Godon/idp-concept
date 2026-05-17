"""
Elasticsearch v9.4.1 Template — Elastic ECK CRD pattern.

License note: Elasticsearch 9.x artifacts and ECK are available under Elastic's
licenses, not Apache-2.0. Use only when your organization's intended usage is
compatible with Elastic's license terms. This template generates ECK custom
resources and does not install the ECK operator itself.
"""

import builders.leader as leader
import models.modules.accessory as accessory

_DEFAULT_VERSION = "9.4.1"

schema ElasticsearchResources:
    cpuRequest?: str = "1"
    cpuLimit?: str = "2"
    memoryRequest?: str = "2Gi"
    memoryLimit?: str = "4Gi"

schema ElasticsearchNodeSetSpec:
    name: str
    count?: int = 3
    roles?: [str] = ["master", "data", "ingest", "ml", "transform"]
    storageSize?: str = "100Gi"
    storageClassName?: str = "rook-ceph-block"
    javaOpts?: str = "-Xms2g -Xmx2g"
    config?: {str:any}
    resources?: ElasticsearchResources = ElasticsearchResources {}

    check:
        len(name) > 0, "nodeSet name must not be empty"
        count >= 1, "nodeSet count must be >= 1"
        len(roles) > 0, "nodeSet roles must not be empty"
        len(storageSize) > 0, "nodeSet storageSize must not be empty"

schema ElasticsearchSpec:
    name: str
    namespace: str
    version?: str = _DEFAULT_VERSION
    nodeSets?: [ElasticsearchNodeSetSpec] = [ElasticsearchNodeSetSpec {name = "default"}]
    serviceType?: str = "ClusterIP"
    monitoring?: bool = False
    secureSettings?: [any]
    httpTLSDisabled?: bool = False
    updateStrategy?: any

    check:
        len(name) > 0, "Elasticsearch name must not be empty"
        len(namespace) > 0, "Elasticsearch namespace must not be empty"
        version == _DEFAULT_VERSION, "This template is pinned to Elasticsearch 9.4.1"
        len(nodeSets) > 0, "nodeSets must not be empty"
        serviceType in ["ClusterIP", "NodePort", "LoadBalancer"], "serviceType must be ClusterIP, NodePort, or LoadBalancer"

_resource_requirements = lambda spec: ElasticsearchResources -> any {
    {
        requests = {cpu = spec.cpuRequest, memory = spec.memoryRequest}
        limits = {cpu = spec.cpuLimit, memory = spec.memoryLimit}
    }
}

_build_node_set = lambda ns: ElasticsearchNodeSetSpec -> any {
    _base_config = {
        "node.roles" = ns.roles
    }
    {
        name = ns.name
        count = ns.count
        config = _base_config | (ns.config or {})
        podTemplate = {
            spec = {
                securityContext = {
                    fsGroup = 1000
                    seccompProfile = {$type = "RuntimeDefault"}
                }
                containers = [{
                    name = "elasticsearch"
                    env = [{name = "ES_JAVA_OPTS", value = ns.javaOpts}]
                    resources = _resource_requirements(ns.resources)
                    securityContext = {
                        allowPrivilegeEscalation = False
                        capabilities = {drop = ["ALL"]}
                    }
                }]
            }
        }
        volumeClaimTemplates = [{
            metadata = {name = "elasticsearch-data"}
            spec = {
                accessModes = ["ReadWriteOnce"]
                if ns.storageClassName != Undefined:
                    storageClassName = ns.storageClassName
                resources = {requests = {storage = ns.storageSize}}
            }
        }]
    }
}

build_elasticsearch_cluster = lambda spec: ElasticsearchSpec -> any {
    _http_tls = {
        if spec.httpTLSDisabled:
            tls = {selfSignedCertificate = {disabled = True}}
    }
    _monitoring = {
        if spec.monitoring:
            monitoring = {metrics = {elasticsearchRefs = [{name = spec.name}]}, logs = {elasticsearchRefs = [{name = spec.name}]}}
    }
    {
        apiVersion = "elasticsearch.k8s.elastic.co/v1"
        kind = "Elasticsearch"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {
                "app.kubernetes.io/name" = spec.name
                "app.kubernetes.io/component" = "elasticsearch"
                "app.kubernetes.io/managed-by" = "idp-concept"
            }
        }
        spec = {
            version = spec.version
            http = {service = {spec = {$type = spec.serviceType}}} | _http_tls
            nodeSets = [_build_node_set(ns) for ns in spec.nodeSets]
            if spec.secureSettings != Undefined:
                secureSettings = spec.secureSettings
            if spec.updateStrategy != Undefined:
                updateStrategy = spec.updateStrategy
        } | _monitoring
    }
}

build_elasticsearch_resources = lambda spec: ElasticsearchSpec -> [any] {
    [build_elasticsearch_cluster(spec)]
}

schema ElasticsearchModule(accessory.Accessory):
    """Accessory wrapper for Elasticsearch v9.4.1 via ECK."""
    kind = "CRD"

    clusterName?: str
    nodeSets?: [ElasticsearchNodeSetSpec] = [ElasticsearchNodeSetSpec {name = "default"}]
    serviceType?: str = "ClusterIP"
    monitoring?: bool = False
    secureSettings?: [any]
    httpTLSDisabled?: bool = False
    updateStrategy?: any

    _cluster_name = clusterName if clusterName != Undefined else name
    leaders = [leader.build_accessory_leader(_cluster_name, namespace, "Elasticsearch", "elasticsearch.k8s.elastic.co/v1")]
    manifests = build_elasticsearch_resources(ElasticsearchSpec {
        name = _cluster_name
        namespace = namespace
        version = asset.version
        nodeSets = nodeSets
        serviceType = serviceType
        monitoring = monitoring
        secureSettings = secureSettings
        httpTLSDisabled = httpTLSDisabled
        updateStrategy = updateStrategy
    })
