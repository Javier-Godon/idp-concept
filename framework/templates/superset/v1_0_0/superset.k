"""
Apache Superset Template — Open-source data visualization platform.

Apache Superset is a modern data visualization and business intelligence platform.
It is deployed via Helm chart. This template provides sensible defaults for deploying
Superset with database connectivity, caching, and resource management across environments.

Official Helm chart: https://superset.apache.org/docs/installation/kubernetes
Chart repo: https://apache.github.io/superset (chart: superset/superset)

Usage:
    import templates.superset.v1_0_0.superset as superset

    _spec = superset.SupersetSpec {
        name = "my-superset"
        namespace = "analytics"
        footprint = "production"
        databaseUri = "postgresql://user:pass@postgres:5432/superset"
    }
    _module = superset.SupersetModule {
        name = "my-superset"
        namespace = "analytics"
        footprint = "production"
        databaseUri = "postgresql://user:pass@postgres:5432/superset"
    }.instance
"""
import models.modules.accessory as accessory
import models.modules.thirdparty_helm as th
import templates.footprints.v1_0_0.footprint as fp
import builders.leader as leader

schema SupersetSpec:
    """Specification for deploying Apache Superset via Helm chart."""
    name: str
    namespace: str
    chartVersion: str = "0.14.1"
    footprint: str = "production"

    # Database backend (required for persistent state)
    databaseUri: str

    # Redis cache backend
    redisUri?: str = "redis://localhost:6379/0"

    # Web UI configuration
    adminUsername: str = "admin"
    adminFirstName: str = "Admin"
    adminLastName: str = "User"
    # NOTE: adminPassword should be provided via Helm values or Secret

    # Service ports
    webPort: int = 8088

    # Replicas for web & worker
    webReplicas?: int
    workerReplicas?: int

    # Resource requests/limits
    webCpuRequest?: str
    webMemoryRequest?: str
    webCpuLimit?: str
    webMemoryLimit?: str
    workerCpuRequest?: str
    workerMemoryRequest?: str
    workerCpuLimit?: str
    workerMemoryLimit?: str

    # Persistence for uploads/cache
    persistenceEnabled: bool = True
    persistenceSize?: str
    persistenceStorageClass?: str

    # Extra Helm values
    extraValues?: {str:str}

    check:
        len(name) > 0, "Superset release name must not be empty"
        len(namespace) > 0, "Superset namespace must not be empty"
        len(databaseUri) > 0, "databaseUri must not be empty"
        webPort > 0 and webPort <= 65535, "webPort must be valid"

build_superset_release = lambda spec: SupersetSpec -> any {
    _web_replicas = spec.webReplicas or fp.replicas(spec.footprint)
    _worker_replicas = spec.workerReplicas or fp.replicas(spec.footprint)
    _storage_size = spec.persistenceSize or fp.storage_size(spec.footprint, "5Gi", "10Gi", "20Gi", "50Gi")

    # Build values dict
    _web_replicas_values: {str:str} = {"supersetNode.replicaCount" = str(_web_replicas)}

    _worker_replicas_values: {str:str} = {"supersetWorker.replicaCount" = str(_worker_replicas)}

    _database_values: {str:str} = {"supersetDatabaseUri" = spec.databaseUri}

    _redis_values: {str:str} = {if spec.redisUri: "redis.enabled" = "false", "supersetCeleryBrokerUrl" = spec.redisUri}

    _admin_values: {str:str} = {"adminUser.username" = spec.adminUsername, "adminUser.firstname" = spec.adminFirstName, "adminUser.lastname" = spec.adminLastName}

    _service_values: {str:str} = {"service.port" = str(spec.webPort), "service.type" = "LoadBalancer" if spec.footprint == "production" else "NodePort"}

    _persistence_values: {str:str} = {"persistence.enabled" = str(spec.persistenceEnabled), if spec.persistenceEnabled: "persistence.size" = _storage_size if spec.persistenceStorageClass: "persistence.storageClassName" = spec.persistenceStorageClass}

    _web_resources: {str:str} = {if spec.webCpuRequest: "supersetNode.resources.requests.cpu" = spec.webCpuRequest if spec.webMemoryRequest: "supersetNode.resources.requests.memory" = spec.webMemoryRequest if spec.webCpuLimit: "supersetNode.resources.limits.cpu" = spec.webCpuLimit if spec.webMemoryLimit: "supersetNode.resources.limits.memory" = spec.webMemoryLimit}

    _worker_resources: {str:str} = {if spec.workerCpuRequest: "supersetWorker.resources.requests.cpu" = spec.workerCpuRequest if spec.workerMemoryRequest: "supersetWorker.resources.requests.memory" = spec.workerMemoryRequest if spec.workerCpuLimit: "supersetWorker.resources.limits.cpu" = spec.workerCpuLimit if spec.workerMemoryLimit: "supersetWorker.resources.limits.memory" = spec.workerMemoryLimit}

    _all_values: {str:str} = _web_replicas_values | _worker_replicas_values | _database_values | _redis_values | _admin_values | _service_values | _persistence_values | _web_resources | _worker_resources | (spec.extraValues or {})

    _helm_spec = th.ThirdPartyHelmSpec {
        name = spec.name
        namespace = spec.namespace
        chart = "superset/superset"
        version = spec.chartVersion
        values = _all_values
    }

    th.build_thirdparty_helm(_helm_spec)
}

schema SupersetModule(accessory.Accessory):
    """High-level template for Apache Superset via Helm chart."""
    kind = "CRD"

    # Settings
    footprint: str = "production"
    databaseUri: str
    redisUri?: str = "redis://localhost:6379/0"
    adminUsername: str = "admin"
    adminFirstName: str = "Admin"
    adminLastName: str = "User"
    webPort: int = 8088
    webReplicas?: int
    workerReplicas?: int
    webCpuRequest?: str
    webMemoryRequest?: str
    webCpuLimit?: str
    webMemoryLimit?: str
    workerCpuRequest?: str
    workerMemoryRequest?: str
    workerCpuLimit?: str
    workerMemoryLimit?: str
    persistenceEnabled: bool = True
    persistenceSize?: str
    persistenceStorageClass?: str
    extraValues?: {str:str}

    # Auto-computed
    leaders = [leader.build_accessory_leader(name, namespace, "Release", "helm.crossplane.io/v1beta1")]

    _spec = SupersetSpec {
        name = name
        namespace = namespace
        footprint = footprint
        databaseUri = databaseUri
        if redisUri:
            redisUri = redisUri
        adminUsername = adminUsername
        adminFirstName = adminFirstName
        adminLastName = adminLastName
        webPort = webPort
        if webReplicas:
            webReplicas = webReplicas
        if workerReplicas:
            workerReplicas = workerReplicas
        if webCpuRequest:
            webCpuRequest = webCpuRequest
        if webMemoryRequest:
            webMemoryRequest = webMemoryRequest
        if webCpuLimit:
            webCpuLimit = webCpuLimit
        if webMemoryLimit:
            webMemoryLimit = webMemoryLimit
        if workerCpuRequest:
            workerCpuRequest = workerCpuRequest
        if workerMemoryRequest:
            workerMemoryRequest = workerMemoryRequest
        if workerCpuLimit:
            workerCpuLimit = workerCpuLimit
        if workerMemoryLimit:
            workerMemoryLimit = workerMemoryLimit
        persistenceEnabled = persistenceEnabled
        if persistenceSize:
            persistenceSize = persistenceSize
        if persistenceStorageClass:
            persistenceStorageClass = persistenceStorageClass
        if extraValues:
            extraValues = extraValues
    }

    manifests = [build_superset_release(_spec)]



