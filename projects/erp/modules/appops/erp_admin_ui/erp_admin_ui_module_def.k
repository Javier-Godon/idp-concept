"""
ERP admin UI module — a Nuxt SPA + Nitro BFF published under a sub-path of the shared hostname:
  - erp-owner-admin-interface  (platform operators, https://<erpUiHostname>/owner/)
  - erp-tenant-admin-interface (tenant administration, https://<erpUiHostname>/admin/)

Application workload: rendered as Tier-1 GitOps YAML (dev_apps pre-release), never wrapped in Crossplane.
The BFF signs users in against Keycloak (confidential OIDC client, Authorization Code + PKCE), keeps the
tokens in Valkey (`<cacheNamespace>/erp-cache`) and proxies `/api/erp/**` to the erp-backend Service inside
the cluster (plain HTTP, no gateway hop). The browser only talks to its own origin.

Secrets are referenced by name only and must exist in the application namespace:
  - `<secretName>`  keys `oidc-client-secret` (Keycloak client secret), `session-password` (>= 32 chars)
Optional ConfigMap `<caConfigMap>` with key `ca.crt`: CA of the gateway certificate, trusted by Node.js when the
BFF calls the public Keycloak issuer (self-signed on the dev site).
"""
import framework.templates.webapp.v1_0_0.webapp as webapp
import framework.builders.deployment as deploy
import framework.builders.route as route_builder

_HTTP_PORT = 3000
_CA_DIR = "/etc/platform-ca"

schema ErpAdminUiModule(webapp.WebAppModule):
    # Public sub-path without trailing slash, e.g. "/owner"; the app is served at "<basePath>/".
    basePath: str
    oidcClientId: str
    secretName: str
    caConfigMap?: str

    port = _HTTP_PORT
    serviceType = "ClusterIP"
    replicas = 1
    imagePullPolicy = "IfNotPresent"

    _origin = "https://${configurations.erpUiHostname}"
    _appUrl = "${_origin}${basePath}"
    _issuer = "https://${configurations.keycloakHostname}${configurations.keycloakPath}/realms/${configurations.erpBackendKeycloakRealm}"
    _apiBase = "http://erp-backend.${configurations.appsNamespace}.svc.cluster.local:8089${configurations.erpBackendPath}"
    _sessionStore = "redis://erp-cache.${configurations.cacheNamespace}.svc.cluster.local:6379"

    route = route_builder.RouteSpec {
        hostnames = [configurations.erpUiHostname]
        path = basePath
        trailingSlashRedirect = True
    }

    resources = deploy.ResourceSpec {
        cpuRequest = "50m"
        cpuLimit = "500m"
        memoryRequest = "128Mi"
        memoryLimit = "512Mi"
    }

    livenessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "${basePath}/healthz"
        port = _HTTP_PORT
        initialDelaySeconds = 5
        periodSeconds = 10
        failureThreshold = 3
    }

    readinessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "${basePath}/healthz"
        port = _HTTP_PORT
        initialDelaySeconds = 2
        periodSeconds = 5
        failureThreshold = 3
    }

    extraVolumes = [{name = "platform-ca", configMap = {name = caConfigMap, optional = True}}] if caConfigMap else []
    extraVolumeMounts = [{name = "platform-ca", mountPath = _CA_DIR, readOnly = True}] if caConfigMap else []

    env = [
        {name = "NUXT_APP_BASE_URL", value = "${basePath}/"}
        {name = "NUXT_PUBLIC_APP_ORIGIN", value = _origin}
        {name = "NUXT_ERP_API_BASE_URL", value = _apiBase}
        {name = "NUXT_OIDC_ISSUER", value = _issuer}
        {name = "NUXT_OIDC_CLIENT_ID", value = oidcClientId}
        {name = "NUXT_OIDC_CLIENT_SECRET", valueFrom = {secretKeyRef = {name = secretName, key = "oidc-client-secret"}}}
        {name = "NUXT_OIDC_REDIRECT_URI", value = "${_appUrl}/auth/callback"}
        {name = "NUXT_OIDC_POST_LOGOUT_REDIRECT_URI", value = "${_appUrl}/"}
        {name = "NUXT_SESSION_PASSWORD", valueFrom = {secretKeyRef = {name = secretName, key = "session-password"}}}
        {name = "NUXT_SESSION_STORAGE_URL", value = _sessionStore}
        # The platform gateway (Envoy) is the only proxy and appends the client address to X-Forwarded-For;
        # the BFF rate limits on that hop, never on client-supplied entries.
        {name = "NUXT_TRUSTED_PROXY_HOPS", value = "1"}
    ] + ([{name = "NODE_EXTRA_CA_CERTS", value = "${_CA_DIR}/ca.crt"}] if caConfigMap else [])

    check:
        basePath.startswith("/") and not basePath.endswith("/"), "basePath must look like /owner"
