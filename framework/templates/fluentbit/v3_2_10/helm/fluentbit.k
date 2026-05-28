"""
Fluent Bit v3.2.10 Helm chart template.

This deployment mode emits a Flux HelmRelease for the official Fluent Bit chart.
"""

import models.modules.thirdparty_helm as th
import templates.observability.v1_0_0.telemetry_config as telemetry

_DEFAULT_IMAGE_REPOSITORY = "cr.fluentbit.io/fluent/fluent-bit"
_DEFAULT_IMAGE_TAG = "3.2.10"
_DEFAULT_CHART = "fluent/fluent-bit"
_DEFAULT_CHART_VERSION = "0.48.9"
_DEFAULT_REPOSITORY = "https://fluent.github.io/helm-charts"

schema FluentBitHelmSpec:
    name: str
    namespace: str
    chartVersion?: str = _DEFAULT_CHART_VERSION
    repository?: str = _DEFAULT_REPOSITORY
    imageRepository?: str = _DEFAULT_IMAGE_REPOSITORY
    imageTag?: str = _DEFAULT_IMAGE_TAG
    kind?: str = "DaemonSet"
    pipeline?: telemetry.LogPipelineSpec = telemetry.LogPipelineSpec {input = "tail"}
    extraValues?: {str:str}

    check:
        len(name) > 0, "Fluent Bit Helm release name must not be empty"
        len(namespace) > 0, "Fluent Bit Helm namespace must not be empty"
        len(chartVersion) > 0, "Fluent Bit Helm chart version must be pinned"
        "latest" not in chartVersion, "Fluent Bit Helm chart version must not be latest"
        len(imageTag) > 0, "Fluent Bit image tag must be pinned"
        "latest" not in imageTag, "Fluent Bit image tag must not be latest"
        kind in ["DaemonSet", "Deployment"], "kind must be DaemonSet or Deployment"

build_fluentbit_helm_release = lambda spec: FluentBitHelmSpec -> any {
    _config = telemetry.build_fluentbit_classic_config(spec.pipeline)
    _values = {
        kind = spec.kind
        "image.repository" = spec.imageRepository
        "image.tag" = spec.imageTag
        "serviceMonitor.enabled" = "false"
        "config.service" = "[SERVICE]\n    Flush    1\n    Daemon    Off\n    Log_Level    info\n    HTTP_Server    On\n    HTTP_Listen    0.0.0.0\n    HTTP_Port    2020\n    Parsers_File    parsers.conf\n"
        "config.inputs" = "[INPUT]\n" + "\n".join(["    ${key}    ${value}" for key, value in telemetry.fluentbit_input_options(spec.pipeline)]) + "\n"
        "config.outputs" = "[OUTPUT]\n" + "\n".join(["    ${key}    ${value}" for key, value in telemetry.fluentbit_output_options(spec.pipeline)]) + "\n"
        "config.customParsers" = _config["parsers.conf"]
    } | (spec.extraValues or {})

    th.build_thirdparty_helm(th.ThirdPartyHelmSpec {
        name = spec.name
        namespace = spec.namespace
        chart = _DEFAULT_CHART
        version = spec.chartVersion
        repository = spec.repository
        values = _values
    })
}
