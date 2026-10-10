"""
Shared platform stack: API gateway + routes for platform tools.
Profile-specific folders override only the values that differ.
"""

import framework.models.stack
import framework.models.compatibility as compat
import platform.modules.networking.platform_gateway.platform_gateway_module_def as gateway
import platform.modules.networking.service_routes.service_routes_module_def as routes
# koncept:imports:end

schema PlatformStack(stack.Stack):
    compatibility = compat.FrameworkCompatibility {
        version = "dev"
        versionConstraint = ">=0.1.0 <1.0.0"
        supportTier = "tier-1"
        source = "local"
        supportWindow = "until next minor framework release"
    }

    # The XGateway composition owns the gateway namespace; route namespaces belong to their tools.
    k8snamespaces = []

    _gateway = gateway.PlatformGatewayModule {
        name = "platform-gateway"
        namespace = "gateway-system"
        asset = {version = "v1.9.2"}
        configurations = instanceConfigurations
        dependsOn = []
    }.instance

    _argocd_route = routes.ArgoCDRouteModule {
        name = "argocd"
        namespace = "argocd"
        asset = {version = "v3.5.4"}
        configurations = instanceConfigurations
        dependsOn = []
    }.instance

    _keycloak_route = routes.KeycloakRouteModule {
        name = "keycloak"
        namespace = "keycloak"
        asset = {version = "26.4"}
        configurations = instanceConfigurations
        dependsOn = []
    }.instance

    # koncept:modules:end

    components = []  # koncept:components
    accessories = [_gateway, _argocd_route, _keycloak_route]  # koncept:accessories
