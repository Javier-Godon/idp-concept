"""
Kibana v9.4.1 Template — Elastic ECK CRD pattern.

Generates a `kibana.k8s.elastic.co/v1 Kibana` resource. Requires ECK to be
installed separately and an Elasticsearch resource reference.
"""

import builders.leader as leader
import models.modules.accessory as accessory

_DEFAULT_VERSION = "9.4.1"

schema KibanaResources:
    cpuRequest?: str = "250m"
    cpuLimit?: str = "1"
    memoryRequest?: str = "512Mi"
    memoryLimit?: str = "2Gi"

schema KibanaSpec:
    name: str
    namespace: str
    version?: str = _DEFAULT_VERSION
    count?: int = 2
    elasticsearchRef: str
    serviceType?: str = "ClusterIP"
    config?: {str:any}
    secureSettings?: [any]
    resources?: KibanaResources = KibanaResources {}

    check:
        len(name) > 0, "Kibana name must not be empty"
        len(namespace) > 0, "Kibana namespace must not be empty"
        version == _DEFAULT_VERSION, "This template is pinned to Kibana 9.4.1"
        count >= 1, "Kibana count must be >= 1"
        len(elasticsearchRef) > 0, "elasticsearchRef must not be empty"
        serviceType in ["ClusterIP", "NodePort", "LoadBalancer"], "serviceType must be ClusterIP, NodePort, or LoadBalancer"

_kibana_v9_resource_requirements = lambda spec: KibanaResources -> any {
    {
        requests = {cpu = spec.cpuRequest, memory = spec.memoryRequest}
        limits = {cpu = spec.cpuLimit, memory = spec.memoryLimit}
    }
}

build_kibana = lambda spec: KibanaSpec -> any {
    {
        apiVersion = "kibana.k8s.elastic.co/v1"
        kind = "Kibana"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {
                "app.kubernetes.io/name" = spec.name
                "app.kubernetes.io/component" = "kibana"
                "app.kubernetes.io/managed-by" = "idp-concept"
            }
        }
        spec = {
            version = spec.version
            count = spec.count
            elasticsearchRef = {name = spec.elasticsearchRef}
            http = {service = {spec = {$type = spec.serviceType}}}
            podTemplate = {
                spec = {
                    securityContext = {seccompProfile = {$type = "RuntimeDefault"}}
                    containers = [{
                        name = "kibana"
                        resources = _kibana_v9_resource_requirements(spec.resources)
                        securityContext = {allowPrivilegeEscalation = False, capabilities = {drop = ["ALL"]}}
                    }]
                }
            }
            if spec.config != Undefined:
                config = spec.config
            if spec.secureSettings != Undefined:
                secureSettings = spec.secureSettings
        }
    }
}

build_kibana_resources = lambda spec: KibanaSpec -> [any] {
    [build_kibana(spec)]
}

schema KibanaModule(accessory.Accessory):
    """Accessory wrapper for Kibana v9.4.1 via ECK."""
    kind = "CRD"

    kibanaName?: str
    count?: int = 2
    elasticsearchRef: str
    serviceType?: str = "ClusterIP"
    config?: {str:any}
    secureSettings?: [any]
    resources?: KibanaResources = KibanaResources {}

    _kibana_name = kibanaName if kibanaName != Undefined else name
    leaders = [leader.build_accessory_leader(_kibana_name, namespace, "Kibana", "kibana.k8s.elastic.co/v1")]
    manifests = build_kibana_resources(KibanaSpec {
        name = _kibana_name
        namespace = namespace
        version = asset.version
        count = count
        elasticsearchRef = elasticsearchRef
        serviceType = serviceType
        config = config
        secureSettings = secureSettings
        resources = resources
    })

