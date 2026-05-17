"""
OpenTelemetry Operator Template — OpenTelemetry Collector + Instrumentation CRDs.

Deploys the OpenTelemetry Operator via Helm chart (ThirdPartyHelmSpec pattern)
and generates OpenTelemetryCollector and Instrumentation CRDs for automatic
telemetry collection and auto-instrumentation of workloads.

Operator: open-telemetry/opentelemetry-operator (Apache-2.0, CNCF)
Helm chart: open-telemetry/opentelemetry-operator (0.109.0)
CRDs: OpenTelemetryCollector (opentelemetry.io/v1beta1), Instrumentation (opentelemetry.io/v1alpha1)

Usage:
    import templates.opentelemetry as otel

    # Deploy the operator via Helm
    _operator = otel.build_otel_operator(otel.OtelOperatorSpec {
        name = "opentelemetry-operator"
        namespace = "opentelemetry"
    })

    # Deploy a collector instance
    _collector = otel.build_otel_collector(otel.OtelCollectorSpec {
        name = "otel-collector"
        namespace = "opentelemetry"
        mode = "deployment"
        exporters = { debug = {} }
    })

    # Deploy auto-instrumentation
    _instrumentation = otel.build_instrumentation(otel.InstrumentationSpec {
        name = "my-instrumentation"
        namespace = "apps"
        exporterEndpoint = "http://otel-collector.opentelemetry.svc:4317"
    })
"""
import models.modules.thirdparty_helm as th

# --- OpenTelemetry Operator Helm Chart ---

_OTEL_OPERATOR_CHART = "open-telemetry/opentelemetry-operator"
_OTEL_OPERATOR_CHART_VERSION = "0.109.0"

schema OtelOperatorSpec:
    """Specification for deploying the OpenTelemetry Operator via Helm chart."""
    name: str
    namespace: str
    chartVersion?: str = _OTEL_OPERATOR_CHART_VERSION
    certManagerEnabled?: bool = True
    autoGenerateCert?: bool = False
    createRbacPermissions?: bool = True
    collectorImage?: str
    extraValues?: {str:str}

    check:
        len(name) > 0, "OTel Operator release name must not be empty"
        len(namespace) > 0, "OTel Operator namespace must not be empty"
        not (certManagerEnabled and autoGenerateCert), "cannot enable both certManager and autoGenerateCert"

build_otel_operator = lambda spec: OtelOperatorSpec -> any {
    _cert_values: {str:str} = {
        "admissionWebhooks.certManager.enabled" = "true" if spec.certManagerEnabled else "false"
        "admissionWebhooks.autoGenerateCert.enabled" = "true" if spec.autoGenerateCert else "false"
    }
    _rbac_values: {str:str} = {
        "manager.createRbacPermissions" = "true" if spec.createRbacPermissions else "false"
    }
    _image_values: {str:str} = {
        if spec.collectorImage:
            "manager.collectorImage.repository" = spec.collectorImage
    }

    _all_values: {str:str} = _cert_values | _rbac_values | _image_values | (spec.extraValues or {})

    _helm_spec = th.ThirdPartyHelmSpec {
        name = spec.name
        namespace = spec.namespace
        chart = _OTEL_OPERATOR_CHART
        version = spec.chartVersion
        values = _all_values
    }

    th.build_thirdparty_helm(_helm_spec)
}

# --- OpenTelemetryCollector CRD (opentelemetry.io/v1beta1) ---

schema OtelCollectorSpec:
    """Specification for an OpenTelemetryCollector CR instance."""
    name: str
    namespace: str
    mode?: str = "deployment"
    replicas?: int = 1
    image?: str
    receivers?: {str:any}
    processors?: {str:any}
    exporters?: {str:any}
    pipelines?: {str:any}
    targetAllocatorEnabled?: bool = False
    targetAllocatorPrometheusCR?: bool = False
    resources?: {str:any}

    check:
        mode in ["deployment", "daemonset", "statefulset", "sidecar"], "mode must be deployment, daemonset, statefulset, or sidecar"
        replicas >= 1 if replicas is not Undefined, "replicas must be at least 1"

