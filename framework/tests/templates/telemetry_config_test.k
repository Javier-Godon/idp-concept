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
    assert _config.exporters.debug == {}
    assert _config.pipelines.logs.receivers == ["otlp"]
}
