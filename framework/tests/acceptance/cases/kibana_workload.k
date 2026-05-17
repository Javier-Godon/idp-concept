"""
Acceptance fixture: Kibana OSS standalone workload.

This validates Deployment/Service/ConfigMap/PDB rendering with server-side
dry-run. It is not applied by default because it expects Elasticsearch.
"""

import manifests
import templates.kibana as kibana

_namespace = {
    apiVersion = "v1"
    kind = "Namespace"
    metadata = {name = "idp-acceptance-kibana"}
}

_resources = kibana.build_kibana_resources(kibana.KibanaSpec {
    name = "kibana"
    namespace = "idp-acceptance-kibana"
    replicas = 1
    elasticsearchHosts = ["http://elasticsearch:9200"]
})

manifests.yaml_stream([_namespace] + _resources)
