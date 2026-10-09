"""
erp cache module — Valkey (Redis-compatible).
The crossplane output renders it as an XValkeyInstance reconciled by
crossplane_v2/managed_resources/valkey; sizing follows the configured footprint.
"""
import framework.templates.valkey.v1_0_0.valkey as valkey

schema ErpCacheModule(valkey.ValkeyModule):
    valkeyName = name
    footprint = configurations.footprint
    storageClassName = configurations.storageClassName
