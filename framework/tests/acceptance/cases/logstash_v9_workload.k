"""
Acceptance fixture: Elastic v9 Logstash ECK CR through the IDP render path.
"""
import ._helpers as h
import templates.elastic.v9_4_1.logstash as logstash
_namespace = "idp-acceptance-logstash-v9"
_pipeline = "input { beats { port => 5044 } }\noutput { stdout { codec => rubydebug } }\n"
_resource = logstash.build_logstash(logstash.LogstashSpec {
    name = "acceptance-logstash-v9"
    namespace = _namespace
    count = 1
    elasticsearchRefs = ["acceptance-elasticsearch-v9"]
    pipelines = [logstash.PipelineSpec {id = "main", config = _pipeline}]
})
_module = h.wrap_accessory("acceptance-logstash-v9", _namespace, "logstash.k8s.elastic.co/v1alpha1", "Logstash", [_resource], "9.4.1")
h.render_accessory(_namespace, _module)
