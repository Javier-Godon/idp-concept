"""
Acceptance fixture: Kibana OSS standalone workload.

This validates Deployment/Service/ConfigMap/PDB rendering with server-side
dry-run. It is not applied by default because it expects Elasticsearch.
"""

import ._helpers as h
import templates.elastic.v7_10_2.kibana as kibana

_module = kibana.KibanaModule {
    name = "kibana"
    namespace = "idp-acceptance-kibana"
    configurations = {}
    asset = {version = "7.10.2"}
    dependsOn = []
    replicas = 1
    elasticsearchHosts = ["http://elasticsearch:9200"]
}.instance

h.render_component("idp-acceptance-kibana", _module)
