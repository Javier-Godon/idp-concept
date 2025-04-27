import framework.configs.models as model

dev_cluster_config = model.SiteConfig{
    name = "stg_cluster"
    rootPaths = {
        "local opensearch": "http://opensearch.opensearch"
        "central opensearch": "https://central-services/opensearch"
        "keycloak": "keycloak.keycloak/realm/auth"
    }
}