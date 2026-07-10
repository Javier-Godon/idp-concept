"""
Acceptance fixture: TimescaleDBModule through the IDP render path.
Tests: CNPG Cluster with TimescaleDB extension, footprint-based sizing.
Level: L1 (dry-run) — requires CloudNativePG operator CRD stubs.
"""

import ._helpers as h
import templates.timescale.v1_0_0.timescale as ts

_namespace = "idp-acceptance-timescale"
_module = ts.TimescaleDBModule {
    clusterName = "acceptance-timescaledb"
    namespace = _namespace
    footprint = "development"
    instances = 1
    storageSize = "5Gi"
    databaseName = "timescaledb"
    databaseOwner = "timescale_user"
    enablePodMonitor = False
    enablePDB = True
}.instance

h.render_accessory(_namespace, _module)
