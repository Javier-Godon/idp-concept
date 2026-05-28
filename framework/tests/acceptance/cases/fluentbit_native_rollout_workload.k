"""
Runtime rollout fixture: Fluent Bit native single-instance Deployment.

Uses the real Fluent Bit image and a dummy input/stdout output so it can become
Ready in kind without an external log backend.
"""
import ._helpers as h
import templates.fluentbit.v3_2_10.native.fluentbit as fb
import templates.observability.v1_0_0.telemetry_config as telemetry

_namespace = "idp-acceptance-fluentbit-native-rollout"
_module = fb.FluentBitSingleInstanceModule {
    name = "acceptance-fluentbit"
    namespace = _namespace
    configurations = {}
    asset = {image = "cr.fluentbit.io/fluent/fluent-bit", version = "3.2.10"}
    replicas = 1
    pipeline = telemetry.LogPipelineSpec {
        name = "dummy-logs"
        input = "dummy"
        output = "stdout"
    }
    dependsOn = [h.build_namespace(_namespace)]
}.instance

h.render_component(_namespace, _module)
