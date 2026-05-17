import runtime
import templates.kibana as kibana

test_kibana_resources = lambda {
    _resources = kibana.build_kibana_resources(kibana.KibanaSpec {
        name = "kibana"
        namespace = "search"
        elasticsearchHosts = ["http://elasticsearch:9200"]
    })

    assert len(_resources) == 4
    assert _resources[0].kind == "ConfigMap"
    assert "elasticsearch.hosts" in _resources[0].data["kibana.yml"]
    assert _resources[1].kind == "Service"
    assert _resources[2].kind == "Deployment"
    assert _resources[2].spec.template.spec.containers[0].image == "docker.elastic.co/kibana/kibana-oss:7.10.2"
    assert _resources[3].kind == "PodDisruptionBudget"
}

test_kibana_extra_config = lambda {
    _config = kibana.build_kibana_config(kibana.KibanaSpec {
        name = "kibana"
        namespace = "search"
        elasticsearchHosts = ["http://elasticsearch:9200"]
        serverBasePath = "/kibana"
        extraConfig = {"monitoring.ui.container.elasticsearch.enabled" = "true"}
    })

    assert "server.basePath: /kibana" in _config
    assert "monitoring.ui.container.elasticsearch.enabled: true" in _config
}

test_kibana_rejects_non_oss_version = lambda {
    _err = runtime.catch(lambda {
        kibana.KibanaSpec {
            name = "kibana"
            namespace = "search"
            version = "8.15.0"
            elasticsearchHosts = ["http://elasticsearch:9200"]
        }
    })
    assert _err != Undefined, "Expected validation error for non-OSS Kibana version"
}

test_kibana_rejects_empty_hosts = lambda {
    _err = runtime.catch(lambda {
        kibana.KibanaSpec {
            name = "kibana"
            namespace = "search"
            elasticsearchHosts = []
        }
    })
    assert _err != Undefined, "Expected validation error for empty Elasticsearch hosts"
}
