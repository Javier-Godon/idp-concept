"""
Acceptance fixture: Fluent Bit via Fluent Operator through the IDP render path.
"""
import ._helpers as h
import templates.fluentbit.v3_2_10.operator.fluentbit as fb
import templates.observability.v1_0_0.telemetry_config as telemetry

_namespace = "idp-acceptance-fluentbit-operator"
_resources = fb.build_fluentbit_operator_resources(fb.FluentBitOperatorSpec {
    name = "acceptance-fluentbit"
    namespace = _namespace
    pipeline = telemetry.LogPipelineSpec {
        name = "cluster-logs"
        input = "tail"
        output = "stdout"
    }
})
_module = h.wrap_accessory("acceptance-fluentbit-operator", _namespace, "fluentbit.fluent.io/v1alpha2", "FluentBit", _resources, "3.2.10")
h.render_accessory(_namespace, _module)
