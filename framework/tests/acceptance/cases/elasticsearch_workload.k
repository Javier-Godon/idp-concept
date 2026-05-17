"""
Acceptance fixture: Elasticsearch OSS standalone workload.

This validates StatefulSet/Service/ConfigMap/PDB rendering with server-side
dry-run. It is intentionally dry-run only because a real Elasticsearch rollout is
too heavy for the default kind acceptance path.
"""

import manifests
import templates.elasticsearch as elasticsearch

_namespace = {
    apiVersion = "v1"
    kind = "Namespace"
    metadata = {name = "idp-acceptance-elasticsearch"}
}

_resources = elasticsearch.build_elasticsearch_resources(elasticsearch.ElasticsearchSpec {
    name = "elasticsearch"
    namespace = "idp-acceptance-elasticsearch"
    storageSize = "1Gi"
})

manifests.yaml_stream([_namespace] + _resources)
