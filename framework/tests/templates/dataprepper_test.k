import runtime
import templates.dataprepper as dp

_pipeline = "entry-pipeline:\n  source:\n    http:\n      path: /log/ingest\n  sink:\n    - stdout:\n"

test_dataprepper_resources = lambda {
    _resources = dp.build_dataprepper_resources(dp.DataPrepperSpec {
        name = "data-prepper"
        namespace = "observability"
        pipelineConfig = _pipeline
    })

    assert len(_resources) == 4
    assert _resources[0].kind == "ConfigMap"
    assert _resources[0].data["pipelines.yaml"] == _pipeline
    assert _resources[1].kind == "Service"
    assert _resources[1].spec.ports[0].port == 2021
    assert _resources[2].kind == "Deployment"
    assert _resources[2].spec.replicas == 2
    assert _resources[2].spec.template.spec.containers[0].image == "opensearchproject/data-prepper:2.10.2"
    assert _resources[3].kind == "PodDisruptionBudget"
}

test_dataprepper_single_replica_skips_pdb = lambda {
    _resources = dp.build_dataprepper_resources(dp.DataPrepperSpec {
        name = "data-prepper"
        namespace = "observability"
        replicas = 1
        pipelineConfig = _pipeline
    })

    assert len(_resources) == 3
}

test_dataprepper_custom_runtime_settings = lambda {
    _deploy = dp.build_dataprepper_deployment(dp.DataPrepperSpec {
        name = "data-prepper"
        namespace = "observability"
        version = "2.10.2"
        replicas = 3
        port = 21890
        metricsPort = 4901
        pipelineConfig = _pipeline
        env = [{name = "JAVA_OPTS", value = "-Xms512m -Xmx512m"}]
        resources = dp.DataPrepperResources {
            cpuRequest = "750m"
            cpuLimit = "1500m"
            memoryRequest = "2Gi"
            memoryLimit = "3Gi"
        }
    })

    _container = _deploy.spec.template.spec.containers[0]
    assert _deploy.spec.replicas == 3
    assert _container.ports[0].containerPort == 21890
    assert _container.ports[1].containerPort == 4901
    assert _container.env[0].name == "JAVA_OPTS"
    assert _container.resources.requests.cpu == "750m"
    assert _container.securityContext.allowPrivilegeEscalation == False
    assert _deploy.spec.template.spec.securityContext.runAsNonRoot == True
}

test_dataprepper_rejects_latest_version = lambda {
    _err = runtime.catch(lambda {
        dp.DataPrepperSpec {
            name = "data-prepper"
            namespace = "observability"
            version = "latest"
            pipelineConfig = _pipeline
        }
    })
    assert _err != Undefined, "Expected validation error for latest Data Prepper image version"
}

test_dataprepper_rejects_empty_pipeline = lambda {
    _err = runtime.catch(lambda {
        dp.DataPrepperSpec {
            name = "data-prepper"
            namespace = "observability"
            pipelineConfig = ""
        }
    })
    assert _err != Undefined, "Expected validation error for empty Data Prepper pipeline"
}
