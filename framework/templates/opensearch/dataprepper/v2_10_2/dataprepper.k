"""
Data Prepper Template — OpenSearch Data Prepper ingestion pipeline.

Operator note: Data Prepper does not currently have a widely adopted dedicated
OSS Kubernetes operator. This template uses Kubernetes-native controllers
(Deployment/Service/PDB) with pinned OpenSearch Project images and production
defaults. It avoids hardcoded secrets; inject credentials with env/valueFrom.
"""

import builders.configmap as cm
import builders.leader as leader
import builders.pdb as pdb
import builders.service as svc
import models.modules.component as component
import templates.observability.v1_0_0.telemetry_config as telemetry

_DEFAULT_IMAGE = "opensearchproject/data-prepper"
_DEFAULT_VERSION = "2.10.2"

schema DataPrepperResources:
    cpuRequest?: str = "500m"
    cpuLimit?: str = "2"
    memoryRequest?: str = "1Gi"
    memoryLimit?: str = "4Gi"

schema DataPrepperSpec:
    name: str
    namespace: str
    image?: str = _DEFAULT_IMAGE
    version?: str = _DEFAULT_VERSION
    replicas?: int = 2
    port?: int = 2021
    metricsPort?: int = 4900
    serviceType?: str = "ClusterIP"
    pipelineConfig?: str
    pipeline?: telemetry.LogPipelineSpec
    dataPrepperConfig?: str = "ssl: false\nmetricRegistries: [Prometheus]\n"
    log4j2Properties?: str = "status = error\nname = DataPrepperPropertiesConfig\n"
    env?: [any]
    resources?: DataPrepperResources = DataPrepperResources {}
    minAvailable?: int | str = 1

    check:
        len(name) > 0, "Data Prepper name must not be empty"
        len(namespace) > 0, "Data Prepper namespace must not be empty"
        len(version) > 0, "Data Prepper image version must be pinned"
        "latest" not in version, "Data Prepper image version must not be latest"
        replicas >= 1, "Data Prepper replicas must be >= 1"
        1 <= port <= 65535, "Data Prepper port must be between 1 and 65535"
        1 <= metricsPort <= 65535, "Data Prepper metricsPort must be between 1 and 65535"
        serviceType in ["ClusterIP", "NodePort", "LoadBalancer"], "serviceType must be ClusterIP, NodePort, or LoadBalancer"
        pipelineConfig is not Undefined or pipeline is not Undefined, "Data Prepper requires either pipelineConfig or pipeline"
        len(pipelineConfig) > 0 if pipelineConfig is not Undefined, "Data Prepper pipelineConfig must not be empty"

_pipeline_config = lambda spec: DataPrepperSpec -> str {
    spec.pipelineConfig if spec.pipelineConfig is not Undefined else telemetry.build_dataprepper_pipeline_config(spec.pipeline)
}

_resource_requirements = lambda spec: DataPrepperResources -> any {
    {
        requests = {
            cpu = spec.cpuRequest
            memory = spec.memoryRequest
        }
        limits = {
            cpu = spec.cpuLimit
            memory = spec.memoryLimit
        }
    }
}

build_dataprepper_configmap = lambda spec: DataPrepperSpec -> any {
    cm.build_configmap(cm.ConfigMapSpec {
        name = "${spec.name}-config"
        namespace = spec.namespace
        data = {
            "pipelines.yaml" = _pipeline_config(spec)
            "data-prepper-config.yaml" = spec.dataPrepperConfig
            "log4j2.properties" = spec.log4j2Properties
        }
    })
}

