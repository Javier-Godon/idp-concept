"""
Acceptance fixture: WebAppModule + RedisModule co-deployed in one stack.

Models a caching/session web application IDP stack: a webapp Deployment wired to
a Redis CR in the same namespace. Both modules are rendered through a single
RenderStack via render_stack.

The webapp uses the pause image and sets REDIS_HOST to the Redis service name.

Dry-run-only in acceptance_kind.sh. Real apply requires OT Redis Operator
and a working StorageClass (see docs/ACCEPTANCE_DEPENDENCIES.md).

Covers:
- Application + caching-layer IDP stack via render_stack
- WebApp Component + Redis Accessory in the same namespace
- Redis CR shape alongside Deployment resources in one manifest
- Cross-module env wiring: REDIS_HOST points at Redis service
"""

import ._helpers as h
import templates.webapp.v1_0_0.webapp as webapp
import templates.redis.v1_0_0.redis as redis

_namespace = "idp-acceptance-webapp-redis-stack"

_app = webapp.WebAppModule {
    name = "acceptance-webapp-redis"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "server.port: 8080\nredis.host: acceptance-redis-stack\nredis.port: 6379\n"}
    env = [
        {name = "REDIS_HOST", value = "acceptance-redis-stack"}
        {name = "REDIS_PORT", value = "6379"}
    ]
}.instance

_redis = redis.RedisModule {
    name = "acceptance-redis-stack"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.0.12"}
    dependsOn = []
    redisName = "acceptance-redis-stack"
    storageSize = "1Gi"
}.instance

h.render_stack([_namespace], [_app], [_redis])

