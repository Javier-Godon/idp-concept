"""
Observability Template — Prometheus + Grafana + ServiceMonitor

Deploys monitoring infrastructure via Bitnami Helm charts (ThirdPartyHelmSpec pattern)
and generates Prometheus ServiceMonitor CRDs for automatic metrics scraping.

Charts:
- kube-prometheus (Bitnami): Prometheus + node-exporter + kube-state-metrics
- grafana (Bitnami): Dashboards + alerting UI

Usage:
    import templates.observability as obs

    _prometheus = obs.build_prometheus(obs.PrometheusSpec {
        name = "prometheus"
        namespace = "monitoring"
        storageSize = "50Gi"
        retentionDays = 15
    })

    _grafana = obs.build_grafana(obs.GrafanaSpec {
        name = "grafana"
        namespace = "monitoring"
        ingressEnabled = True
        ingressHost = "grafana.example.com"
    })

    _monitor = obs.build_service_monitor(obs.ServiceMonitorSpec {
        name = "my-app"
        namespace = "apps"
        matchLabels = {"app": "my-app"}
        port = "metrics"
    })
"""

# --- Prometheus (kube-prometheus-stack via Bitnami) ---

_PROMETHEUS_CHART = "oci://registry-1.docker.io/bitnamicharts/kube-prometheus"
_PROMETHEUS_VERSION = "10.2.0"

schema PrometheusSpec:
    """Specification for Prometheus deployment via Bitnami kube-prometheus chart."""
    name: str
    namespace: str
    chartVersion?: str = _PROMETHEUS_VERSION
    storageSize?: str = "50Gi"
    retentionDays?: int = 15
    alertmanagerEnabled?: bool = False
    alertmanagerReplicas?: int = 1
    nodeExporterEnabled?: bool = True

    check:
        retentionDays >= 1, "retentionDays must be at least 1"
        alertmanagerReplicas >= 1 if alertmanagerEnabled, "alertmanagerReplicas must be at least 1"

build_prometheus = lambda spec: PrometheusSpec -> any {
    _values: {str:str} = {
        "prometheus.persistence.size" = spec.storageSize
        "prometheus.retention" = "${spec.retentionDays}d"
        "nodeExporter.enabled" = "true" if spec.nodeExporterEnabled else "false"
    }
    _alert_values: {str:str} = {
        "alertmanager.enabled" = "true"
        "alertmanager.replicaCount" = str(spec.alertmanagerReplicas)
    } if spec.alertmanagerEnabled else {}
    {
        apiVersion = "helm.toolkit.fluxcd.io/v2beta1"
        kind = "HelmRelease"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {
                "app.kubernetes.io/name" = spec.name
                "app.kubernetes.io/managed-by" = "idp-concept"
                "app.kubernetes.io/component" = "monitoring"
            }
        }
        spec = {
            chart = _PROMETHEUS_CHART
            version = spec.chartVersion
            createNamespace = True
            wait = True
            timeout = "15m"
            values = _values | _alert_values
        }
    }
}

# --- Grafana ---

_GRAFANA_CHART = "oci://registry-1.docker.io/bitnamicharts/grafana"
_GRAFANA_VERSION = "11.3.0"

schema GrafanaSpec:
    """Specification for Grafana deployment via Bitnami Helm chart."""
    name: str
    namespace: str
    chartVersion?: str = _GRAFANA_VERSION
    adminPasswordSecret?: str
    persistence?: bool = False
    storageSize?: str = "10Gi"
    ingressEnabled?: bool = False
    ingressHost?: str

    check:
        ingressHost if ingressEnabled, "ingressHost is required when ingressEnabled is True"

build_grafana = lambda spec: GrafanaSpec -> any {
    _base_values: {str:str} = {}
    _secret_values: {str:str} = {"admin.existingSecret" = spec.adminPasswordSecret} if spec.adminPasswordSecret else {}
    _persistence_values: {str:str} = {
        "persistence.enabled" = "true"
        "persistence.size" = spec.storageSize
    } if spec.persistence else {}
    _ingress_values: {str:str} = {
        "ingress.enabled" = "true"
        "ingress.hostname" = spec.ingressHost
    } if spec.ingressEnabled else {}
    {
        apiVersion = "helm.toolkit.fluxcd.io/v2beta1"
        kind = "HelmRelease"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {
                "app.kubernetes.io/name" = spec.name
                "app.kubernetes.io/managed-by" = "idp-concept"
                "app.kubernetes.io/component" = "monitoring"
            }
        }
        spec = {
            chart = _GRAFANA_CHART
            version = spec.chartVersion
            createNamespace = True
            wait = True
            timeout = "10m"
            values = _base_values | _secret_values | _persistence_values | _ingress_values
        }
    }
}

# --- ServiceMonitor (Prometheus Operator CRD) ---

schema ServiceMonitorSpec:
    """Specification for a Prometheus ServiceMonitor CRD."""
    name: str
    namespace: str
    matchLabels: {str:str}
    port: str
    path?: str = "/metrics"
    interval?: str = "30s"
    scrapeTimeout?: str = "10s"

    check:
        len(matchLabels) > 0, "matchLabels must not be empty"

build_service_monitor = lambda spec: ServiceMonitorSpec -> any {
    {
        apiVersion = "monitoring.coreos.com/v1"
        kind = "ServiceMonitor"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {
                "app.kubernetes.io/name" = spec.name
                "app.kubernetes.io/managed-by" = "idp-concept"
            }
        }
        spec = {
            selector = {
                matchLabels = spec.matchLabels
            }
            endpoints = [{
                port = spec.port
                path = spec.path
                interval = spec.interval
                scrapeTimeout = spec.scrapeTimeout
            }]
        }
    }
}
