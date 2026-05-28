"""
Acceptance fixture: RedisModule through the IDP render path.
"""

import ._helpers as h
import templates.redis.v1_0_0.redis as redis

_module = redis.RedisModule {
    name = "acceptance-redis"
    namespace = "idp-acceptance-redis"
    configurations = {}
    asset = {version = "7.0.12"}
    dependsOn = []
    redisName = "acceptance-redis"
    storageSize = "1Gi"
}.instance

h.render_accessory("idp-acceptance-redis", _module)

