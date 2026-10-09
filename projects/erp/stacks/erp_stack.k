"""
Shared erp stack template.
Profile-specific folders override only the values that differ.
"""

import framework.models.stack
import framework.models.compatibility as compat
import erp.modules.data.erp_cache.erp_cache_module_def as erp_cache
# koncept:imports:end

schema ErpStack(stack.Stack):
    compatibility = compat.FrameworkCompatibility {
        version = "dev"
        versionConstraint = ">=0.1.0 <1.0.0"
        supportTier = "tier-1"
        source = "local"
        supportWindow = "until next minor framework release"
    }

    # No stack-level namespace: the XValkeyInstance composition owns its namespace.
    k8snamespaces = []

    _cache = erp_cache.ErpCacheModule {
        name = "erp-cache"
        namespace = instanceConfigurations.cacheNamespace
        asset = {version = "8.1.10"}
        configurations = instanceConfigurations
        dependsOn = []
    }.instance

    # koncept:modules:end

    components = []  # koncept:components
    accessories = [_cache]  # koncept:accessories
