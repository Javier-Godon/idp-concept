"""
OpenTelemetry Template Tests.

Tests the OpenTelemetry template which provides:
- OTel Operator deployment via Helm (ThirdPartyHelmSpec)
- OpenTelemetryCollector CRD generation
- Instrumentation CRD generation for auto-instrumentation
"""
import templates.opentelemetry as otel
import runtime

# === OTel Operator Helm Chart Tests ===

test_otel_operator_default = lambda {
    _result = otel.build_otel_operator(otel.OtelOperatorSpec {
        name = "opentelemetry-operator"
        namespace = "opentelemetry"
    })
    assert _result.apiVersion == "helm.toolkit.fluxcd.io/v2beta1"
    assert _result.kind == "HelmRelease"
    assert _result.metadata.name == "opentelemetry-operator"
    assert _result.metadata.namespace == "opentelemetry"
    assert _result.spec.chart == "open-telemetry/opentelemetry-operator"
    assert _result.spec.version == "0.109.0"
    assert _result.spec.values["admissionWebhooks.certManager.enabled"] == "true"
    assert _result.spec.values["admissionWebhooks.autoGenerateCert.enabled"] == "false"
    assert _result.spec.values["manager.createRbacPermissions"] == "true"
}

test_otel_operator_auto_cert = lambda {
    _result = otel.build_otel_operator(otel.OtelOperatorSpec {
        name = "otel-op"
        namespace = "otel"
        certManagerEnabled = False
        autoGenerateCert = True
    })
    assert _result.spec.values["admissionWebhooks.certManager.enabled"] == "false"
    assert _result.spec.values["admissionWebhooks.autoGenerateCert.enabled"] == "true"
}

test_otel_operator_custom_image = lambda {
    _result = otel.build_otel_operator(otel.OtelOperatorSpec {
        name = "otel-op"
        namespace = "otel"
        collectorImage = "ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s"
        chartVersion = "0.110.0"
    })
    assert _result.spec.version == "0.110.0"
    assert _result.spec.values["manager.collectorImage.repository"] == "ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s"
}

test_otel_operator_rejects_both_cert_options = lambda {
    _err = runtime.catch(lambda {
        otel.OtelOperatorSpec {
            name = "bad"
            namespace = "ns"
            certManagerEnabled = True
            autoGenerateCert = True
        }
    })
    assert _err != Undefined, "expected check block to reject both cert options enabled"
}

# === OpenTelemetryCollector CRD Tests ===

test_otel_collector_default = lambda {
    _result = otel.build_otel_collector(otel.OtelCollectorSpec {
        name = "otel-collector"
        namespace = "opentelemetry"
    })
    assert _result.apiVersion == "opentelemetry.io/v1beta1"
    assert _result.kind == "OpenTelemetryCollector"
    assert _result.metadata.name == "otel-collector"
    assert _result.metadata.namespace == "opentelemetry"
    assert _result.spec.mode == "deployment"
    assert _result.spec.replicas == 1
    assert _result.spec.config.receivers.otlp.protocols.grpc.endpoint == "0.0.0.0:4317"
    assert _result.spec.config.receivers.otlp.protocols.http.endpoint == "0.0.0.0:4318"
    assert _result.spec.config.service.pipelines.traces
    assert _result.spec.config.service.pipelines.metrics
    assert _result.spec.config.service.pipelines.logs
}

test_otel_collector_daemonset = lambda {
    _result = otel.build_otel_collector(otel.OtelCollectorSpec {
        name = "otel-ds"
        namespace = "monitoring"
        mode = "daemonset"
    })
    assert _result.spec.mode == "daemonset"
}

test_otel_collector_custom_config = lambda {
    _custom_receivers = {
        jaeger = { protocols = { grpc = {} } }
    }
    _custom_exporters = {
        otlp = { endpoint = "backend:4317" }
    }
    _custom_pipelines = {
        traces = {
            receivers = ["jaeger"]
            exporters = ["otlp"]
        }
    }
    _result = otel.build_otel_collector(otel.OtelCollectorSpec {
        name = "custom-collector"
        namespace = "tracing"
        receivers = _custom_receivers
        exporters = _custom_exporters
        pipelines = _custom_pipelines
    })
    assert _result.spec.config.receivers.jaeger.protocols.grpc == {}
    assert _result.spec.config.exporters.otlp.endpoint == "backend:4317"
    assert _result.spec.config.service.pipelines.traces.receivers == ["jaeger"]
}

test_otel_collector_target_allocator = lambda {
    _result = otel.build_otel_collector(otel.OtelCollectorSpec {
        name = "ta-collector"
        namespace = "monitoring"
        mode = "statefulset"
        replicas = 3
        targetAllocatorEnabled = True
        targetAllocatorPrometheusCR = True
    })
    assert _result.spec.mode == "statefulset"
    assert _result.spec.replicas == 3
    assert _result.spec.targetAllocator.enabled == True
    assert _result.spec.targetAllocator.prometheusCR.enabled == True
}

test_otel_collector_rejects_invalid_mode = lambda {
    _err = runtime.catch(lambda {
        otel.OtelCollectorSpec {
            name = "bad"
            namespace = "ns"
            mode = "invalid"
        }
    })
    assert _err != Undefined, "expected check block to reject invalid mode"
}

test_otel_collector_sidecar_no_replicas = lambda {
    _result = otel.build_otel_collector(otel.OtelCollectorSpec {
        name = "sidecar-collector"
        namespace = "apps"
        mode = "sidecar"
    })
    assert _result.spec.mode == "sidecar"
    assert "replicas" not in _result.spec, "sidecar mode should not have replicas"
}

# === Instrumentation CRD Tests ===

test_instrumentation_default = lambda {
    _result = otel.build_instrumentation(otel.InstrumentationSpec {
        name = "my-instrumentation"
        namespace = "apps"
    })
    assert _result.apiVersion == "opentelemetry.io/v1alpha1"
    assert _result.kind == "Instrumentation"
    assert _result.metadata.name == "my-instrumentation"
    assert _result.metadata.namespace == "apps"
    assert _result.spec.exporter.endpoint == "http://otel-collector.opentelemetry.svc:4317"
    assert _result.spec.propagators == ["tracecontext", "baggage"]
    assert _result.spec.sampler.$type == "parentbased_traceidratio"
    assert _result.spec.sampler.argument == "1.0"
}

test_instrumentation_custom_endpoint = lambda {
    _result = otel.build_instrumentation(otel.InstrumentationSpec {
        name = "custom-inst"
        namespace = "apps"
        exporterEndpoint = "http://jaeger-collector:4317"
        propagators = ["tracecontext", "baggage", "b3"]
        samplerType = "always_on"
        samplerArgument = ""
    })
    assert _result.spec.exporter.endpoint == "http://jaeger-collector:4317"
    assert len(_result.spec.propagators) == 3
    assert _result.spec.sampler.$type == "always_on"
}

test_instrumentation_custom_images = lambda {
    _result = otel.build_instrumentation(otel.InstrumentationSpec {
        name = "custom-images"
        namespace = "apps"
        javaImage = "custom/java-agent:1.0"
        pythonImage = "custom/python-agent:1.0"
        nodejsImage = "custom/nodejs-agent:1.0"
    })
    assert _result.spec.java.image == "custom/java-agent:1.0"
    assert _result.spec.python.image == "custom/python-agent:1.0"
    assert _result.spec.nodejs.image == "custom/nodejs-agent:1.0"
}
