"""
Acceptance scenario: DataPrepperModule wired to an OpenSearchClusterModule.

This validates the IDP render path for the common runtime dependency:
Data Prepper can render independently, but a useful pipeline normally needs a
reachable OpenSearch endpoint and the OpenSearch operator to reconcile the
OpenSearchCluster CR.
"""

import ._helpers as h
import templates.dataprepper as dp
import templates.opensearch as os

_namespace = "idp-acceptance-dataprepper-opensearch"

_opensearch = os.OpenSearchClusterModule {
    name = "acceptance-opensearch"
    namespace = _namespace
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
}.instance

_pipeline = "entry-pipeline:\n  source:\n    http:\n      path: /log/ingest\n  sink:\n    - opensearch:\n        hosts: [\"http://acceptance-opensearch:9200\"]\n        index: acceptance-events\n        insecure: true\n"

_dataprepper = dp.DataPrepperModule {
    name = "acceptance-dataprepper"
    namespace = _namespace
    configurations = {}
    asset = {version = "2.10.2"}
    dependsOn = [_opensearch]
    replicas = 1
    pipelineConfig = _pipeline
    resources = dp.DataPrepperResources {
        cpuRequest = "100m"
        cpuLimit = "500m"
        memoryRequest = "512Mi"
        memoryLimit = "1Gi"
    }
}.instance

h.render_stack([_namespace], [_dataprepper], [_opensearch])

