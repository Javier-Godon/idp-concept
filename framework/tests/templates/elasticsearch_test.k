import runtime
import templates.elastic.v7_10_2.elasticsearch as es

test_elasticsearch_resources = lambda {
    _resources = es.build_elasticsearch_resources(es.ElasticsearchSpec {
        name = "elasticsearch"
        namespace = "search"
    })

    assert len(_resources) == 5
    assert _resources[0].kind == "ConfigMap"
    assert "cluster.initial_master_nodes" in _resources[0].data["elasticsearch.yml"]
    assert _resources[1].metadata.name == "elasticsearch-headless"
    assert _resources[2].kind == "Service"
    assert _resources[3].kind == "StatefulSet"
    assert _resources[3].spec.replicas == 3
    assert _resources[3].spec.template.spec.containers[0].image == "docker.elastic.co/elasticsearch/elasticsearch-oss:7.10.2"
    assert _resources[3].spec.volumeClaimTemplates[0].spec.resources.requests.storage == "100Gi"
    assert _resources[4].kind == "PodDisruptionBudget"
}

test_elasticsearch_custom_storage = lambda {
    _sts = es.build_elasticsearch_statefulset(es.ElasticsearchSpec {
        name = "elasticsearch"
        namespace = "search"
        storageSize = "250Gi"
        storageClassName = "fast-ssd"
        javaOpts = "-Xms4g -Xmx4g"
    })

    assert _sts.spec.volumeClaimTemplates[0].spec.storageClassName == "fast-ssd"
    assert _sts.spec.volumeClaimTemplates[0].spec.resources.requests.storage == "250Gi"
    assert _sts.spec.template.spec.containers[0].env[0].value == "-Xms4g -Xmx4g"
}

test_elasticsearch_rejects_non_oss_version = lambda {
    _err = runtime.catch(lambda {
        es.ElasticsearchSpec {
            name = "elasticsearch"
            namespace = "search"
            version = "8.15.0"
        }
    })
    assert _err != Undefined, "Expected validation error for non-OSS Elasticsearch version"
}

test_elasticsearch_rejects_low_replicas = lambda {
    _err = runtime.catch(lambda {
        es.ElasticsearchSpec {
            name = "elasticsearch"
            namespace = "search"
            replicas = 1
        }
    })
    assert _err != Undefined, "Expected validation error for low Elasticsearch replicas"
}
