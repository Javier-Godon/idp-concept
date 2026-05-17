"""Backward-compatible Logstash template wrapper.

New code should prefer explicit versioned imports such as:
`import templates.elastic.v7_10_2.logstash as logstash` or
`import templates.elastic.v9_4_1.logstash as logstash`.
"""

import templates.elastic.v7_10_2.logstash as logstash_v7_wrapper

LogstashResources = logstash_v7_wrapper.LogstashResources
LogstashSpec = logstash_v7_wrapper.LogstashSpec
LogstashModule = logstash_v7_wrapper.LogstashModule
build_logstash_configmap = logstash_v7_wrapper.build_logstash_configmap
build_logstash_deployment = logstash_v7_wrapper.build_logstash_deployment
build_logstash_service = logstash_v7_wrapper.build_logstash_service
build_logstash_pdb = logstash_v7_wrapper.build_logstash_pdb
build_logstash_resources = logstash_v7_wrapper.build_logstash_resources
