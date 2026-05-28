"""
Acceptance fixture: OpenSearchClusterModule through the IDP render path.
"""

import ._helpers as h
import templates.opensearch.v2_17_0.opensearch as os

_module = os.OpenSearchClusterModule {
    name = "acceptance-opensearch"
    namespace = "idp-acceptance-opensearch"
    configurations = {}
    asset = {version = "2.17.0"}
    dependsOn = []
    clusterName = "acceptance-opensearch"
    version = "2.17.0"
    securityDisabled = True
    nodePools = [os.NodePoolSpec {
        component = "nodes"
        replicas = 1
        diskSize = "1Gi"
        roles = ["cluster_manager", "data", "ingest"]
    }]
    dashboards = os.DashboardsSpec {
        enable = True
        replicas = 1
        version = "2.17.0"
    }
}.instance

h.render_accessory("idp-acceptance-opensearch", _module)

