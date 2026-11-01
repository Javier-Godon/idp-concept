import erp.core_sources.erp_configurations as cfg

_erp_profile_configurations = cfg.ErpConfigurations {
    cacheNamespace = "erp-data"
    # Valkey Admin UI on the shared hostname at /valkey-admin. It has no login of its own: the gateway enforces
    # basic auth from this Secret (`.htpasswd` key), created out of band in the cache namespace.
    valkeyAdminHostname = "bluesolution.es"
    valkeyAdminPath = "/valkey-admin"
    valkeyAdminBasicAuthSecret = "valkey-admin-basic-auth"
    postgresNamespace = "erp-postgres"
    postgresFootprint = "development"
    postgresDatabase = "blue_postgres"
    postgresSuperuserSecret = "erp-postgres-superuser"
    postgresClusterName = "erp-postgres"
    # The Keycloak operator watches only its own namespace; keycloak-db-secret is created out of band there.
    keycloakNamespace = "keycloak"
    keycloakFootprint = "development"
    keycloakHostname = "bluesolution.es"
    keycloakPath = "/iam"
    keycloakDbSchema = "keycloak"
    keycloakDbSecret = "keycloak-db-secret"
    # Keycloak 26.4.0 plus the `erp` login theme (erp-keycloak-theme), built locally and loaded into minikube.
    keycloakImage = "ghcr.io/javier-godon/erp-keycloak:26.4.0-erp-theme-0.1.0-5d988a6"
    footprint = "development"
    # erp-backend API (dev_apps pre-release). Pin the image tag published by the erp-backend CD workflow.
    # Secrets are created out of band in appsNamespace (docs/platform-engineering/PLATFORM_INSTALLATION.md).
    appsNamespace = "erp-backend"
    erpBackendImage = "ghcr.io/javier-godon/erp-backend"
    erpBackendVersion = "v0.1.0-0d2a16e-20261101-1306"
    erpBackendPath = "/shopping"
    erpApiPath = "/api"
    erpBackendPullSecret = "ghcr-secret"
    erpBackendDbSecret = "erp-backend-db"
    erpBackendKeycloakSecret = "erp-backend-keycloak"
    erpBackendKeycloakRealm = "railway"
    # Admin UIs: owner console at /owner, tenant administration at /admin (Keycloak clients and the
    # `erp-*-admin` Secrets are created out of band — docs/platform-engineering/PLATFORM_INSTALLATION.md).
    # Images are built locally and loaded into minikube until their CD pipelines publish them (tag v0.1.0-<sha7>).
    erpUiHostname = "bluesolution.es"
    platformCaConfigMap = "platform-ca"
    erpOwnerAdminImage = "ghcr.io/javier-godon/erp-owner-admin-interface"
    erpOwnerAdminVersion = "v0.1.0-d35d313-20261101-1340"
    erpOwnerAdminPath = "/owner"
    erpOwnerAdminOidcClientId = "erp-owner-admin-bff"
    erpOwnerAdminSecret = "erp-owner-admin"
    erpTenantAdminImage = "ghcr.io/javier-godon/erp-tenant-admin-interface"
    erpTenantAdminVersion = "v0.1.0-a9cf362-20261101-1340"
    erpTenantAdminPath = "/admin"
    erpTenantAdminOidcClientId = "erp-tenant-admin-bff"
    erpTenantAdminSecret = "erp-tenant-admin"
    # APISIX: API gateway for the REST API (`/api`) with its Admin UI at /apisix (-> /ui). Envoy Gateway stays the
    # edge; the admin keys Secret is created out of band (docs/platform-engineering/PLATFORM_INSTALLATION.md).
    apisixNamespace = "apisix"
    apisixName = "erp-apisix"
    apisixFootprint = "development"
    apisixHostname = "bluesolution.es"
    apisixAdminKeySecret = "apisix-admin-keys"
    # minikube pod network (Envoy Gateway proxy and the ingress controller call the Admin API from it).
    apisixAdminAllowCidrs = ["10.244.0.0/16"]
}
