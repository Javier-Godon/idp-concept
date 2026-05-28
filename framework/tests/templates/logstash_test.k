import runtime
import templates.elastic.v7_10_2.logstash as logstash

_pipeline = "input { beats { port => 5044 } }\noutput { stdout { codec => rubydebug } }\n"

test_logstash_resources = lambda {
    _resources = logstash.build_logstash_resources(logstash.LogstashSpec {
        name = "logstash"
        namespace = "search"
        pipelineConfig = _pipeline
    })

    assert len(_resources) == 4
    assert _resources[0].kind == "ConfigMap"
    assert _resources[0].data["logstash.conf"] == _pipeline
    assert _resources[1].kind == "Service"
    assert _resources[1].spec.ports[0].port == 5044
    assert _resources[2].kind == "Deployment"
    assert _resources[2].spec.template.spec.containers[0].image == "docker.elastic.co/logstash/logstash-oss:7.10.2"
    assert _resources[3].kind == "PodDisruptionBudget"
}

test_logstash_custom_ports = lambda {
    _deploy = logstash.build_logstash_deployment(logstash.LogstashSpec {
        name = "logstash"
        namespace = "search"
        pipelineConfig = _pipeline
        beatsPort = 5050
        monitoringPort = 9700
        javaOpts = "-Xms2g -Xmx2g"
    })

    assert _deploy.spec.template.spec.containers[0].ports[0].containerPort == 5050
    assert _deploy.spec.template.spec.containers[0].ports[1].containerPort == 9700
    assert _deploy.spec.template.spec.containers[0].env[0].value == "-Xms2g -Xmx2g"
}

test_logstash_rejects_empty_pipeline = lambda {
    _err = runtime.catch(lambda {
        logstash.LogstashSpec {
            name = "logstash"
            namespace = "search"
            pipelineConfig = ""
        }
    })
    assert _err != Undefined, "Expected validation error for empty Logstash pipeline"
}

test_logstash_rejects_non_oss_version = lambda {
    _err = runtime.catch(lambda {
        logstash.LogstashSpec {
            name = "logstash"
            namespace = "search"
            version = "8.15.0"
            pipelineConfig = _pipeline
        }
    })
    assert _err != Undefined, "Expected validation error for non-OSS Logstash version"
}
