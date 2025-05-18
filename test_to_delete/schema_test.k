import k8s.api.core.v1 as core
import k8s.api.apps.v1 as apps

app_test: apps.Deployment {
    apiVersion = "apps/v1"
    kind = "Deployment"
    metadata = {
        name = "name"
        namespace = "namespace"
    }
    spec = {
        replicas = 1
        selector = {
            matchLabels = {
                app = "name"
            }
        }
        template = {
            metadata = {
                labels = {
                    app = "name"
                }
            }
            spec = {
                containers = [
                    {
                        image = "image"
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
                        name = "name"
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
