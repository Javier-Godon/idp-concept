"""
Acceptance fixture: Apache Superset analytics platform via Helm chart.
Tests: Rendering with database connection and environment-specific sizing.
"""

import ._helpers as h
import templates.superset.v1_0_0.superset as superset

_namespace = "idp-acceptance-superset"
_module = superset.SupersetModule {
    name = "acceptance-superset"
    namespace = _namespace
    footprint = "development"
    databaseUri = "postgresql://superset:test@postgres-dev.default:5432/superset"
    redisUri = "redis://redis-dev.default:6379/0"
    webPort = 8088
    webReplicas = 1
    workerReplicas = 1
    adminUsername = "admin"
    adminFirstName = "Test"
    adminLastName = "Admin"
    persistenceEnabled = True
    persistenceSize = "5Gi"
}.instance

h.render_accessory(_namespace, _module)

