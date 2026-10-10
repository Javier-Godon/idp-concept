"""
platform project-specific configuration schema.
Extends BaseConfigurations with the shared API gateway settings.
"""

import framework.models.configurations as base

schema PlatformConfigurations(base.BaseConfigurations):
    footprint?: "local" | "development" | "staging" | "production"
    # Public hostname of the platform tools (Argo CD at /argocd, Keycloak at /).
    platformHostname?: str
    # Gateway: IPs set as proxy Service externalIPs (empty → LoadBalancer).
    gatewayAddresses?: [str]
    # Hostnames served over HTTPS (one certificate); plain HTTP is redirected for them.
    gatewayTlsHostnames?: [str]
    # cert-manager issuer for the gateway certificate, or a generated local CA (non-production).
    gatewayIssuerName?: str
    gatewaySelfSignedCA?: bool
