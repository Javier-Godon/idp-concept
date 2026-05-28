"""
Shared observability configuration helpers.

These schemas let templates such as Fluent Bit, Data Prepper, and the
OpenTelemetry Collector share one small pipeline description and render it to
the configuration shape each tool expects.
"""

schema TelemetryEndpoint:
    name?: str = "default"
    scheme?: str = "http"
    host: str
    port: int
    path?: str = ""
    tls?: bool = False
    headers?: {str:str}

    check:
        len(host) > 0, "endpoint host must not be empty"
        1 <= port <= 65535, "endpoint port must be between 1 and 65535"
        scheme in ["http", "https", "grpc", "tcp"], "endpoint scheme must be http, https, grpc, or tcp"

schema LogPipelineSpec:
    name?: str = "logs"
    input?: str = "dummy"
    inputPath?: str = "/var/log/containers/*.log"
    parser?: str = "docker"
    output?: str = "stdout"
    endpoint?: TelemetryEndpoint
    index?: str = "logs-%Y.%m.%d"
    extraInput?: {str:str}
    extraOutput?: {str:str}
    processors?: [str] = ["batch"]

    check:
        len(name) > 0, "pipeline name must not be empty"
        input in ["dummy", "tail", "http", "forward", "otlp"], "input must be dummy, tail, http, forward, or otlp"
        output in ["stdout", "opensearch", "http", "otlp"], "output must be stdout, opensearch, http, or otlp"
        endpoint is not Undefined if output in ["opensearch", "http", "otlp"], "endpoint is required for remote outputs"

schema ReceiverSpec:
    name: str
    kind: str
    path?: str
    port?: int
    protocol?: str = "http"
    options?: {str:str}

    check:
        len(name) > 0, "receiver name must not be empty"
        kind in ["dummy", "tail", "filelog", "http", "forward", "otlp"], "receiver kind must be dummy, tail, filelog, http, forward, or otlp"
        1 <= port <= 65535 if port is not Undefined, "receiver port must be between 1 and 65535"

schema TransformerSpec:
    name: str
    kind: str
    options?: {str:any}

    check:
        len(name) > 0, "transformer name must not be empty"
        kind in ["batch", "memory_limiter", "attributes", "resource", "filter", "transform", "parse_json"], "unsupported transformer kind"

schema ProducerSpec:
    name: str
    kind: str
    endpoint?: TelemetryEndpoint
    index?: str = "logs-%Y.%m.%d"
    options?: {str:str}

    check:
        len(name) > 0, "producer name must not be empty"
        kind in ["stdout", "debug", "opensearch", "http", "otlp"], "producer kind must be stdout, debug, opensearch, http, or otlp"
        endpoint is not Undefined if kind in ["opensearch", "http", "otlp"], "producer endpoint is required for remote producers"

schema TelemetryPipelineSpec:
    name?: str = "logs"
    signal?: str = "logs"
    receivers?: [ReceiverSpec] = [ReceiverSpec {name = "dummy", kind = "dummy"}]
    transformers?: [TransformerSpec] = [TransformerSpec {name = "batch", kind = "batch"}]
    producers?: [ProducerSpec] = [ProducerSpec {name = "stdout", kind = "stdout"}]

    check:
        len(name) > 0, "pipeline name must not be empty"
        signal in ["logs", "metrics", "traces"], "pipeline signal must be logs, metrics, or traces"
        len(receivers) > 0, "pipeline requires at least one receiver"
        len(producers) > 0, "pipeline requires at least one producer"

endpoint_hostport = lambda endpoint: TelemetryEndpoint -> str {
    "${endpoint.host}:${endpoint.port}"
}

endpoint_url = lambda endpoint: TelemetryEndpoint -> str {
    _scheme = "https" if endpoint.tls and endpoint.scheme == "http" else endpoint.scheme
    _path = endpoint.path if endpoint.path else ""
    "${_scheme}://${endpoint.host}:${endpoint.port}${_path}" if _scheme in ["http", "https"] else "${endpoint.host}:${endpoint.port}"
}

_receiver_to_log_input = lambda receiver: ReceiverSpec -> str {
    "tail" if receiver.kind == "filelog" else receiver.kind
}

