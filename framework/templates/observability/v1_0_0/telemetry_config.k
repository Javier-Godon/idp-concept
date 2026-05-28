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

endpoint_hostport = lambda endpoint: TelemetryEndpoint -> str {
    "${endpoint.host}:${endpoint.port}"
}

endpoint_url = lambda endpoint: TelemetryEndpoint -> str {
    _scheme = "https" if endpoint.tls and endpoint.scheme == "http" else endpoint.scheme
    _path = endpoint.path if endpoint.path else ""
    "${_scheme}://${endpoint.host}:${endpoint.port}${_path}" if _scheme in ["http", "https"] else "${endpoint.host}:${endpoint.port}"
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

build_otel_collector_config = lambda spec: LogPipelineSpec -> any {
    _receiver_name = "otlp" if spec.input in ["otlp", "http", "forward"] else "filelog"
    _receivers = {
        if _receiver_name == "otlp":
            otlp = {protocols = {grpc = {endpoint = "0.0.0.0:4317"}, http = {endpoint = "0.0.0.0:4318"}}}
        if _receiver_name == "filelog":
            filelog = {include = [spec.inputPath], start_at = "end"}
    }
    _exporter_name = "debug" if spec.output == "stdout" else spec.output
    _exporters = {
        if spec.output == "stdout":
            debug = {}
        if spec.output == "opensearch":
            opensearch = {http = {endpoint = endpoint_url(spec.endpoint)}}
        if spec.output == "http":
            http = {endpoint = endpoint_url(spec.endpoint)}
        if spec.output == "otlp":
            otlp = {endpoint = endpoint_hostport(spec.endpoint), tls = {insecure = not spec.endpoint.tls}}
    }
    {
        receivers = _receivers
        processors = {batch = {}}
        exporters = _exporters
        pipelines = {
            logs = {
                receivers = [_receiver_name]
                processors = spec.processors
                exporters = [_exporter_name]
            }
        }
    }
}
