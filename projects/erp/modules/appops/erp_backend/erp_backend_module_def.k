"""
erp-backend module — the ERP Spring Boot API (https://github.com/Javier-Godon/erp-backend).

Application workload: rendered as Tier-1 GitOps YAML (dev_apps pre-release, `koncept render argocd`),
never wrapped in Crossplane. It consumes the curated data/identity services of this project:
  - PostgreSQL: the CloudNativePG cluster `<postgresClusterName>` (read-write service), database
    `<postgresDatabase>`; Flyway creates the per-bounded-context schemas on startup.
  - Keycloak: the operator-managed instance served at `<keycloakHostname><keycloakPath>`. Tokens are issued
    for the public URL (issuer); keys and admin calls go to the in-cluster Service `keycloakServiceName`.

The HTTP API listens on 8089 under the `/shopping` context path; Spring Boot Actuator listens on 9090.
Secrets are referenced by name only and must exist in the application namespace:
  - `<erpBackendPullSecret>`     docker-registry Secret for the private GHCR image
  - `<erpBackendDbSecret>`       keys `username`, `password`
  - `<erpBackendKeycloakSecret>` keys `admin-client-secret`, `iam-client-secret` (optional)
"""
import framework.templates.webapp.v1_0_0.webapp as webapp
import framework.builders.deployment as deploy

_HTTP_PORT = 8089
_MANAGEMENT_PORT = 9090

schema ErpBackendModule(webapp.WebAppModule):
    # Name of the Keycloak operator Service (`<keycloak name>-service`), set by the stack.
    keycloakServiceName: str

    port = _HTTP_PORT
    serviceType = "ClusterIP"
    replicas = 1
    imagePullPolicy = "IfNotPresent"
    imagePullSecretName = configurations.erpBackendPullSecret

    _realm = configurations.erpBackendKeycloakRealm
    _keycloakInternalUrl = "http://${keycloakServiceName}.${configurations.keycloakNamespace}.svc.cluster.local:8080${configurations.keycloakPath}"
    _keycloakIssuer = "https://${configurations.keycloakHostname}${configurations.keycloakPath}/realms/${_realm}"
    _postgresHost = "${configurations.postgresClusterName}-rw.${configurations.postgresNamespace}.svc.cluster.local"

    route = {
        hostnames = [configurations.erpBackendHostname]
        path = configurations.erpBackendPath
    }

    resources = deploy.ResourceSpec {
        cpuRequest = "250m"
        cpuLimit = "2"
        memoryRequest = "768Mi"
        memoryLimit = "1536Mi"
    }

    # Flyway migrates every bounded-context schema on the first start: allow up to ~5 minutes.
    startupProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health"
        port = _MANAGEMENT_PORT
        initialDelaySeconds = 20
        periodSeconds = 10
        failureThreshold = 30
    }

    livenessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health/liveness"
        port = _MANAGEMENT_PORT
        initialDelaySeconds = 0
        periodSeconds = 10
        failureThreshold = 3
    }

    readinessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/actuator/health/readiness"
        port = _MANAGEMENT_PORT
        initialDelaySeconds = 0
        periodSeconds = 5
        failureThreshold = 3
    }

    env = [
        {name = "SPRING_DATASOURCE_URL", value = "jdbc:postgresql://${_postgresHost}:5432/${configurations.postgresDatabase}"}
        {name = "SPRING_DATASOURCE_USERNAME", valueFrom = {secretKeyRef = {name = configurations.erpBackendDbSecret, key = "username"}}}
        {name = "SPRING_DATASOURCE_PASSWORD", valueFrom = {secretKeyRef = {name = configurations.erpBackendDbSecret, key = "password"}}}
        {name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = _keycloakIssuer}
        {name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI", value = "${_keycloakInternalUrl}/realms/${_realm}/protocol/openid-connect/certs"}
        {name = "KEYCLOAK_ADMIN_CLIENT_AUTH_SERVER_URL", value = _keycloakInternalUrl}
        {name = "KEYCLOAK_ADMIN_CLIENT_REALM", value = _realm}
        {name = "KEYCLOAK_IAM_CLIENT_AUTH_SERVER_URL", value = _keycloakInternalUrl}
        {name = "KEYCLOAK_IAM_CLIENT_REALM", value = _realm}
        {name = "KEYCLOAK_ADMIN_CLIENT_SECRET", valueFrom = {secretKeyRef = {name = configurations.erpBackendKeycloakSecret, key = "admin-client-secret", optional = True}}}
        {name = "KEYCLOAK_IAM_CLIENT_SECRET", valueFrom = {secretKeyRef = {name = configurations.erpBackendKeycloakSecret, key = "iam-client-secret", optional = True}}}
    ]
