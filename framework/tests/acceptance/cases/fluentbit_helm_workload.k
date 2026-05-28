"""
Acceptance fixture: Fluent Bit HelmRelease through the IDP render path.
"""
import ._helpers as h
import templates.fluentbit.v3_2_10.helm.fluentbit as fb
import templates.observability.v1_0_0.telemetry_config as telemetry

_namespace = "idp-acceptance-fluentbit-helm"
_resources = [fb.build_fluentbit_helm_release(fb.FluentBitHelmSpec {
    name = "acceptance-fluentbit"
    namespace = _namespace
    chartVersion = "0.48.9"
    kind = "Deployment"
    pipeline = telemetry.LogPipelineSpec {output = "stdout"}
})]
_module = h.wrap_accessory("acceptance-fluentbit-helm", _namespace, "helm.toolkit.fluxcd.io/v2beta1", "HelmRelease", _resources, "0.48.9")
h.render_accessory(_namespace, _module)
