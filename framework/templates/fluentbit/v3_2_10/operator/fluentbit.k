"""
Fluent Bit v3.2.10 Fluent Operator templates.

This deployment mode emits:
- a Flux HelmRelease for fluent-operator
- Fluent Operator CRs describing one Fluent Bit collector and cluster config
"""

import builders.leader as leader
import models.modules.accessory as accessory
import models.modules.thirdparty_helm as th
import templates.observability.v1_0_0.telemetry_config as telemetry
import templates.footprints.v1_0_0.footprint as fp

_API_VERSION = "fluentbit.fluent.io/v1alpha2"
_DEFAULT_IMAGE = "cr.fluentbit.io/fluent/fluent-bit"
_DEFAULT_VERSION = "3.2.10"
_DEFAULT_OPERATOR_CHART = "fluent/fluent-operator"
_DEFAULT_OPERATOR_CHART_VERSION = "3.1.0"
_DEFAULT_REPOSITORY = "https://fluent.github.io/helm-charts"

schema FluentBitOperatorSpec:
    name: str
    namespace: str
    operatorReleaseName?: str = "fluent-operator"
    operatorChartVersion?: str = _DEFAULT_OPERATOR_CHART_VERSION
    repository?: str = _DEFAULT_REPOSITORY
    image?: str = _DEFAULT_IMAGE
    version?: str = _DEFAULT_VERSION
    footprint?: str = "development"
    pipeline?: telemetry.LogPipelineSpec = telemetry.LogPipelineSpec {input = "tail"}
    pipelineSpec?: telemetry.TelemetryPipelineSpec
    fluentBitConfigName?: str = "fluent-bit-config"
    extraOperatorValues?: {str:str}

    check:
        len(name) > 0, "Fluent Bit CR name must not be empty"
        len(namespace) > 0, "Fluent Bit namespace must not be empty"
        len(operatorChartVersion) > 0, "Fluent Operator chart version must be pinned"
        "latest" not in operatorChartVersion, "Fluent Operator chart version must not be latest"
        len(version) > 0, "Fluent Bit image version must be pinned"
        "latest" not in version, "Fluent Bit image version must not be latest"
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"

build_fluent_operator_release = lambda spec: FluentBitOperatorSpec -> any {
    th.build_thirdparty_helm(th.ThirdPartyHelmSpec {
        name = spec.operatorReleaseName
        namespace = spec.namespace
        chart = _DEFAULT_OPERATOR_CHART
        version = spec.operatorChartVersion
        repository = spec.repository
        values = {
            "containerRuntime" = "containerd"
        } | (spec.extraOperatorValues or {})
    })
}

build_fluentbit_cr = lambda spec: FluentBitOperatorSpec -> any {
    {
        apiVersion = _API_VERSION
        kind = "FluentBit"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {"app.kubernetes.io/name" = spec.name, "app.kubernetes.io/component" = "fluent-bit", "app.kubernetes.io/managed-by" = "idp-concept"}
        }
        spec = {
            image = "${spec.image}:${spec.version}"
            fluentBitConfigName = spec.fluentBitConfigName
            replicas = fp.replicas(spec.footprint, 1, 1, 2, 3)
            positionDB = {hostPath = {path = "/var/lib/fluent-bit/"}}
            resources = {
                requests = {cpu = "100m", memory = "128Mi"}
                limits = {cpu = "500m", memory = "512Mi"}
            }
        }
    }
}

build_cluster_fluentbit_config = lambda spec: FluentBitOperatorSpec -> any {
    _log_pipeline = telemetry.to_log_pipeline(spec.pipelineSpec) if spec.pipelineSpec is not Undefined else spec.pipeline
    {
        apiVersion = _API_VERSION
        kind = "ClusterFluentBitConfig"
        metadata = {
            name = spec.fluentBitConfigName
            labels = {"app.kubernetes.io/name" = spec.fluentBitConfigName, "app.kubernetes.io/managed-by" = "idp-concept"}
        }
        spec = {
            service = {
                parsersFile = "parsers.conf"
                httpServer = True
                httpListen = "0.0.0.0"
                httpPort = 2020
            }
            inputSelector = {matchLabels = {"idp-concept/pipeline" = _log_pipeline.name}}
            outputSelector = {matchLabels = {"idp-concept/pipeline" = _log_pipeline.name}}
        }
    }
}

build_cluster_input = lambda spec: FluentBitOperatorSpec -> any {
    _log_pipeline = telemetry.to_log_pipeline(spec.pipelineSpec) if spec.pipelineSpec is not Undefined else spec.pipeline
    {
        apiVersion = _API_VERSION
        kind = "ClusterInput"
        metadata = {
            name = "${spec.name}-${_log_pipeline.input}-input"
            labels = {"idp-concept/pipeline" = _log_pipeline.name}
        }
        spec = telemetry.fluentbit_input_options(_log_pipeline)
    }
}

build_cluster_output = lambda spec: FluentBitOperatorSpec -> any {
    _log_pipeline = telemetry.to_log_pipeline(spec.pipelineSpec) if spec.pipelineSpec is not Undefined else spec.pipeline
    {
        apiVersion = _API_VERSION
        kind = "ClusterOutput"
        metadata = {
            name = "${spec.name}-${_log_pipeline.output}-output"
            labels = {"idp-concept/pipeline" = _log_pipeline.name}
        }
        spec = telemetry.fluentbit_output_options(_log_pipeline)
    }
}

build_fluentbit_operator_resources = lambda spec: FluentBitOperatorSpec -> [any] {
    [
        build_fluent_operator_release(spec)
        build_cluster_fluentbit_config(spec)
        build_cluster_input(spec)
        build_cluster_output(spec)
        build_fluentbit_cr(spec)
    ]
}

schema FluentBitOperatorModule(accessory.Accessory):
    kind = "CRD"

    operatorReleaseName?: str = "fluent-operator"
    operatorChartVersion?: str = _DEFAULT_OPERATOR_CHART_VERSION
    footprint?: str = "development"
    pipeline?: telemetry.LogPipelineSpec = telemetry.LogPipelineSpec {input = "tail"}
    pipelineSpec?: telemetry.TelemetryPipelineSpec
    fluentBitConfigName?: str = "fluent-bit-config"
    extraOperatorValues?: {str:str}

    leaders = [leader.build_accessory_leader(name, namespace, "FluentBit", _API_VERSION)]

    manifests = build_fluentbit_operator_resources(FluentBitOperatorSpec {
        name = name
        namespace = namespace
        image = asset.image if asset.image != Undefined else _DEFAULT_IMAGE
        version = asset.version
        footprint = footprint
        operatorReleaseName = operatorReleaseName
        operatorChartVersion = operatorChartVersion
        pipeline = pipeline
        pipelineSpec = pipelineSpec
        fluentBitConfigName = fluentBitConfigName
        extraOperatorValues = extraOperatorValues
    })
