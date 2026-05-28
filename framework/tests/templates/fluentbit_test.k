import runtime
import templates.fluentbit.v3_2_10.native.fluentbit as fb_native
import templates.fluentbit.v3_2_10.helm.fluentbit as fb_helm
import templates.fluentbit.v3_2_10.operator.fluentbit as fb_operator
import templates.observability.v1_0_0.telemetry_config as telemetry

_opensearch_endpoint = telemetry.TelemetryEndpoint {
    host = "opensearch"
    port = 9200
}

_fb_pipeline = telemetry.LogPipelineSpec {
    name = "app-logs"
    input = "tail"
    output = "opensearch"
    endpoint = _opensearch_endpoint
}

test_fluentbit_native_single_instance = lambda {
    _resources = fb_native.build_fluentbit_resources(fb_native.FluentBitNativeSpec {
        name = "fluent-bit"
        namespace = "observability"
        mode = "deployment"
        replicas = 2
        pipeline = _fb_pipeline
    })
    assert len(_resources) == 4
    assert _resources[0].kind == "ConfigMap"
    assert _resources[1].kind == "Service"
    assert _resources[2].kind == "Deployment"
    assert _resources[2].spec.template.spec.containers[0].image == "cr.fluentbit.io/fluent/fluent-bit:3.2.10"
    assert _resources[3].kind == "PodDisruptionBudget"
}

test_fluentbit_native_daemonset = lambda {
    _resources = fb_native.build_fluentbit_resources(fb_native.FluentBitNativeSpec {
        name = "fluent-bit"
        namespace = "observability"
        mode = "daemonset"
        pipeline = _fb_pipeline
        mountHostLogs = True
    })
    assert len(_resources) == 3
    assert _resources[2].kind == "DaemonSet"
    assert _resources[2].spec.template.spec.volumes[1].hostPath.path == "/var/log"
}

test_fluentbit_helm_release = lambda {
    _release = fb_helm.build_fluentbit_helm_release(fb_helm.FluentBitHelmSpec {
        name = "fluent-bit"
        namespace = "observability"
        kind = "Deployment"
        pipeline = telemetry.LogPipelineSpec {output = "stdout"}
    })
    assert _release.kind == "HelmRelease"
    assert _release.spec.chart == "fluent/fluent-bit"
    assert _release.spec.version == "0.48.9"
    assert _release.spec.values["image.tag"] == "3.2.10"
    assert _release.spec.values.kind == "Deployment"
}

test_fluentbit_operator_resources = lambda {
    _resources = fb_operator.build_fluentbit_operator_resources(fb_operator.FluentBitOperatorSpec {
        name = "fluent-bit"
        namespace = "observability"
        pipeline = _fb_pipeline
    })
    assert len(_resources) == 5
    assert _resources[0].kind == "HelmRelease"
    assert _resources[1].kind == "ClusterFluentBitConfig"
    assert _resources[2].kind == "ClusterInput"
    assert _resources[3].kind == "ClusterOutput"
    assert _resources[4].kind == "FluentBit"
}

test_fluentbit_rejects_latest = lambda {
    _err = runtime.catch(lambda {
        fb_native.FluentBitNativeSpec {
            name = "bad"
            namespace = "observability"
            version = "latest"
        }
    })
    assert _err != Undefined, "expected Fluent Bit latest tag rejection"
}
