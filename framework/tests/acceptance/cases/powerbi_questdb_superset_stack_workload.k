"""
Acceptance fixture: Power BI connector with full analytics backends.
Tests: Multi-datasource configuration (QuestDB + Superset + PostgreSQL).
"""

import ._helpers as h
import templates.powerbi.v1_0_0.powerbi_connector as pbi
import templates.questdb.v1_0_0.questdb as qdb
import templates.superset.v1_0_0.superset as superset

_namespace = "idp-acceptance-powerbi-full"

# QuestDB
_qdb_resource = qdb.build_questdb_release(qdb.QuestDBSpec {
    name = "full-questdb"
    namespace = _namespace
    storageSize = "1Gi"
})
_questdb = h.wrap_accessory("full-questdb", _namespace, "helm.toolkit.fluxcd.io/v2beta1", "HelmRelease", [_qdb_resource], "0.32.0")

# Superset
_superset = superset.SupersetModule {
    name = "full-superset"
    namespace = _namespace
    footprint = "development"
    databaseUri = "postgresql://superset:test@postgres-dev.default:5432/superset"
    persistenceSize = "5Gi"
}.instance

# Power BI Connector
_powerbi = pbi.PowerBIConnectorModule {
    name = "powerbi-full-connector"
    namespace = _namespace
    questdbHost = "full-questdb.${_namespace}.svc.cluster.local"
    questdbPort = 5432
    questdbDatabase = "qdb"
    questdbUsername = "admin"
    supersetHost = "full-superset.${_namespace}.svc.cluster.local"
    supersetPort = 8088
    postgresHost = "postgres.default.svc.cluster.local"
    postgresPort = 5432
    postgresDatabase = "warehouse"
    postgresUsername = "analytics_user"
    footprint = "development"
}.instance

h.render_stack(
    [_namespace],
    [_powerbi, _superset],
    []
)

