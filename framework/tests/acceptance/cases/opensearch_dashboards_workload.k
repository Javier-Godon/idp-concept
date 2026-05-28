"""
Acceptance fixture: OpenSearch Dashboards standalone workload.

This validates the generated Kubernetes-native manifests with server-side dry-run.
It is not applied by default because the real dashboard image expects a backing
OpenSearch endpoint.
"""

import ._helpers as h
import templates.opensearch.v2_17_0.opensearch_dashboards as dashboards

_module = dashboards.OpenSearchDashboardsModule {
    name = "opensearch-dashboards"
    namespace = "idp-acceptance-opensearch-dashboards"
    configurations = {}
    asset = {version = "2.17.0"}
    dependsOn = []
    replicas = 1
    opensearchHosts = ["https://opensearch.example.internal:9200"]
}.instance

h.render_component("idp-acceptance-opensearch-dashboards", _module)
