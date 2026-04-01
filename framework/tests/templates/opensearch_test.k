"""
OpenSearch Cluster Template Tests.

Tests the build_opensearch_cluster lambda for the
OpenSearch Kubernetes Operator (opensearch.org/v1).
"""
import templates.opensearch as os
import runtime

# === Test: build_opensearch_cluster generates correct CRD ===
test_build_opensearch_basic = lambda {
    _result = os.build_opensearch_cluster(os.OpenSearchClusterSpec {
        name = "my-os"
        namespace = "search"
        version = "2.17.0"
        nodePools = [os.NodePoolSpec {
            component = "masters"
            replicas = 3
            diskSize = "30Gi"
            roles = ["cluster_manager", "data"]
        }]
    })
    assert _result.apiVersion == "opensearch.org/v1"
    assert _result.kind == "OpenSearchCluster"
    assert _result.metadata.name == "my-os"
    assert _result.metadata.namespace == "search"
    assert _result.spec.general.serviceName == "my-os"
    assert _result.spec.general.version == "2.17.0"
    assert _result.spec.nodePools[0].component == "masters"
    assert _result.spec.nodePools[0].replicas == 3
    assert _result.spec.nodePools[0].diskSize == "30Gi"
    assert _result.spec.nodePools[0].roles[0] == "cluster_manager"
}

# === Test: OpenSearch with dashboards ===
test_build_opensearch_with_dashboards = lambda {
    _result = os.build_opensearch_cluster(os.OpenSearchClusterSpec {
        name = "my-os"
        namespace = "search"
        version = "2.17.0"
        dashboards = os.DashboardsSpec {
            enable = True
            replicas = 1
            version = "2.17.0"
        }
        nodePools = [os.NodePoolSpec {
            component = "masters"
            replicas = 3
            diskSize = "30Gi"
            roles = ["cluster_manager", "data"]
        }]
    })
    assert _result.spec.dashboards.enable == True
    assert _result.spec.dashboards.replicas == 1
    assert _result.spec.dashboards.version == "2.17.0"
}

# === Test: OpenSearch with multiple node pools ===
test_build_opensearch_multi_pool = lambda {
    _result = os.build_opensearch_cluster(os.OpenSearchClusterSpec {
        name = "my-os"
        namespace = "search"
        version = "2.17.0"
        nodePools = [
            os.NodePoolSpec {
                component = "masters"
                replicas = 3
                diskSize = "10Gi"
                roles = ["cluster_manager"]
            }
            os.NodePoolSpec {
                component = "data"
                replicas = 5
                diskSize = "100Gi"
                roles = ["data"]
                resources = {
                    requests = {memory = "4Gi", cpu = "1"}
                    limits = {memory = "4Gi", cpu = "2"}
                }
            }
        ]
    })
    assert len(_result.spec.nodePools) == 2
    assert _result.spec.nodePools[0].component == "masters"
    assert _result.spec.nodePools[1].component == "data"
    assert _result.spec.nodePools[1].replicas == 5
    assert _result.spec.nodePools[1].resources.requests.memory == "4Gi"
}

# === Test: OpenSearch with additional config ===
test_build_opensearch_with_config = lambda {
    _result = os.build_opensearch_cluster(os.OpenSearchClusterSpec {
        name = "my-os"
        namespace = "search"
        version = "2.17.0"
        additionalConfig = {
            "plugins.security.ssl.http.enabled" = "true"
        }
        nodePools = [os.NodePoolSpec {
            component = "nodes"
            replicas = 3
            diskSize = "30Gi"
            roles = ["cluster_manager", "data"]
        }]
    })
    assert _result.spec.general.additionalConfig["plugins.security.ssl.http.enabled"] == "true"
}

# === Test: OpenSearch with monitoring ===
test_build_opensearch_with_monitoring = lambda {
    _result = os.build_opensearch_cluster(os.OpenSearchClusterSpec {
        name = "my-os"
        namespace = "search"
        version = "2.17.0"
        monitoring = True
        nodePools = [os.NodePoolSpec {
            component = "nodes"
            replicas = 3
            diskSize = "30Gi"
            roles = ["cluster_manager", "data"]
        }]
    })
    assert _result.spec.general.monitoring.enable == True
}

# === Test: Validation — version must not be empty ===
test_opensearch_rejects_empty_version = lambda {
    _err = runtime.catch(lambda {
        os.OpenSearchClusterSpec {
            name = "bad"
            namespace = "search"
            version = ""
            nodePools = [os.NodePoolSpec {
                component = "nodes"
                replicas = 3
                diskSize = "10Gi"
                roles = ["data"]
            }]
        }
    })
    assert _err, "Expected validation error for empty version"
}

# === Test: Validation — nodePools must not be empty ===
test_opensearch_rejects_empty_nodepools = lambda {
    _err = runtime.catch(lambda {
        os.OpenSearchClusterSpec {
            name = "bad"
            namespace = "search"
            version = "2.17.0"
            nodePools = []
        }
    })
    assert _err, "Expected validation error for empty nodePools"
}

# === Test: Validation — nodePool replicas must be >= 1 ===
test_opensearch_rejects_zero_replicas = lambda {
    _err = runtime.catch(lambda {
        os.NodePoolSpec {
            component = "bad"
            replicas = 0
            diskSize = "10Gi"
            roles = ["data"]
        }
    })
    assert _err, "Expected validation error for replicas=0"
}
