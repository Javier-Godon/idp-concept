"""
Acceptance fixture: Elastic v9 Kibana ECK CR through the IDP render path.
"""
import ._helpers as h
import templates.elastic.v9_4_1.kibana as kibana
_namespace = "idp-acceptance-kibana-v9"
_resource = kibana.build_kibana(kibana.KibanaSpec {
    name = "acceptance-kibana-v9"
    namespace = _namespace
    elasticsearchRef = "acceptance-elasticsearch-v9"
    count = 1
})
_module = h.wrap_accessory("acceptance-kibana-v9", _namespace, "kibana.k8s.elastic.co/v1", "Kibana", [_resource], "9.4.1")
h.render_accessory(_namespace, _module)
