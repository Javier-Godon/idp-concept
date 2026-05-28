"""
Acceptance fixture: OpenTelemetry operator HelmRelease and CRs through the IDP render path.
"""
import ._helpers as h
import templates.opentelemetry.v1_0_0.opentelemetry as otel
_namespace = "idp-acceptance-opentelemetry"
_resources = [
    otel.build_otel_operator(otel.OtelOperatorSpec {
        name = "acceptance-otel-operator"
        namespace = _namespace
        chartVersion = "0.109.0"
        certManagerEnabled = False
        autoGenerateCert = True
    })
    otel.build_otel_collector(otel.OtelCollectorSpec {
        name = "acceptance-otel-collector"
        namespace = _namespace
        mode = "deployment"
        replicas = 1
    })
    otel.build_instrumentation(otel.InstrumentationSpec {
        name = "acceptance-instrumentation"
        namespace = _namespace
        exporterEndpoint = "http://acceptance-otel-collector:4317"
    })
]
_module = h.wrap_accessory("acceptance-opentelemetry", _namespace, "opentelemetry.io/v1beta1", "OpenTelemetryCollector", _resources, "0.109.0")
h.render_accessory(_namespace, _module)