build_dataprepper_deployment = lambda spec: DataPrepperSpec -> any {
    {
        apiVersion = "apps/v1"
        kind = "Deployment"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {
                app = spec.name
                "app.kubernetes.io/name" = spec.name
                "app.kubernetes.io/component" = "data-prepper"
                "app.kubernetes.io/managed-by" = "idp-concept"
            }
        }
        spec = {
            replicas = spec.replicas
            strategy = {
                $type = "RollingUpdate"
                rollingUpdate = {
                    maxUnavailable = 1
                    maxSurge = 1
                }
            }
            selector = {matchLabels = {app = spec.name}}
            template = {
                metadata = {labels = {app = spec.name}}
                spec = {
                    securityContext = {
                        runAsNonRoot = True
                        runAsUser = 1000
                        runAsGroup = 1000
                        fsGroup = 1000
                        seccompProfile = {$type = "RuntimeDefault"}
                    }
                    containers = [{
                        name = spec.name
                        image = "${spec.image}:${spec.version}"
                        imagePullPolicy = "IfNotPresent"
                        args = [
                            "--config", "/usr/share/data-prepper/config/data-prepper-config.yaml",
                            "/usr/share/data-prepper/pipelines/pipelines.yaml"
                        ]
                        ports = [
                            {name = "ingest", containerPort = spec.port}
                            {name = "metrics", containerPort = spec.metricsPort}
                        ]
                        if spec.env:
                            env = spec.env
                        resources = _resource_requirements(spec.resources)
                        readinessProbe = {httpGet = {path = "/list", port = spec.metricsPort}, initialDelaySeconds = 20, periodSeconds = 10, timeoutSeconds = 5}
                        livenessProbe = {httpGet = {path = "/list", port = spec.metricsPort}, initialDelaySeconds = 60, periodSeconds = 20, timeoutSeconds = 5}
                        securityContext = {
                            allowPrivilegeEscalation = False
                            capabilities = {drop = ["ALL"]}
                        }
                        volumeMounts = [
                            {name = "config", mountPath = "/usr/share/data-prepper/config/data-prepper-config.yaml", subPath = "data-prepper-config.yaml", readOnly = True}
                            {name = "config", mountPath = "/usr/share/data-prepper/pipelines/pipelines.yaml", subPath = "pipelines.yaml", readOnly = True}
                            {name = "config", mountPath = "/usr/share/data-prepper/config/log4j2.properties", subPath = "log4j2.properties", readOnly = True}
                        ]
                    }]
                    volumes = [{name = "config", configMap = {name = "${spec.name}-config"}}]
                }
            }
        }
    }
}

build_dataprepper_service = lambda spec: DataPrepperSpec -> any {
    svc.build_service(svc.ServiceSpec {
        name = spec.name
        namespace = spec.namespace
        port = spec.port
        targetPort = spec.port
        serviceType = spec.serviceType
        portName = "ingest"
    })
}

build_dataprepper_pdb = lambda spec: DataPrepperSpec -> any {
    pdb.build_pdb(pdb.PDBSpec {
        name = spec.name
        namespace = spec.namespace
        matchLabels = {app = spec.name}
        minAvailable = spec.minAvailable
    })
}

build_dataprepper_resources = lambda spec: DataPrepperSpec -> [any] {
    _pdbs = [build_dataprepper_pdb(spec)] if spec.replicas > 1 else []
    [build_dataprepper_configmap(spec), build_dataprepper_service(spec), build_dataprepper_deployment(spec)] + _pdbs
}

schema DataPrepperModule(component.Component):
    """Component wrapper for deploying Data Prepper in a stack."""
    kind = "INFRASTRUCTURE"

    pipelineConfig?: str
    pipeline?: telemetry.LogPipelineSpec
    dataPrepperConfig?: str = "ssl: false\nmetricRegistries: [Prometheus]\n"
    log4j2Properties?: str = "status = error\nname = DataPrepperPropertiesConfig\n"
    replicas?: int = 2
    port?: int = 2021
    metricsPort?: int = 4900
    serviceType?: str = "ClusterIP"
    env?: [any]
    resources?: DataPrepperResources = DataPrepperResources {}

    leaders = [leader.build_component_leader(name, namespace)]

    manifests = build_dataprepper_resources(DataPrepperSpec {
        name = name
        namespace = namespace
        image = asset.image if asset.image != Undefined else _DEFAULT_IMAGE
        version = asset.version
        replicas = replicas
        port = port
        metricsPort = metricsPort
        serviceType = serviceType
        pipelineConfig = pipelineConfig
        pipeline = pipeline
        dataPrepperConfig = dataPrepperConfig
        log4j2Properties = log4j2Properties
        env = env
        resources = resources
    })
