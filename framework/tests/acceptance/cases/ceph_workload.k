"""
Acceptance fixture: CephModule through the IDP render path.
"""
import ._helpers as h
import templates.ceph.v1_0_0.ceph as ceph
_module = ceph.CephModule {
    name = "acceptance-ceph"
    namespace = "idp-acceptance-ceph"
    configurations = {}
    asset = {version = "1.15.2"}
    dependsOn = []
    cephName = "acceptance-ceph"
    clusterName = "acceptance-ceph"
    chartVersion = "1.15.2"
    monCount = 1
    mgrCount = 1
    blockPoolReplicatedSize = 1
    storageUseAllNodes = False
    storageUseAllDevices = False
    createBlockPoolAndStorageClass = True
    storageClassName = "acceptance-ceph-block"
}.instance
h.render_accessory("idp-acceptance-ceph", _module)
