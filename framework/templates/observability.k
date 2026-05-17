"""Backward-compatible Observability template wrapper.

The implementation lives in `templates.observability.main`. Keep this root module thin so
existing imports such as `import templates.observability as observability` continue to work
without duplicating template implementation code.
"""

import templates.observability.main as observability_compat

PrometheusSpec = observability_compat.PrometheusSpec
build_prometheus = observability_compat.build_prometheus
GrafanaSpec = observability_compat.GrafanaSpec
build_grafana = observability_compat.build_grafana
ServiceMonitorSpec = observability_compat.ServiceMonitorSpec
build_service_monitor = observability_compat.build_service_monitor
