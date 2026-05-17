"""
Logstash v9.4.1 Template — Elastic ECK CRD pattern.

Generates a `logstash.k8s.elastic.co/v1alpha1 Logstash` resource. Requires ECK
with Logstash CRD support installed separately.
"""

import builders.leader as leader
import models.modules.accessory as accessory

_DEFAULT_VERSION = "9.4.1"

schema LogstashResources:
    cpuRequest?: str = "500m"
    cpuLimit?: str = "2"
    memoryRequest?: str = "1Gi"
    memoryLimit?: str = "4Gi"

schema PipelineSpec:
    id: str
    config: str

    check:
        len(id) > 0, "pipeline id must not be empty"
        len(config) > 0, "pipeline config must not be empty"

schema LogstashSpec:
    name: str
    namespace: str
    version?: str = _DEFAULT_VERSION
    count?: int = 2
    pipelines: [PipelineSpec]
    elasticsearchRefs?: [str]
    serviceType?: str = "ClusterIP"
    monitoringPort?: int = 9600
    javaOpts?: str = "-Xms1g -Xmx1g"
    config?: {str:any}
    secureSettings?: [any]
    resources?: LogstashResources = LogstashResources {}

    check:
        len(name) > 0, "Logstash name must not be empty"
        len(namespace) > 0, "Logstash namespace must not be empty"
        version == _DEFAULT_VERSION, "This template is pinned to Logstash 9.4.1"
        count >= 1, "Logstash count must be >= 1"
        len(pipelines) > 0, "pipelines must not be empty"
        1 <= monitoringPort <= 65535, "monitoringPort must be between 1 and 65535"
        serviceType in ["ClusterIP", "NodePort", "LoadBalancer"], "serviceType must be ClusterIP, NodePort, or LoadBalancer"

_logstash_v9_resource_requirements = lambda spec: LogstashResources -> any {
    {
        requests = {cpu = spec.cpuRequest, memory = spec.memoryRequest}
        limits = {cpu = spec.cpuLimit, memory = spec.memoryLimit}
    }
}

_pipeline_entries = lambda pipelines: [PipelineSpec] -> [any] {
    [{"pipeline.id" = p.id, "config.string" = p.config} for p in pipelines]
}

_elasticsearch_refs = lambda refs: [str] -> [any] {
    [{name = ref} for ref in refs]
}

build_logstash = lambda spec: LogstashSpec -> any {
    {
        apiVersion = "logstash.k8s.elastic.co/v1alpha1"
        kind = "Logstash"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {
                "app.kubernetes.io/name" = spec.name
                "app.kubernetes.io/component" = "logstash"
                "app.kubernetes.io/managed-by" = "idp-concept"
            }
        }
        spec = {
            version = spec.version
            count = spec.count
            pipelines = _pipeline_entries(spec.pipelines)
            services = [{name = "beats", service = {spec = {$type = spec.serviceType}}}]
            podTemplate = {
                spec = {
                    securityContext = {seccompProfile = {$type = "RuntimeDefault"}}
                    containers = [{
                        name = "logstash"
                        env = [{name = "LS_JAVA_OPTS", value = spec.javaOpts}]
                        ports = [{name = "monitoring", containerPort = spec.monitoringPort}]
                        resources = _logstash_v9_resource_requirements(spec.resources)
                        securityContext = {allowPrivilegeEscalation = False, capabilities = {drop = ["ALL"]}}
                    }]
                }
            }
            if spec.elasticsearchRefs != Undefined:
                elasticsearchRefs = _elasticsearch_refs(spec.elasticsearchRefs)
            if spec.config != Undefined:
                config = spec.config
            if spec.secureSettings != Undefined:
                secureSettings = spec.secureSettings
        }
    }
}

build_logstash_resources = lambda spec: LogstashSpec -> [any] {
    [build_logstash(spec)]
}

schema LogstashModule(accessory.Accessory):
    """Accessory wrapper for Logstash v9.4.1 via ECK."""
    kind = "CRD"

    logstashName?: str
    count?: int = 2
    pipelines: [PipelineSpec]
    elasticsearchRefs?: [str]
    serviceType?: str = "ClusterIP"
    monitoringPort?: int = 9600
    javaOpts?: str = "-Xms1g -Xmx1g"
    config?: {str:any}
    secureSettings?: [any]
    resources?: LogstashResources = LogstashResources {}

    _logstash_name = logstashName if logstashName != Undefined else name
    leaders = [leader.build_accessory_leader(_logstash_name, namespace, "Logstash", "logstash.k8s.elastic.co/v1alpha1")]
    manifests = build_logstash_resources(LogstashSpec {
        name = _logstash_name
        namespace = namespace
        version = asset.version
        count = count
        pipelines = pipelines
        elasticsearchRefs = elasticsearchRefs
        serviceType = serviceType
        monitoringPort = monitoringPort
        javaOpts = javaOpts
        config = config
        secureSettings = secureSettings
        resources = resources
    })

