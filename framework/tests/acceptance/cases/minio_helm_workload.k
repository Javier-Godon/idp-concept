"""
Acceptance fixture: MinIO HelmRelease through the IDP render path.
"""
import ._helpers as h
import templates.minio.v1_0_0.minio as minio
_namespace = "idp-acceptance-minio-helm"
_resource = minio.build_minio_helm(minio.MinIOHelmSpec {
    name = "acceptance-minio-helm"
    namespace = _namespace
    chartVersion = "14.8.5"
    mode = "standalone"
    replicas = 1
    storageSize = "1Gi"
})
_module = h.wrap_accessory("acceptance-minio-helm", _namespace, "helm.toolkit.fluxcd.io/v2beta1", "HelmRelease", [_resource], "14.8.5")
h.render_accessory(_namespace, _module)
