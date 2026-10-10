"""
Observability Template — Prometheus + Grafana + ServiceMonitor

Deploys monitoring infrastructure via Bitnami Helm charts (ThirdPartyHelmSpec pattern)
and generates Prometheus ServiceMonitor CRDs for automatic metrics scraping.

Charts:
- kube-prometheus (Bitnami): Prometheus + node-exporter + kube-state-metrics
- grafana (Bitnami): Dashboards + alerting UI

Usage:
    import templates.observability.v1_0_0.observability as obs

    _prometheus = obs.build_prometheus(obs.PrometheusSpec {
        name = "prometheus"
        namespace = "monitoring"
        storageSize = "50Gi"
        retentionDays = 15
    })

    _grafana_spec = obs.GrafanaSpec {
        name = "grafana"
        namespace = "monitoring"
        route = {hostnames = ["grafana.example.com"]}
    }
    _grafana = obs.build_grafana(_grafana_spec)
    _grafana_routes = obs.build_grafana_routes(_grafana_spec)   # HTTPRoute on the platform gateway

    _monitor = obs.build_service_monitor(obs.ServiceMonitorSpec {
        name = "my-app"
        namespace = "apps"
        matchLabels = {"app": "my-app"}
        port = "metrics"
    })
"""

import builders.leader as leader
import models.modules.accessory as accessory
import templates.footprints.v1_0_0.footprint as fp
import builders.route as route_builder

_GRAFANA_PORT = 3000

# --- Prometheus (kube-prometheus-stack via Bitnami) ---

_PROMETHEUS_CHART = "oci://registry-1.docker.io/bitnamicharts/kube-prometheus"
_PROMETHEUS_VERSION = "10.2.0"

schema PrometheusSpec:
    """Specification for Prometheus deployment via Bitnami kube-prometheus chart."""
    name: str
    namespace: str
    footprint?: str = "production"
    chartVersion?: str = _PROMETHEUS_VERSION
    storageSize?: str
    retentionDays?: int
    alertmanagerEnabled?: bool = False
    alertmanagerReplicas?: int = 1
    nodeExporterEnabled?: bool = True
    extraValues?: {str:str}

    check:
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"
        retentionDays >= 1 if retentionDays is not Undefined, "retentionDays must be at least 1"
        alertmanagerReplicas >= 1 if alertmanagerEnabled, "alertmanagerReplicas must be at least 1"

build_prometheus = lambda spec: PrometheusSpec -> any {
    _storage_size = spec.storageSize if spec.storageSize is not Undefined else fp.storage_size(spec.footprint, "1Gi", "2Gi", "10Gi", "50Gi")
    _retention_days = spec.retentionDays if spec.retentionDays is not Undefined else fp.retention_days(spec.footprint, 1, 3, 7, 15)
    _values: {str:str} = {
        "prometheus.persistence.enabled" = "false" if spec.footprint == "local" else "true"
        "prometheus.persistence.size" = _storage_size
        "prometheus.retention" = "${_retention_days}d"
        "nodeExporter.enabled" = "false" if spec.footprint == "local" else "true" if spec.nodeExporterEnabled else "false"
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
            values = _values | _alert_values | (spec.extraValues or {})
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
    footprint?: str = "production"
    chartVersion?: str = _GRAFANA_VERSION
    adminPasswordSecret?: str
    persistence?: bool
    storageSize?: str
    # Expose Grafana on the platform API gateway (Gateway API HTTPRoute).
    route?: route_builder.RouteSpec
    extraValues?: {str:str}

    check:
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"

build_grafana = lambda spec: GrafanaSpec -> any {
    _persistence_enabled = spec.persistence if spec.persistence is not Undefined else fp.persistence_enabled(spec.footprint, True)
    _storage_size = spec.storageSize if spec.storageSize is not Undefined else fp.storage_size(spec.footprint, "512Mi", "1Gi", "5Gi", "10Gi")
    _base_values: {str:str} = {}
    _secret_values: {str:str} = {"admin.existingSecret" = spec.adminPasswordSecret} if spec.adminPasswordSecret else {}
    _persistence_values: {str:str} = {
        "persistence.enabled" = "true"
        "persistence.size" = _storage_size
    } if _persistence_enabled else {"persistence.enabled" = "false"}
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
            values = _base_values | _secret_values | _persistence_values | (spec.extraValues or {})
        }
    }
}

build_grafana_routes = lambda spec: GrafanaSpec -> [{str:}] {
    """HTTPRoute exposing the Grafana chart Service on the platform gateway (empty without route)."""
    [route_builder.build_http_route(route_builder.HTTPRouteSpec {
        name = spec.name
        namespace = spec.namespace
        serviceName = route_builder.helm_fullname(spec.name, "grafana")
        servicePort = _GRAFANA_PORT
        route = spec.route
    })] if spec.route else []
}

schema PrometheusModule(accessory.Accessory):
    kind = "CRD"
    prometheusName: str
    footprint?: str = "production"
    chartVersion?: str = _PROMETHEUS_VERSION
    storageSize?: str
    retentionDays?: int
    alertmanagerEnabled?: bool = False
    alertmanagerReplicas?: int = 1
    nodeExporterEnabled?: bool = True
    extraValues?: {str:str}
    leaders = [leader.build_accessory_leader(prometheusName, namespace, "HelmRelease", "helm.toolkit.fluxcd.io/v2beta1")]
    manifests = [build_prometheus(PrometheusSpec {name = prometheusName, namespace = namespace, footprint = footprint, chartVersion = chartVersion, storageSize = storageSize, retentionDays = retentionDays, alertmanagerEnabled = alertmanagerEnabled, alertmanagerReplicas = alertmanagerReplicas, nodeExporterEnabled = nodeExporterEnabled, extraValues = extraValues})]

schema GrafanaModule(accessory.Accessory):
    kind = "CRD"
    grafanaName: str
    footprint?: str = "production"
    chartVersion?: str = _GRAFANA_VERSION
    adminPasswordSecret?: str
    persistence?: bool
    storageSize?: str
    route?: route_builder.RouteSpec
    extraValues?: {str:str}
    leaders = [leader.build_accessory_leader(grafanaName, namespace, "HelmRelease", "helm.toolkit.fluxcd.io/v2beta1")]
    _grafana_spec = GrafanaSpec {name = grafanaName, namespace = namespace, footprint = footprint, chartVersion = chartVersion, adminPasswordSecret = adminPasswordSecret, persistence = persistence, storageSize = storageSize, route = route, extraValues = extraValues}
    manifests = [build_grafana(_grafana_spec)] + build_grafana_routes(_grafana_spec)

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
