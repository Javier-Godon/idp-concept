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
    footprint = "development"
}