_producer_to_log_output = lambda producer: ProducerSpec -> str {
    "stdout" if producer.kind == "debug" else producer.kind
}

to_log_pipeline = lambda spec: TelemetryPipelineSpec -> LogPipelineSpec {
    _receiver = spec.receivers[0]
    _producer = spec.producers[0]
    LogPipelineSpec {
        name = spec.name
        input = _receiver_to_log_input(_receiver)
        inputPath = _receiver.path if _receiver.path else "/var/log/containers/*.log"
        output = _producer_to_log_output(_producer)
        endpoint = _producer.endpoint
        index = _producer.index
        extraInput = _receiver.options
        extraOutput = _producer.options
        processors = [t.name for t in spec.transformers]
    }
}

_classic_section = lambda section: str, options: {str:str} -> str {
    "[${section}]\n" + "\n".join(["    ${key}    ${value}" for key, value in options]) + "\n"
}

fluentbit_input_options = lambda spec: LogPipelineSpec -> {str:str} {
    _base: {str:str} = {
        if spec.input == "dummy":
            Name = "dummy"
            Tag = spec.name
        if spec.input == "tail":
            Name = "tail"
            Path = spec.inputPath
            Parser = spec.parser
            Tag = spec.name
            Mem_Buf_Limit = "10MB"
            Skip_Long_Lines = "On"
        if spec.input == "http":
            Name = "http"
            Listen = "0.0.0.0"
            Port = "9880"
            Tag = spec.name
        if spec.input == "forward":
            Name = "forward"
            Listen = "0.0.0.0"
            Port = "24224"
            Tag = spec.name
        if spec.input == "otlp":
            Name = "opentelemetry"
            Listen = "0.0.0.0"
            Port = "4318"
            Tag = spec.name
    }
    _base | (spec.extraInput or {})
}

fluentbit_output_options = lambda spec: LogPipelineSpec -> {str:str} {
    _base: {str:str} = {
        Match = "*"
        if spec.output == "stdout":
            Name = "stdout"
        if spec.output == "opensearch":
            Name = "opensearch"
            Host = spec.endpoint.host
            Port = str(spec.endpoint.port)
            Index = spec.index
            Suppress_Type_Name = "On"
            tls = "On" if spec.endpoint.tls else "Off"
        if spec.output == "http":
            Name = "http"
            Host = spec.endpoint.host
            Port = str(spec.endpoint.port)
            URI = spec.endpoint.path if spec.endpoint.path else "/"
            Format = "json_lines"
            tls = "On" if spec.endpoint.tls else "Off"
        if spec.output == "otlp":
            Name = "opentelemetry"
            Host = spec.endpoint.host
            Port = str(spec.endpoint.port)
            tls = "On" if spec.endpoint.tls else "Off"
    }
    _base | (spec.extraOutput or {})
}

build_fluentbit_classic_config = lambda spec: LogPipelineSpec -> {str:str} {
    _service = _classic_section("SERVICE", {
        Flush = "1"
        Daemon = "Off"
        Log_Level = "info"
        HTTP_Server = "On"
        HTTP_Listen = "0.0.0.0"
        HTTP_Port = "2020"
        Parsers_File = "parsers.conf"
    })
    _input = _classic_section("INPUT", fluentbit_input_options(spec))
    _output = _classic_section("OUTPUT", fluentbit_output_options(spec))
    {
        "fluent-bit.conf" = _service + "\n" + _input + "\n" + _output
        "parsers.conf" = "[PARSER]\n    Name    docker\n    Format    json\n    Time_Key    time\n    Time_Format    %Y-%m-%dT%H:%M:%S.%L\n    Time_Keep    On\n"
    }
}

build_fluentbit_classic_config_from_pipeline = lambda spec: TelemetryPipelineSpec -> {str:str} {
    build_fluentbit_classic_config(to_log_pipeline(spec))
}

_dataprepper_source = lambda spec: LogPipelineSpec -> str {
    _path = spec.inputPath if spec.input == "http" and spec.inputPath else "/log/ingest"
    "    http:\n      path: ${_path}\n"
}

