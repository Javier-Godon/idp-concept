"""
QuestDB Template — Time-series database deployed via official Helm chart.

QuestDB has no Kubernetes operator; it is deployed as a Helm chart using
the ThirdPartyHelmSpec pattern. This template provides a QuestDB-specific
wrapper with sensible defaults for chart, ports, persistence, and resources.

Official Helm chart: https://questdb.io/docs/deployment/kubernetes/
Chart repo: https://questdb.github.io/questdb-helm (chart: questdb/questdb)

Usage:
    import templates.questdb as qdb

    _spec = qdb.QuestDBSpec {
        name = "my-questdb"
        namespace = "data"
        storageSize = "50Gi"
    }
    _manifest = qdb.build_questdb_release(_spec)
"""
import models.modules.thirdparty_helm as th

schema QuestDBSpec:
    """Specification for deploying QuestDB via Helm chart."""
    name: str
    namespace: str
    chartVersion: str = "0.32.0"
    storageSize: str = "50Gi"
    storageClassName?: str

    # Resource requests/limits
    cpuRequest?: str
    memoryRequest?: str
    cpuLimit?: str
    memoryLimit?: str

    # Service ports (QuestDB defaults)
    httpPort?: int
    ilpPort?: int
    pgPort?: int

    # Service type
    serviceType?: str

    # Extra Helm values (flat key=value)
    extraValues?: {str:str}

    check:
        len(name) > 0, "QuestDB release name must not be empty"
        len(namespace) > 0, "QuestDB namespace must not be empty"
        len(storageSize) > 0, "QuestDB storageSize must not be empty"

build_questdb_release = lambda spec: QuestDBSpec -> any {
    # Build values dict from spec fields
    _persistence_values: {str:str} = {
        "persistence.enabled" = "true"
        "persistence.size" = spec.storageSize
    }
    _storage_class_values: {str:str} = {
        if spec.storageClassName:
            "persistence.storageClassName" = spec.storageClassName
    }
    _resource_values: {str:str} = {
        if spec.cpuRequest:
            "resources.requests.cpu" = spec.cpuRequest
        if spec.memoryRequest:
            "resources.requests.memory" = spec.memoryRequest
        if spec.cpuLimit:
            "resources.limits.cpu" = spec.cpuLimit
        if spec.memoryLimit:
            "resources.limits.memory" = spec.memoryLimit
    }
    _port_values: {str:str} = {
        if spec.httpPort:
            "service.http.port" = str(spec.httpPort)
        if spec.ilpPort:
            "service.ilp.port" = str(spec.ilpPort)
        if spec.pgPort:
            "service.postgresql.port" = str(spec.pgPort)
    }
    _service_values: {str:str} = {
        if spec.serviceType:
            "service.type" = spec.serviceType
    }

    _all_values: {str:str} = _persistence_values | _storage_class_values | _resource_values | _port_values | _service_values | (spec.extraValues or {})

    _helm_spec = th.ThirdPartyHelmSpec {
        name = spec.name
        namespace = spec.namespace
        chart = "questdb/questdb"
        version = spec.chartVersion
        values = _all_values
    }

    th.build_thirdparty_helm(_helm_spec)
}
