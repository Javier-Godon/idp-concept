"""
MinIO Template — Object storage deployed via MinIO Operator (Tenant CRD)
or as a Bitnami Helm chart fallback.

The MinIO Operator (minio/operator) was archived March 2026 but the Tenant CRD
(`minio.min.io/v2`) remains functional for existing clusters. For new deployments,
use the Helm chart fallback (`MinIOHelmSpec` + `build_minio_helm`).

Operator: https://github.com/minio/operator (archived, AGPL-3.0)
Helm: https://github.com/bitnami/charts/tree/main/bitnami/minio (Apache-2.0)

Usage with Operator CRD:
    import templates.minio as mn

    _spec = mn.MinIOTenantSpec {
        name = "my-minio"
        namespace = "storage"
        servers = 4
        volumesPerServer = 4
        storageSize = "100Gi"
    }
    _manifest = mn.build_minio_tenant(_spec)

Usage with Helm chart (recommended for new deployments):
    import templates.minio as mn

    _spec = mn.MinIOHelmSpec {
        name = "my-minio"
        namespace = "storage"
        storageSize = "100Gi"
    }
    _manifest = mn.build_minio_helm(_spec)
"""
import models.modules.thirdparty_helm as th

_API_VERSION = "minio.min.io/v2"
_DEFAULT_IMAGE = "minio/minio:RELEASE.2025-03-12T18-04-18Z"

# --- MinIO Operator Tenant CRD ---

schema MinIOTenantSpec:
    """Specification for a MinIO Tenant CRD (minio.min.io/v2)."""
    name: str
    namespace: str
    image?: str = _DEFAULT_IMAGE
    servers?: int = 4
    volumesPerServer?: int = 4
    storageSize?: str = "10Gi"
    storageClassName?: str

    # Resource requests/limits
    cpuRequest?: str
    memoryRequest?: str
    cpuLimit?: str
    memoryLimit?: str

    # TLS
    requestAutoCert?: bool = True

    # Environment variables
    env?: [any]

    # Credentials secret (must contain accesskey and secretkey)
    credsSecret?: str

    check:
        servers >= 1, "MinIO requires at least 1 server"
        volumesPerServer >= 1, "MinIO requires at least 1 volume per server"
        len(storageSize) > 0, "MinIO storageSize must not be empty"

build_minio_tenant = lambda spec: MinIOTenantSpec -> any {
    _resources = {
        if spec.cpuRequest or spec.memoryRequest:
            requests = {
                if spec.cpuRequest:
                    cpu = spec.cpuRequest
                if spec.memoryRequest:
                    memory = spec.memoryRequest
            }
        if spec.cpuLimit or spec.memoryLimit:
            limits = {
                if spec.cpuLimit:
                    cpu = spec.cpuLimit
                if spec.memoryLimit:
                    memory = spec.memoryLimit
            }
    }

    {
        apiVersion = _API_VERSION
        kind = "Tenant"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {
                "app.kubernetes.io/name" = spec.name
                "app.kubernetes.io/managed-by" = "idp-concept"
            }
        }
        spec = {
            image = spec.image
            pools = [{
                servers = spec.servers
                volumesPerServer = spec.volumesPerServer
                volumeClaimTemplate = {
                    metadata.labels = {
                        "app.kubernetes.io/name" = spec.name
                    }
                    spec = {
                        accessModes = ["ReadWriteOnce"]
                        resources.requests.storage = spec.storageSize
                        if spec.storageClassName:
                            storageClassName = spec.storageClassName
                    }
                }
                if _resources:
                    resources = _resources
            }]
            requestAutoCert = spec.requestAutoCert
            if spec.env:
                env = spec.env
            if spec.credsSecret:
                credsSecret.name = spec.credsSecret
        }
    }
}

# --- MinIO Helm Chart Fallback (Bitnami) ---

schema MinIOHelmSpec:
    """Specification for deploying MinIO via Bitnami Helm chart."""
    name: str
    namespace: str
    chartVersion: str = "14.8.5"
    mode?: str = "distributed"
    storageSize?: str = "10Gi"
    storageClassName?: str
    replicas?: int = 4
    extraValues?: {str:str}

    check:
        mode in ["standalone", "distributed"], "mode must be 'standalone' or 'distributed'"
        replicas >= 1, "replicas must be at least 1"
        len(storageSize) > 0, "storageSize must not be empty"

build_minio_helm = lambda spec: MinIOHelmSpec -> any {
    _values: {str:str} = {
        "mode" = spec.mode
        "persistence.enabled" = "true"
        "persistence.size" = spec.storageSize
        if spec.storageClassName:
            "persistence.storageClassName" = spec.storageClassName
        if spec.mode == "distributed":
            "statefulset.replicaCount" = str(spec.replicas)
    }

    _all_values = _values | (spec.extraValues or {})

    _helm_spec = th.ThirdPartyHelmSpec {
        name = spec.name
        namespace = spec.namespace
        chart = "oci://registry-1.docker.io/bitnamicharts/minio"
        version = spec.chartVersion
        values = _all_values
    }

    th.build_thirdparty_helm(_helm_spec)
}
