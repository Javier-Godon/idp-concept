import templates.observability.v1_0_0.telemetry_config as telemetry

_test_endpoint = telemetry.TelemetryEndpoint {
    scheme = "http"
    host = "opensearch"
    port = 9200
}

_test_pipeline = telemetry.LogPipelineSpec {
    name = "app-logs"
    input = "tail"
    output = "opensearch"
    endpoint = _test_endpoint
    index = "app-logs"
}

test_endpoint_url = lambda {
    assert telemetry.endpoint_url(_test_endpoint) == "http://opensearch:9200"
}

test_fluentbit_config_for_opensearch = lambda {
    _config = telemetry.build_fluentbit_classic_config(_test_pipeline)
    assert "fluent-bit.conf" in _config
    assert "Name    tail" in _config["fluent-bit.conf"]
    assert "Name    opensearch" in _config["fluent-bit.conf"]
    assert "Host    opensearch" in _config["fluent-bit.conf"]
}

test_dataprepper_pipeline_for_stdout = lambda {
    _pipeline = telemetry.build_dataprepper_pipeline_config(telemetry.LogPipelineSpec {
        name = "logs"
        input = "http"
        inputPath = "/ingest"
        output = "stdout"
    })
    assert "logs:" in _pipeline
    assert "path: /ingest" in _pipeline
    assert "stdout" in _pipeline
}

test_otel_config_for_otlp = lambda {
    _config = telemetry.build_otel_collector_config(telemetry.LogPipelineSpec {
        input = "otlp"
        output = "stdout"
    })
    assert _config.receivers.otlp.protocols.grpc.endpoint == "0.0.0.0:4317"
    assert _config.exporters.debug.verbosity == "normal"
    assert _config.pipelines.logs.receivers == ["otlp"]
}

test_pipeline_graph_to_fluentbit = lambda {
    _pipeline = telemetry.TelemetryPipelineSpec {
        name = "app-logs"
        receivers = [telemetry.ReceiverSpec {name = "container-files", kind = "filelog", path = "/var/log/containers/*.log"}]
        transformers = [telemetry.TransformerSpec {name = "batch", kind = "batch"}]
        producers = [telemetry.ProducerSpec {name = "stdout", kind = "stdout"}]
    }
    _config = telemetry.build_fluentbit_classic_config_from_pipeline(_pipeline)
    assert "Name    tail" in _config["fluent-bit.conf"]
    assert "Path    /var/log/containers/*.log" in _config["fluent-bit.conf"]
}

test_pipeline_graph_to_otel = lambda {
    _pipeline = telemetry.TelemetryPipelineSpec {
        name = "otel-pipeline"
        receivers = [telemetry.ReceiverSpec {name = "otlp", kind = "otlp"}]
        transformers = [telemetry.TransformerSpec {name = "memory_limiter", kind = "memory_limiter"}, telemetry.TransformerSpec {name = "batch", kind = "batch"}]
        producers = [telemetry.ProducerSpec {name = "debug", kind = "debug"}]
    }
    _config = telemetry.build_otel_collector_pipeline_config(_pipeline)
    assert "otlp" in _config.receivers
    assert "memory_limiter" in _config.processors
    assert _config.pipelines.logs.processors[1] == "batch"
}
