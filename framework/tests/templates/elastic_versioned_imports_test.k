import templates.elastic.v7_10_2.elasticsearch as elasticsearch_v7_explicit
import templates.elastic.v7_10_2.kibana as kibana_v7_explicit
import templates.elastic.v7_10_2.logstash as logstash_v7_explicit

_pipeline = "input { beats { port => 5044 } }\noutput { stdout { codec => rubydebug } }\n"

test_v7_explicit_elasticsearch_import = lambda {
    _resources = elasticsearch_v7_explicit.build_elasticsearch_resources(elasticsearch_v7_explicit.ElasticsearchSpec {
        name = "elasticsearch"
        namespace = "search"
    })
    assert _resources[3].spec.template.spec.containers[0].image == "docker.elastic.co/elasticsearch/elasticsearch-oss:7.10.2"
}

test_v7_explicit_kibana_import = lambda {
    _resources = kibana_v7_explicit.build_kibana_resources(kibana_v7_explicit.KibanaSpec {
        name = "kibana"
        namespace = "search"
        elasticsearchHosts = ["http://elasticsearch:9200"]
    })
    assert _resources[2].spec.template.spec.containers[0].image == "docker.elastic.co/kibana/kibana-oss:7.10.2"
}

test_v7_explicit_logstash_import = lambda {
    _resources = logstash_v7_explicit.build_logstash_resources(logstash_v7_explicit.LogstashSpec {
        name = "logstash"
        namespace = "search"
        pipelineConfig = _pipeline
    })
    assert _resources[2].spec.template.spec.containers[0].image == "docker.elastic.co/logstash/logstash-oss:7.10.2"
}

