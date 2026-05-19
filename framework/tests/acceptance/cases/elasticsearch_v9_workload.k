"""
Acceptance fixture: Elastic v9 Elasticsearch ECK CR through the IDP render path.
"""
import ._helpers as h
import templates.elastic.v9_4_1.elasticsearch as es
_namespace = "idp-acceptance-elasticsearch-v9"
_resource = es.build_elasticsearch_cluster(es.ElasticsearchSpec {
    name = "acceptance-elasticsearch-v9"
    namespace = _namespace
    nodeSets = [es.ElasticsearchNodeSetSpec {name = "default", count = 1, storageSize = "1Gi"}]
})
_module = h.wrap_accessory("acceptance-elasticsearch-v9", _namespace, "elasticsearch.k8s.elastic.co/v1", "Elasticsearch", [_resource], "9.4.1")
h.render_accessory(_namespace, _module)
