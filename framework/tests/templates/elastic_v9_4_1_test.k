import runtime
import templates.elastic.v9_4_1.elasticsearch as elasticsearch_v9
import templates.elastic.v9_4_1.kibana as kibana_v9
import templates.elastic.v9_4_1.logstash as logstash_v9

_pipeline = "input { beats { port => 5044 } }\noutput { elasticsearch { hosts => [\"https://elasticsearch-es-http:9200\"] } }\n"

test_elasticsearch_v9_eck_cr = lambda {
    _result = elasticsearch_v9.build_elasticsearch_cluster(elasticsearch_v9.ElasticsearchSpec {
        name = "elasticsearch"
        namespace = "search"
    })

    assert _result.apiVersion == "elasticsearch.k8s.elastic.co/v1"
    assert _result.kind == "Elasticsearch"
    assert _result.spec.version == "9.4.1"
    assert _result.spec.nodeSets[0].name == "default"
    assert _result.spec.nodeSets[0].count == 3
    assert _result.spec.nodeSets[0].volumeClaimTemplates[0].spec.resources.requests.storage == "100Gi"
}

test_elasticsearch_v9_custom_nodeset = lambda {
    _result = elasticsearch_v9.build_elasticsearch_cluster(elasticsearch_v9.ElasticsearchSpec {
        name = "elasticsearch"
        namespace = "search"
        nodeSets = [elasticsearch_v9.ElasticsearchNodeSetSpec {
            name = "hot"
            count = 3
            roles = ["master", "data_hot", "ingest"]
            storageSize = "250Gi"
            storageClassName = "fast-ssd"
        }]
    })

    assert _result.spec.nodeSets[0].config["node.roles"][1] == "data_hot"
    assert _result.spec.nodeSets[0].volumeClaimTemplates[0].spec.storageClassName == "fast-ssd"
}

test_elasticsearch_v9_monitoring_secure_settings_and_tls = lambda {
    _result = elasticsearch_v9.build_elasticsearch_cluster(elasticsearch_v9.ElasticsearchSpec {
        name = "elasticsearch"
        namespace = "search"
        serviceType = "LoadBalancer"
        monitoring = True
        httpTLSDisabled = True
        secureSettings = [{secretName = "elastic-secure-settings"}]
    })

    assert _result.spec.http.service.spec.$type == "LoadBalancer"
    assert _result.spec.http.tls.selfSignedCertificate.disabled == True
    assert _result.spec.secureSettings[0].secretName == "elastic-secure-settings"
    assert _result.spec.monitoring.metrics.elasticsearchRefs[0].name == "elasticsearch"
}

test_elasticsearch_v9_rejects_other_version = lambda {
    _err = runtime.catch(lambda {
        elasticsearch_v9.ElasticsearchSpec {
            name = "elasticsearch"
            namespace = "search"
            version = "9.3.0"
        }
    })
    assert _err != Undefined, "Expected version pin validation error"
}

test_kibana_v9_eck_cr = lambda {
    _result = kibana_v9.build_kibana(kibana_v9.KibanaSpec {
        name = "kibana"
        namespace = "search"
        elasticsearchRef = "elasticsearch"
    })

    assert _result.apiVersion == "kibana.k8s.elastic.co/v1"
    assert _result.kind == "Kibana"
    assert _result.spec.version == "9.4.1"
    assert _result.spec.count == 2
    assert _result.spec.elasticsearchRef.name == "elasticsearch"
}

test_kibana_v9_config_secure_settings_and_service = lambda {
    _result = kibana_v9.build_kibana(kibana_v9.KibanaSpec {
        name = "kibana"
        namespace = "search"
        elasticsearchRef = "elasticsearch"
        serviceType = "NodePort"
        config = {"server.publicBaseUrl" = "https://kibana.example.com"}
        secureSettings = [{secretName = "kibana-secure-settings"}]
    })

    assert _result.spec.http.service.spec.$type == "NodePort"
    assert _result.spec.config["server.publicBaseUrl"] == "https://kibana.example.com"
    assert _result.spec.secureSettings[0].secretName == "kibana-secure-settings"
}

test_kibana_v9_rejects_missing_ref = lambda {
    _err = runtime.catch(lambda {
        kibana_v9.KibanaSpec {
            name = "kibana"
            namespace = "search"
            elasticsearchRef = ""
        }
    })
    assert _err != Undefined, "Expected missing elasticsearchRef validation error"
}

test_logstash_v9_eck_cr = lambda {
    _result = logstash_v9.build_logstash(logstash_v9.LogstashSpec {
        name = "logstash"
        namespace = "search"
        elasticsearchRefs = ["elasticsearch"]
        pipelines = [logstash_v9.PipelineSpec {id = "main", config = _pipeline}]
    })

    assert _result.apiVersion == "logstash.k8s.elastic.co/v1alpha1"
    assert _result.kind == "Logstash"
    assert _result.spec.version == "9.4.1"
    assert _result.spec.pipelines[0]["pipeline.id"] == "main"
    assert _result.spec.elasticsearchRefs[0].name == "elasticsearch"
}

test_logstash_v9_config_and_secure_settings = lambda {
    _result = logstash_v9.build_logstash(logstash_v9.LogstashSpec {
        name = "logstash"
        namespace = "search"
        serviceType = "LoadBalancer"
        elasticsearchRefs = ["elasticsearch"]
        pipelines = [logstash_v9.PipelineSpec {id = "main", config = _pipeline}]
        config = {"api.http.host" = "0.0.0.0"}
        secureSettings = [{secretName = "logstash-secure-settings"}]
    })

    assert _result.spec.services[0].service.spec.$type == "LoadBalancer"
    assert _result.spec.config["api.http.host"] == "0.0.0.0"
    assert _result.spec.secureSettings[0].secretName == "logstash-secure-settings"
}

test_logstash_v9_rejects_empty_pipelines = lambda {
    _err = runtime.catch(lambda {
        logstash_v9.LogstashSpec {
            name = "logstash"
            namespace = "search"
            pipelines = []
        }
    })
    assert _err != Undefined, "Expected empty pipelines validation error"
}

