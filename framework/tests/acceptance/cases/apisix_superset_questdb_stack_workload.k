"""
Acceptance fixture: APISIX + Superset + QuestDB analytics stack integration.
Tests: Multi-module deployment with routing and data connections.
"""

import ._helpers as h
import templates.apisix.v1_0_0.apisix as apisix
import templates.superset.v1_0_0.superset as superset
import templates.questdb.v1_0_0.questdb as qdb

_namespace = "idp-acceptance-analytics-stack"

# APISIX Gateway
_gateway = apisix.APIGatewayModule {
    name = "analytics-gateway"
    namespace = _namespace
    footprint = "development"
    gatewayType = "NodePort"
    etcdReplicas = 1
}.instance

# QuestDB time-series database
_qdb_resource = qdb.build_questdb_release(qdb.QuestDBSpec {
    name = "acceptance-questdb"
    namespace = _namespace
    chartVersion = "0.32.0"
    storageSize = "1Gi"
    footprint = "development"
})
_questdb = h.wrap_accessory("acceptance-questdb", _namespace, "helm.toolkit.fluxcd.io/v2beta1", "HelmRelease", [_qdb_resource], "0.32.0")

# Superset analytics platform
_superset = superset.SupersetModule {
    name = "analytics-superset"
    namespace = _namespace
    footprint = "development"
    databaseUri = "postgresql://superset:test@postgres-dev.default:5432/superset"
    redisUri = "redis://redis-dev.default:6379/0"
    webReplicas = 1
    workerReplicas = 1
    persistenceSize = "5Gi"
}.instance

h.render_stack(
    [_namespace],
    [_gateway, _superset],
    []
)

