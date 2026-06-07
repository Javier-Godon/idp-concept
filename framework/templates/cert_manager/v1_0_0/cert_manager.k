"""
Cert-Manager Template — Certificate Management for Kubernetes

Deploys cert-manager via Bitnami Helm chart for automatic TLS certificate provisioning and renewal.
Supports Let's Encrypt and other ACME providers.

Charts:
- cert-manager (Bitnami): ACME client, certificate issuers, automating certificate renewal

Usage:
    import templates.cert_manager.v1_0_0.cert_manager as cm

    _cm = cm.build_cert_manager({
        name = "cert-manager"
        namespace = "cert-manager"
        replicas = 2
    })
"""

# Cert-Manager Template — placeholder for full implementation
# Implements HelmRelease + ClusterIssuer patterns for ACME-based certificate provisioning

_CERT_MANAGER_CHART = "oci://registry-1.docker.io/bitnamicharts/cert-manager"
_CERT_MANAGER_VERSION = "1.15.2"

build_cert_manager = lambda spec: any {
    {
        apiVersion = "helm.toolkit.fluxcd.io/v2beta1"
        kind = "HelmRelease"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            interval = "5m"
            chart = {
                spec = {
                    chart = "cert-manager"
                    version = spec.chartVersion if spec.chartVersion is not Undefined else _CERT_MANAGER_VERSION
                    sourceRef = {
                        kind = "HelmRepository"
                        name = "bitnami"
                        namespace = "flux-system"
                    }
                }
            }
            values = {
                "installCRDs" = "true"
                "replicaCount" = str(spec.replicas if spec.replicas is not Undefined else 2)
            }
            serviceAccountName = spec.name
        }
    }
}




