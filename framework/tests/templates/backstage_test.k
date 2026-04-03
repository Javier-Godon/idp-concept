import templates.backstage as bs

# --- Tests ---

test_backstage_default = lambda {
    _spec = bs.BackstageHelmSpec {
        name = "backstage"
        namespace = "backstage"
    }
    _result = bs.build_backstage_release(_spec)
    assert _result.metadata.name == "backstage"
    assert _result.metadata.namespace == "backstage"
    assert _result.spec.chart == "backstage/backstage"
    assert _result.spec.version == "2.3.0"
    assert _result.spec.repository == "https://backstage.github.io/charts"
}

test_backstage_with_host = lambda {
    _spec = bs.BackstageHelmSpec {
        name = "backstage"
        namespace = "portal"
        host = "backstage.example.com"
    }
    _result = bs.build_backstage_release(_spec)
    assert _result.spec.values["ingress.enabled"] == "true"
    assert _result.spec.values["ingress.host"] == "backstage.example.com"
    assert _result.spec.values["backstage.appConfig.app.baseUrl"] == "https://backstage.example.com"
    assert _result.spec.values["backstage.appConfig.backend.baseUrl"] == "https://backstage.example.com"
}

test_backstage_with_postgres = lambda {
    _spec = bs.BackstageHelmSpec {
        name = "backstage"
        namespace = "backstage"
        postgresHost = "backstage-db-rw.backstage.svc"
        postgresSecretName = "backstage-db-app"
    }
    _result = bs.build_backstage_release(_spec)
    assert _result.spec.values["postgresql.enabled"] == "false"
    assert _result.spec.values["backstage.appConfig.backend.database.client"] == "pg"
    assert _result.spec.values["backstage.appConfig.backend.database.connection.host"] == "backstage-db-rw.backstage.svc"
    assert _result.spec.values["backstage.appConfig.backend.database.connection.password.secret"] == "backstage-db-app"
}

test_backstage_with_resources = lambda {
    _spec = bs.BackstageHelmSpec {
        name = "backstage"
        namespace = "backstage"
        cpuRequest = "500m"
        memoryRequest = "1Gi"
        cpuLimit = "2"
        memoryLimit = "4Gi"
    }
    _result = bs.build_backstage_release(_spec)
    assert _result.spec.values["backstage.resources.requests.cpu"] == "500m"
    assert _result.spec.values["backstage.resources.requests.memory"] == "1Gi"
    assert _result.spec.values["backstage.resources.limits.cpu"] == "2"
    assert _result.spec.values["backstage.resources.limits.memory"] == "4Gi"
}

test_backstage_custom_version = lambda {
    _spec = bs.BackstageHelmSpec {
        name = "backstage"
        namespace = "backstage"
        chartVersion = "3.0.0"
        replicas = 3
    }
    _result = bs.build_backstage_release(_spec)
    assert _result.spec.version == "3.0.0"
    assert _result.spec.values["backstage.replicas"] == "3"
}
