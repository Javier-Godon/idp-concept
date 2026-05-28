import runtime
import templates.opensearch.v2_17_0.opensearch_dashboards as osd

test_opensearch_dashboards_resources = lambda {
    _resources = osd.build_opensearch_dashboards_resources(osd.OpenSearchDashboardsSpec {
        name = "dashboards"
        namespace = "search"
        opensearchHosts = ["https://opensearch-cluster:9200"]
    })

    assert len(_resources) == 4
    assert _resources[0].kind == "ConfigMap"
    assert "opensearch.hosts" in _resources[0].data["opensearch_dashboards.yml"]
    assert _resources[1].kind == "Service"
    assert _resources[1].spec.ports[0].port == 5601
    assert _resources[2].kind == "Deployment"
    assert _resources[2].spec.template.spec.containers[0].image == "opensearchproject/opensearch-dashboards:2.17.0"
    assert _resources[3].kind == "PodDisruptionBudget"
}

test_opensearch_dashboards_extra_config = lambda {
    _config = osd.build_opensearch_dashboards_config(osd.OpenSearchDashboardsSpec {
        name = "dashboards"
        namespace = "search"
        opensearchHosts = ["https://opensearch-cluster:9200"]
        serverBasePath = "/dashboards"
        extraConfig = {"opensearch.ssl.verificationMode" = "certificate"}
    })

    assert "server.basePath: /dashboards" in _config
    assert "opensearch.ssl.verificationMode: certificate" in _config
}

test_opensearch_dashboards_single_replica_skips_pdb = lambda {
    _resources = osd.build_opensearch_dashboards_resources(osd.OpenSearchDashboardsSpec {
        name = "dashboards"
        namespace = "search"
        replicas = 1
        opensearchHosts = ["https://opensearch-cluster:9200"]
    })

    assert len(_resources) == 3
}

test_opensearch_dashboards_custom_runtime = lambda {
    _deploy = osd.build_opensearch_dashboards_deployment(osd.OpenSearchDashboardsSpec {
        name = "dashboards"
        namespace = "search"
        replicas = 3
        port = 5602
        opensearchHosts = ["https://opensearch-cluster:9200"]
        env = [{name = "NODE_OPTIONS", value = "--max-old-space-size=1024"}]
        resources = osd.OpenSearchDashboardsResources {
            cpuRequest = "500m"
            cpuLimit = "1500m"
            memoryRequest = "1Gi"
            memoryLimit = "3Gi"
        }
    })

    _container = _deploy.spec.template.spec.containers[0]
    assert _deploy.spec.replicas == 3
    assert _container.ports[0].containerPort == 5602
    assert _container.env[0].name == "NODE_OPTIONS"
    assert _container.resources.requests.cpu == "500m"
    assert _container.securityContext.allowPrivilegeEscalation == False
}

test_opensearch_dashboards_rejects_empty_hosts = lambda {
    _err = runtime.catch(lambda {
        osd.OpenSearchDashboardsSpec {
            name = "dashboards"
            namespace = "search"
            opensearchHosts = []
        }
    })
    assert _err != Undefined, "Expected validation error for empty OpenSearch hosts"
}
