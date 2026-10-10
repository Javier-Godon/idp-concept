"""
erp cache module — Valkey (Redis-compatible).
The crossplane output renders it as an XValkeyInstance reconciled by
crossplane_v2/managed_resources/valkey; sizing follows the configured footprint.
Valkey Admin is served on the shared hostname under a sub-path; the basic-auth Secret is referenced by
name only and must exist in the cache namespace.
"""
import framework.templates.valkey.v1_0_0.valkey as valkey
import framework.templates.valkey.v1_0_0.valkey_admin as valkey_admin

schema ErpCacheModule(valkey.ValkeyModule):
    valkeyName = name
    footprint = configurations.footprint
    storageClassName = configurations.storageClassName
    valkeyAdmin = valkey_admin.ValkeyAdminOptions {
        hostname = configurations.valkeyAdminHostname
        path = configurations.valkeyAdminPath
        basicAuthSecretName = configurations.valkeyAdminBasicAuthSecret
    }
