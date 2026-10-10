"""
Routes for platform tools installed outside the framework (Argo CD, Keycloak operator).
"""
import framework.templates.gateway_api.v1_0_0.gateway_api as gw

# Argo CD runs with server.rootpath=/argocd (gitops/argocd/argocd-cmd-params-cm.yaml),
# so the path is forwarded unchanged.
schema ArgoCDRouteModule(gw.HTTPRouteModule):
    serviceName = "argocd-server"
    servicePort = 80
    route = {
        hostnames = [configurations.platformHostname]
        path = "/argocd"
    }

# keycloak-operator Service <keycloak>-service, plain HTTP behind the gateway (proxy headers: xforwarded).
schema KeycloakRouteModule(gw.HTTPRouteModule):
    serviceName = "blue-keycloak-service"
    servicePort = 8080
    route = {
        hostnames = [configurations.platformHostname]
    }
