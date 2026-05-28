"""
Acceptance fixture: observability HelmRelease + ServiceMonitor resources through the IDP render path.
"""
import ._helpers as h
import templates.observability.v1_0_0.observability as obs
_namespace = "idp-acceptance-observability"
_resources = [
    obs.build_prometheus(obs.PrometheusSpec {
        name = "acceptance-prometheus"
        namespace = _namespace
        chartVersion = "10.2.0"
        storageSize = "1Gi"
        retentionDays = 1
        nodeExporterEnabled = False
    })
    obs.build_grafana(obs.GrafanaSpec {
        name = "acceptance-grafana"
        namespace = _namespace
        chartVersion = "11.3.0"
        persistence = False
    })
    obs.build_service_monitor(obs.ServiceMonitorSpec {
        name = "acceptance-service-monitor"
        namespace = _namespace
        matchLabels = {app = "acceptance-webapp"}
        port = "http"
    })
]
_module = h.wrap_accessory("acceptance-observability", _namespace, "monitoring.coreos.com/v1", "ServiceMonitor", _resources, "1.0.0")
h.render_accessory(_namespace, _module)
