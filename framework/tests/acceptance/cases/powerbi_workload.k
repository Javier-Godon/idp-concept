"""
Acceptance fixture: Power BI connector for QuestDB/Superset integration.
Tests: ConfigMap-based integration helper rendering.
"""

import ._helpers as h
import templates.powerbi.v1_0_0.powerbi_connector as pbi

_namespace = "idp-acceptance-powerbi"
_module = pbi.PowerBIConnectorModule {
    name = "acceptance-pbi-connector"
    namespace = _namespace
    questdbHost = "questdb.default.svc.cluster.local"
    questdbPort = 5432
    questdbDatabase = "qdb"
    questdbUsername = "admin"
    supersetHost = "superset.default.svc.cluster.local"
    supersetPort = 8088
    postgresHost = "postgres.default.svc.cluster.local"
    postgresPort = 5432
    postgresDatabase = "warehouse"
    postgresUsername = "analytics_user"
    footprint = "development"
}.instance

h.render_accessory(_namespace, _module)

