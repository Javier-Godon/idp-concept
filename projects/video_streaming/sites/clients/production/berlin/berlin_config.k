import framework.configs.models as model

berlin_config = model.SiteConfig{
    name = "berlin"
    rootPaths = {
        "local opensearch": "http://opensearch.opensearch"
        "central opensearch": "https://central-services/opensearch"
        "keycloak": "keycloak.keycloak/realm/auth"
    }
}