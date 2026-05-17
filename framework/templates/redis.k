"""Backward-compatible Redis template wrapper.

The implementation lives in `templates.redis.main`. Keep this root module thin so
existing imports such as `import templates.redis as redis` continue to work
without duplicating template implementation code.
"""

import templates.redis.main as redis_compat

RedisSpec = redis_compat.RedisSpec
RedisClusterSpec = redis_compat.RedisClusterSpec
build_redis = redis_compat.build_redis
build_redis_cluster = redis_compat.build_redis_cluster
RedisModule = redis_compat.RedisModule
RedisClusterModule = redis_compat.RedisClusterModule