_dataprepper_sink = lambda spec: LogPipelineSpec -> str {
    "    - stdout:\n" if spec.output == "stdout" else "    - opensearch:\n        hosts: [\"${endpoint_url(spec.endpoint)}\"]\n        index: ${spec.index}\n" if spec.output == "opensearch" else "    - http:\n        url: \"${endpoint_url(spec.endpoint)}\"\n" if spec.output == "http" else "    - otel_logs_source:\n        endpoint: \"${endpoint_url(spec.endpoint)}\"\n"
}

build_dataprepper_pipeline_config = lambda spec: LogPipelineSpec -> str {
    "${spec.name}:\n  source:\n${_dataprepper_source(spec)}  sink:\n${_dataprepper_sink(spec)}"
}

build_dataprepper_pipeline_config_from_pipeline = lambda spec: TelemetryPipelineSpec -> str {
    build_dataprepper_pipeline_config(to_log_pipeline(spec))
}

_otel_receiver_config = lambda receiver: ReceiverSpec -> any {
    {
        if receiver.kind == "otlp":
            protocols = {grpc = {endpoint = "0.0.0.0:${receiver.port or 4317}"}, http = {endpoint = "0.0.0.0:4318"}}
        if receiver.kind in ["tail", "filelog"]:
            include = [receiver.path or "/var/log/containers/*.log"]
            start_at = "end"
        if receiver.kind == "http":
            endpoint = "0.0.0.0:${receiver.port or 9880}"
        if receiver.kind == "forward":
            endpoint = "0.0.0.0:${receiver.port or 24224}"
        if receiver.kind == "dummy":
            interval = "1s"
    } | (receiver.options or {})
}

_otel_processor_config = lambda transformer: TransformerSpec -> any {
    {
        if transformer.kind == "memory_limiter":
            check_interval = "1s"
            limit_percentage = 75
            spike_limit_percentage = 15
        if transformer.kind == "parse_json":
            operators = [{type = "json_parser"}]
    } | (transformer.options or {})
}

_otel_exporter_config = lambda producer: ProducerSpec -> any {
    {
        if producer.kind in ["stdout", "debug"]:
            verbosity = "normal"
        if producer.kind == "opensearch":
            http = {endpoint = endpoint_url(producer.endpoint)}
        if producer.kind == "http":
            endpoint = endpoint_url(producer.endpoint)
        if producer.kind == "otlp":
            endpoint = endpoint_hostport(producer.endpoint)
            tls = {insecure = not producer.endpoint.tls}
    } | (producer.options or {})
}

_otel_receiver_name = lambda receiver: ReceiverSpec -> str {
    "filelog" if receiver.kind in ["tail", "filelog"] else "debug" if receiver.kind == "dummy" else receiver.name
}

_otel_exporter_name = lambda producer: ProducerSpec -> str {
    "debug" if producer.kind in ["stdout", "debug"] else producer.name
}

build_otel_collector_pipeline_config = lambda spec: TelemetryPipelineSpec -> any {
    {
        receivers = {_otel_receiver_name(r): _otel_receiver_config(r) for r in spec.receivers}
        processors = {t.name: _otel_processor_config(t) for t in spec.transformers}
        exporters = {_otel_exporter_name(p): _otel_exporter_config(p) for p in spec.producers}
        pipelines = {
            "${spec.signal}" = {
                receivers = [_otel_receiver_name(r) for r in spec.receivers]
                processors = [t.name for t in spec.transformers]
                exporters = [_otel_exporter_name(p) for p in spec.producers]
            }
        }
    }
}

pipeline_from_log_pipeline = lambda spec: LogPipelineSpec -> TelemetryPipelineSpec {
    TelemetryPipelineSpec {
        name = spec.name
        signal = "logs"
        receivers = [ReceiverSpec {name = spec.input, kind = "filelog" if spec.input == "tail" else spec.input, path = spec.inputPath, options = spec.extraInput}]
        transformers = [TransformerSpec {name = p, kind = p if p in ["batch", "memory_limiter"] else "transform"} for p in spec.processors]
        producers = [ProducerSpec {name = "debug" if spec.output == "stdout" else spec.output, kind = "debug" if spec.output == "stdout" else spec.output, endpoint = spec.endpoint, index = spec.index, options = spec.extraOutput}]
    }
}

build_otel_collector_config = lambda spec: LogPipelineSpec -> any {
    build_otel_collector_pipeline_config(pipeline_from_log_pipeline(spec))
}
