import models.modules.thirdparty_helm as th
import runtime

test_basic_thirdparty_helm_spec = lambda {
    _spec = th.ThirdPartyHelmSpec {
        name = "questdb"
        namespace = "data"
        chart = "questdb/questdb"
        version = "0.32.0"
    }
    assert _spec.name == "questdb"
    assert _spec.namespace == "data"
    assert _spec.chart == "questdb/questdb"
    assert _spec.version == "0.32.0"
    assert _spec.createNamespace == True
    assert _spec.wait == True
    assert _spec.timeout == "10m"
}

test_thirdparty_helm_spec_with_values = lambda {
    _spec = th.ThirdPartyHelmSpec {
        name = "grafana"
        namespace = "monitoring"
        chart = "oci://registry-1.docker.io/bitnamicharts/grafana"
        version = "11.3.0"
        repository = "https://charts.bitnami.com/bitnami"
        values = {
            "persistence.enabled" = "true"
            "persistence.size" = "10Gi"
        }
    }
    assert _spec.repository == "https://charts.bitnami.com/bitnami"
    assert _spec.values["persistence.enabled"] == "true"
}

test_thirdparty_helm_spec_rejects_latest = lambda {
    _err = runtime.catch(lambda {
        th.ThirdPartyHelmSpec {
            name = "bad"
            namespace = "ns"
            chart = "repo/chart"
            version = "latest"
        }
    })
    assert _err != Undefined, "expected check block to reject 'latest' version"
}

test_thirdparty_helm_spec_rejects_empty_version = lambda {
    _err = runtime.catch(lambda {
        th.ThirdPartyHelmSpec {
            name = "bad"
            namespace = "ns"
            chart = "repo/chart"
            version = ""
        }
    })
    assert _err != Undefined, "expected check block to reject empty version"
}

test_build_thirdparty_helm_manifest = lambda {
    _spec = th.ThirdPartyHelmSpec {
        name = "questdb"
        namespace = "data"
        chart = "questdb/questdb"
        version = "0.32.0"
        values = {
            "persistence.size" = "50Gi"
        }
    }
    _result = th.build_thirdparty_helm(_spec)
    assert _result.metadata.name == "questdb"
    assert _result.metadata.namespace == "data"
    assert _result.spec.chart == "questdb/questdb"
    assert _result.spec.version == "0.32.0"
    assert _result.spec.values["persistence.size"] == "50Gi"
}
