import platform.core_sources.platform_configurations as cfg

# Local minikube cluster: the gateway listens on the node IP (192.168.49.2 in /etc/hosts)
# with a local CA, replacing the retired ingress-nginx addon.
_dev_cluster_site_configurations = cfg.PlatformConfigurations {
    siteName = "dev_cluster"
    footprint = "local"
    platformHostname = "bluesolution.es"
    gatewayAddresses = ["192.168.49.2"]
    gatewayTlsHostnames = ["bluesolution.es", "shop.railway.es"]
    gatewaySelfSignedCA = True
}
