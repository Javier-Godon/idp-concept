"""
Acceptance fixture: Logstash OSS standalone workload.

This validates Deployment/Service/ConfigMap/PDB rendering with server-side
dry-run. It is not applied by default because it pulls a large runtime image.
"""

import ._helpers as h
import templates.elastic.v7_10_2.logstash as logstash

_pipeline = "input { beats { port => 5044 } }\noutput { stdout { codec => rubydebug } }\n"

_module = logstash.LogstashModule {
    name = "logstash"
    namespace = "idp-acceptance-logstash"
    configurations = {}
    asset = {version = "7.10.2"}
    dependsOn = []
    replicas = 1
    pipelineConfig = _pipeline
}.instance

h.render_component("idp-acceptance-logstash", _module)
