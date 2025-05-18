import framework.models.modules.component as component
import k8s.api.core.v1 as core
import k8s.api.apps.v1 as apps

schema VideoCollectorMongodbPythonModule(component.Component):
    kind = "APPLICATION"
    leaders = [component.ComponentLeader {
        name = name
        kind = "Deployment"
        apiVersion = "apps/v1"
        namespace = namespace
    }]
    manifests = [
        apps.Deployment {
            apiVersion = "apps/v1"
            kind = "Deployment"
            metadata = {
                name = name
                namespace = namespace
            }
            spec = {
                replicas = 1
                selector = {
                    matchLabels = {
                        app = name
                    }
                }
                template = {
                    metadata = {
                        labels = {
                            app = name
                        }
                    }
                    spec = {
                        containers = [
                            {
                                image = "${asset.image}:${asset.version}"
                                imagePullPolicy = "IfNotPresent"
                                livenessProbe = {
                                    exec = {
                                        command = [
                                            "/bin/sh"
                                            "-c"
                                            "echo livenessProbe"
                                        ]
                                    }
                                    failureThreshold = 3
                                    initialDelaySeconds = 30
                                    periodSeconds = 5
                                    successThreshold = 1
                                    timeoutSeconds = 10
                                }
                                name = name
                                readinessProbe = {
                                    exec = {
                                        command = [
                                            "/bin/sh"
                                            "-c"
                                            "echo readinessProbe"
                                        ]
                                    }
                                    failureThreshold = 3
                                    initialDelaySeconds = 30
                                    periodSeconds = 5
                                    successThreshold = 1
                                    timeoutSeconds = 10
                                }
                                resources = {
                                    limits = {
                                        cpu = "1"
                                        memory = "2Gi"
                                        "ephemeral-storage" = "20Gi"
                                    }
                                    requests = {
                                        cpu = "1"
                                        memory = "2Gi"
                                        "ephemeral-storage" = "20Gi"
                                    }
                                }
                                startupProbe = {
                                    exec = {
                                        command = [
                                            "/bin/sh"
                                            "-c"
                                            "echo startupProbe"
                                        ]
                                    }
                                    failureThreshold = 3
                                    initialDelaySeconds = 30
                                    periodSeconds = 5
                                    successThreshold = 1
                                    timeoutSeconds = 10
                                }
                                volumeMounts = [
                                    {
                                        mountPath = "/code/app/configuration/application.yaml"
                                        name = "application-configuration"
                                        subPath = "application.yaml"
                                    }
                                ]
                            }
                        ]
                        serviceAccountName = "github-service-pull-image-account-kafka-video-consumer-mongodb-python"
                        volumes = [
                            {
                                configMap = {
                                    name = "kafka-video-consumer-mongodb-python-configmap"
                                    items = [
                                        {
                                            key = "application.yaml"
                                            path = "application.yaml"
                                        }
                                    ]
                                }
                                name = "application-configuration"
                            }
                        ]
                    }
                }
            }
        }
        core.ConfigMap {
            apiVersion = "v1"
            data = {
                "application.yaml" = r"""server:
  port: 8002
kafka:
  topics:
    processed: processed-video
    streaming: streaming-video
  consumer:
    bootstrap-servers: blue-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
    key-serializer: serializer
    value-serializer: serializer
    acks: all
    auto-offset-reset: earliest
mongodb:
  uri:  mongodb://admin:admin@blue-mongo-db.mongodb.svc.cluster.local:27017/admin?readPreference=primaryPreferred
  database: blue-mongodb
"""
            }
            kind = "ConfigMap"
            metadata = {
                name = "kafka-video-consumer-mongodb-python-configmap"
                namespace = namespace
            }
        }
        core.Service {
            apiVersion = "v1"
            kind = "Service"
            metadata = {
                name = name
                namespace = namespace
            }
            spec = {
                ports = [
                    {
                        name = "kafka-video-consumer-mongodb-python-server"
                        nodePort = 31021
                        port = 8002
                    }
                ]
                selector = {
                    app = name
                }
                $type = "NodePort"
            }
        }
        core.ServiceAccount {
            apiVersion = "v1"
            imagePullSecrets = [
                {
                    name = "pull-image-from-github-registry-secret"
                }
            ]
            kind = "ServiceAccount"
            metadata = {
                name = "github-service-pull-image-account-kafka-video-consumer-mongodb-python"
                namespace = namespace
            }
        }
    ]

