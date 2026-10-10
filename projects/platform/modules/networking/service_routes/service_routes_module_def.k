"""
Routes for platform tools installed outside the framework (Argo CD).
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
