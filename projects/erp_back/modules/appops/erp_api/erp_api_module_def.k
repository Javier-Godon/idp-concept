"""
ERP API Module — Spring Boot Java application.
Uses the WebAppModule template from framework, reducing ~190 lines to ~30.
"""
import framework.templates.webapp as webapp
import framework.builders.deployment as deploy

schema ErpApiModule(webapp.WebAppModule):
    port = 8080
    serviceType = "ClusterIP"
    replicas = 1
    imagePullPolicy = "IfNotPresent"

    resources = deploy.ResourceSpec {
        cpuRequest = "500m"
        cpuLimit = "2"
        memoryRequest = "1Gi"
        memoryLimit = "4Gi"
    }

    livenessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health/liveness"
        port = 8080
        initialDelaySeconds = 60
        periodSeconds = 10
        failureThreshold = 5
    }

    readinessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health/readiness"
        port = 8080
        initialDelaySeconds = 30
        periodSeconds = 5
    }

    startupProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health"
        port = 8080
        initialDelaySeconds = 30
        periodSeconds = 10
        failureThreshold = 10
    }

    env = [
        {
            name = "SPRING_PROFILES_ACTIVE"
            value = configurations.springProfile if configurations.springProfile else "default"
        }
        {
            name = "JAVA_OPTS"
            value = configurations.javaOpts if configurations.javaOpts else "-Xmx1g -Xms512m"
        }
        {
            name = "SPRING_DATASOURCE_URL"
            value = "jdbc:postgresql://${configurations.postgresHost}:${configurations.postgresPort}/${configurations.postgresDatabase}"
        }
        {
            name = "SPRING_DATASOURCE_USERNAME"
            valueFrom = {
                secretKeyRef = {
                    name = "erp-db-credentials"
                    key = "username"
                }
            }
        }
        {
            name = "SPRING_DATASOURCE_PASSWORD"
            valueFrom = {
                secretKeyRef = {
                    name = "erp-db-credentials"
                    key = "password"
                }
            }
        }
    ]
