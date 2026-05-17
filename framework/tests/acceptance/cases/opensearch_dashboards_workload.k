"""
Acceptance fixture: OpenSearch Dashboards standalone workload.

This validates the generated Kubernetes-native manifests with server-side dry-run.
It is not applied by default because the real dashboard image expects a backing
OpenSearch endpoint.
"""

import manifests
import templates.opensearch_dashboards as dashboards

_namespace = {
    apiVersion = "v1"
    kind = "Namespace"
    metadata = {name = "idp-acceptance-opensearch-dashboards"}
}

_resources = dashboards.build_opensearch_dashboards_resources(dashboards.OpenSearchDashboardsSpec {
    name = "opensearch-dashboards"
    namespace = "idp-acceptance-opensearch-dashboards"
    replicas = 1
    opensearchHosts = ["https://opensearch.example.internal:9200"]
})

manifests.yaml_stream([_namespace] + _resources)
