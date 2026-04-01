import templates.observability as obs

# --- Prometheus Tests ---

test_prometheus_default = lambda {
    _spec = obs.PrometheusSpec {
        name = "prometheus"
        namespace = "monitoring"
    }
    _result = obs.build_prometheus(_spec)
    assert _result.metadata.name == "prometheus"
    assert _result.metadata.namespace == "monitoring"
    assert _result.spec.chart == "oci://registry-1.docker.io/bitnamicharts/kube-prometheus"
    assert _result.spec.version == "10.2.0"
    assert _result.spec.createNamespace == True
}

test_prometheus_custom_version = lambda {
    _spec = obs.PrometheusSpec {
        name = "prom"
        namespace = "obs"
        chartVersion = "11.0.0"
        storageSize = "100Gi"
        retentionDays = 30
    }
    _result = obs.build_prometheus(_spec)
    assert _result.spec.version == "11.0.0"
    assert _result.spec.values["prometheus.persistence.size"] == "100Gi"
    assert _result.spec.values["prometheus.retention"] == "30d"
}

test_prometheus_alertmanager = lambda {
    _spec = obs.PrometheusSpec {
        name = "prometheus"
        namespace = "monitoring"
        alertmanagerEnabled = True
        alertmanagerReplicas = 3
    }
    _result = obs.build_prometheus(_spec)
    assert _result.spec.values["alertmanager.enabled"] == "true"
    assert _result.spec.values["alertmanager.replicaCount"] == "3"
}

# --- Grafana Tests ---

test_grafana_default = lambda {
    _spec = obs.GrafanaSpec {
        name = "grafana"
        namespace = "monitoring"
    }
    _result = obs.build_grafana(_spec)
    assert _result.metadata.name == "grafana"
    assert _result.metadata.namespace == "monitoring"
    assert _result.spec.chart == "oci://registry-1.docker.io/bitnamicharts/grafana"
    assert _result.spec.version == "11.3.0"
}

test_grafana_custom = lambda {
    _spec = obs.GrafanaSpec {
        name = "grafana"
        namespace = "monitoring"
        adminPasswordSecret = "grafana-admin"
        persistence = True
        storageSize = "20Gi"
    }
    _result = obs.build_grafana(_spec)
    assert _result.spec.values["admin.existingSecret"] == "grafana-admin"
    assert _result.spec.values["persistence.enabled"] == "true"
    assert _result.spec.values["persistence.size"] == "20Gi"
}

test_grafana_ingress = lambda {
    _spec = obs.GrafanaSpec {
        name = "grafana"
        namespace = "monitoring"
        ingressEnabled = True
        ingressHost = "grafana.example.com"
    }
    _result = obs.build_grafana(_spec)
    assert _result.spec.values["ingress.enabled"] == "true"
    assert _result.spec.values["ingress.hostname"] == "grafana.example.com"
}

# --- ServiceMonitor Tests ---

test_service_monitor = lambda {
    _spec = obs.ServiceMonitorSpec {
        name = "my-app-monitor"
        namespace = "apps"
        matchLabels = {"app": "my-app"}
        port = "metrics"
        path = "/metrics"
    }
    _result = obs.build_service_monitor(_spec)
    assert _result.kind == "ServiceMonitor"
    assert _result.apiVersion == "monitoring.coreos.com/v1"
    assert _result.metadata.name == "my-app-monitor"
    assert _result.spec.selector.matchLabels.app == "my-app"
    assert _result.spec.endpoints[0].port == "metrics"
    assert _result.spec.endpoints[0].path == "/metrics"
}

test_service_monitor_interval = lambda {
    _spec = obs.ServiceMonitorSpec {
        name = "db-monitor"
        namespace = "data"
        matchLabels = {"app": "postgres"}
        port = "metrics"
        interval = "60s"
        scrapeTimeout = "30s"
    }
    _result = obs.build_service_monitor(_spec)
    assert _result.spec.endpoints[0].interval == "60s"
    assert _result.spec.endpoints[0].scrapeTimeout == "30s"
}
