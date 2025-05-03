import framework.configs.models.site_config

berlin_config = site_config.SiteConfig {
    name = "berlin"
    rootPaths = {
        "local opensearch": "http://opensearch.opensearch"
        "central opensearch": "https://central-services/opensearch"
        "keycloak": "keycloak.keycloak/realm/auth"
    }
}
