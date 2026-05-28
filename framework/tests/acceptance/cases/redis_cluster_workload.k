"""
Acceptance fixture: RedisClusterModule through the IDP render path.
"""

import ._helpers as h
import templates.redis.v1_0_0.redis as redis

_module = redis.RedisClusterModule {
    name = "acceptance-redis-cluster"
    namespace = "idp-acceptance-redis-cluster"
    configurations = {}
    asset = {version = "7.0.12"}
    dependsOn = []
    clusterName = "acceptance-redis-cluster"
    clusterSize = 3
    storageSize = "1Gi"
}.instance

h.render_accessory("idp-acceptance-redis-cluster", _module)

