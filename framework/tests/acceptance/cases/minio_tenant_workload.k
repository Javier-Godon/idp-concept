"""
Acceptance fixture: MinIO Tenant CR through the IDP render path.
"""

import ._helpers as h
import templates.minio as minio

_namespace = "idp-acceptance-minio-tenant"
_resource = minio.build_minio_tenant(minio.MinIOTenantSpec {
    name = "acceptance-minio"
    namespace = _namespace
    servers = 1
    volumesPerServer = 1
    storageSize = "1Gi"
    requestAutoCert = False
})
_module = h.wrap_accessory("acceptance-minio", _namespace, "minio.min.io/v2", "Tenant", [_resource], "RELEASE.2025-03-12T18-04-18Z")

h.render_accessory(_namespace, _module)

