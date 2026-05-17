"""
Acceptance fixture: Logstash OSS standalone workload.

This validates Deployment/Service/ConfigMap/PDB rendering with server-side
dry-run. It is not applied by default because it pulls a large runtime image.
"""

import manifests
import templates.logstash as logstash

_namespace = {
    apiVersion = "v1"
    kind = "Namespace"
    metadata = {name = "idp-acceptance-logstash"}
}

_pipeline = "input { beats { port => 5044 } }\noutput { stdout { codec => rubydebug } }\n"

_resources = logstash.build_logstash_resources(logstash.LogstashSpec {
    name = "logstash"
    namespace = "idp-acceptance-logstash"
    replicas = 1
    pipelineConfig = _pipeline
})

manifests.yaml_stream([_namespace] + _resources)