build_otel_collector = lambda spec: OtelCollectorSpec -> any {
    _default_receivers = {
        otlp = {
            protocols = {
                grpc = { endpoint = "0.0.0.0:4317" }
                http = { endpoint = "0.0.0.0:4318" }
            }
        }
    }
    _default_processors = {
        memory_limiter = {
            check_interval = "1s"
            limit_percentage = 75
            spike_limit_percentage = 15
        }
        batch = {}
    }
    _default_exporters = { debug = {} }

    _receivers = spec.receivers or _default_receivers
    _processors = spec.processors or _default_processors
    _exporters = spec.exporters or _default_exporters

    _default_pipelines = {
        traces = {
            receivers = [r for r in _receivers]
            processors = [p for p in _processors]
            exporters = [e for e in _exporters]
        }
        metrics = {
            receivers = [r for r in _receivers]
            processors = [p for p in _processors]
            exporters = [e for e in _exporters]
        }
        logs = {
            receivers = [r for r in _receivers]
            processors = [p for p in _processors]
            exporters = [e for e in _exporters]
        }
    }

    _pipelines = spec.pipelines or _default_pipelines

    _base = {
        apiVersion = "opentelemetry.io/v1beta1"
        kind = "OpenTelemetryCollector"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {
                "app.kubernetes.io/name" = spec.name
                "app.kubernetes.io/managed-by" = "idp-concept"
                "app.kubernetes.io/component" = "observability"
            }
        }
        spec = {
            mode = spec.mode
            if spec.mode != "sidecar":
                replicas = spec.replicas
            if spec.image:
                image = spec.image
            if spec.targetAllocatorEnabled:
                targetAllocator = {
                    enabled = True
                    if spec.targetAllocatorPrometheusCR:
                        prometheusCR = {
                            enabled = True
                            serviceMonitorSelector = {}
                            podMonitorSelector = {}
                        }
                }
            if spec.resources:
                resources = spec.resources
            config = {
                receivers = _receivers
                processors = _processors
                exporters = _exporters
                service = {
                    pipelines = _pipelines
                }
            }
        }
    }

    _base
}

# --- Instrumentation CRD (opentelemetry.io/v1alpha1) ---

schema InstrumentationSpec:
    """Specification for an OpenTelemetry Instrumentation CR for auto-instrumentation."""
    name: str
    namespace: str
    exporterEndpoint?: str = "http://otel-collector.opentelemetry.svc:4317"
    propagators?: [str] = ["tracecontext", "baggage"]
    samplerType?: str = "parentbased_traceidratio"
    samplerArgument?: str = "1.0"
    javaImage?: str
    nodejsImage?: str
    pythonImage?: str
    dotnetImage?: str
    goImage?: str

    check:
        len(name) > 0, "Instrumentation name must not be empty"
        len(namespace) > 0, "Instrumentation namespace must not be empty"

build_instrumentation = lambda spec: InstrumentationSpec -> any {
    {
        apiVersion = "opentelemetry.io/v1alpha1"
        kind = "Instrumentation"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {
                "app.kubernetes.io/name" = spec.name
                "app.kubernetes.io/managed-by" = "idp-concept"
                "app.kubernetes.io/component" = "observability"
            }
        }
        spec = {
            exporter = {
                endpoint = spec.exporterEndpoint
            }
            propagators = spec.propagators
            sampler = {
                $type = spec.samplerType
                argument = spec.samplerArgument
            }
            if spec.javaImage:
                java = { image = spec.javaImage }
            if spec.nodejsImage:
                nodejs = { image = spec.nodejsImage }
            if spec.pythonImage:
                python = { image = spec.pythonImage }
            if spec.dotnetImage:
                dotnet = { image = spec.dotnetImage }
            if spec.goImage:
                go = { image = spec.goImage }
        }
    }
}
