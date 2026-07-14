"""
Acceptance fixture: QuestDB + Apache Superset analytics stack.

Tests: QuestDB and Superset co-deployed in one namespace. Superset is
configured with QuestDB's PostgreSQL wire protocol endpoint (port 8812)
as a pre-registered data source URI, following the official integration guide:
  https://questdb.com/docs/integrations/visualization/superset/

Integration wiring summary:
  - QuestDB Helm chart exposes a Kubernetes Service on port 8812 (PG wire protocol).
  - Superset receives the QuestDB SQLAlchemy URI via extraSecretEnv so that
    init or bootstrap scripts can register the data source connection.
  - The acceptance runtime test verifies TCP connectivity to port 8812 from
    within the cluster, confirming the network path is reachable.
"""

import ._helpers as h
import templates.questdb.v1_0_0.questdb as qdb
import templates.superset.v1_0_0.superset as superset

_namespace = "idp-acceptance-questdb-superset-stack"

# QuestDB service name — also the Helm release name within the namespace
_questdb_name = "acceptance-questdb"
_questdb_host = "${_questdb_name}.${_namespace}.svc.cluster.local"

# QuestDB time-series database deployed via the official Helm chart.
# Exposes port 8812 for the PostgreSQL wire protocol used by Superset.
_qdb_resource = qdb.build_questdb_release(qdb.QuestDBSpec {
    name = _questdb_name
    namespace = _namespace
    chartVersion = "0.32.0"
    storageSize = "1Gi"
})
_questdb = h.wrap_accessory(
    _questdb_name,
    _namespace,
    "helm.toolkit.fluxcd.io/v2beta1",
    "HelmRelease",
    [_qdb_resource],
    "0.32.0"
)

# Superset analytics platform with QuestDB registered as a data source.
# databaseUri is Superset's own metadata backend (separate from QuestDB data).
# extraSecretEnv exposes the QuestDB SQLAlchemy URI for bootstrap/init scripts.
# QuestDB uses its PostgreSQL wire protocol endpoint on port 8812.
_superset = superset.SupersetModule {
    name = "acceptance-superset"
    namespace = _namespace
    footprint = "development"
    databaseUri = "postgresql://superset:test@postgres.default.svc.cluster.local:5432/superset"
    redisUri = "redis://redis.default.svc.cluster.local:6379/0"
    webReplicas = 1
    workerReplicas = 1
    persistenceSize = "5Gi"
    extraValues = {
        # QuestDB datasource URI exposed via env var for init/bootstrap scripts.
        # Superset connects to QuestDB through the PostgreSQL wire protocol
        # using the questdb+psycopg2 SQLAlchemy dialect on port 8812.
        "extraSecretEnv.QUESTDB_SQLALCHEMY_URI" = "questdb+psycopg2://admin:quest@${_questdb_host}:8812/qdb"
        "init.enabled" = "true"
        "init.dbUpgrade" = "true"
    }
}.instance

h.render_stack(
    [_namespace],
    [],
    [_questdb, _superset]
)
