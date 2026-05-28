"""
Acceptance fixture: Elasticsearch OSS standalone workload.

This validates StatefulSet/Service/ConfigMap/PDB rendering with server-side
dry-run. It is intentionally dry-run only because a real Elasticsearch rollout is
too heavy for the default kind acceptance path.
"""

import ._helpers as h
import templates.elastic.v7_10_2.elasticsearch as elasticsearch

_module = elasticsearch.ElasticsearchModule {
    name = "elasticsearch"
    namespace = "idp-acceptance-elasticsearch"
    configurations = {}
    asset = {version = "7.10.2"}
    dependsOn = []
    replicas = 3
    storageSize = "1Gi"
}.instance

h.render_component("idp-acceptance-elasticsearch", _module)
