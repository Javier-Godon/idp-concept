"""
External-DNS Template — Automatic DNS Management for Kubernetes

Deploys external-dns to automatically manage DNS records in external DNS providers
(AWS Route 53, Azure DNS, Google Cloud DNS, etc.) based on Kubernetes Ingress and Service resources.

Charts:
- external-dns (Bitnami): DNS provider integration, automatic record synchronization

Usage:
    import templates.external_dns.v1_0_0.external_dns as edns

    _external_dns = edns.build_external_dns({
        name = "external-dns"
        namespace = "kube-system"
        provider = "aws"
    })
"""

_EXTERNAL_DNS_CHART = "oci://registry-1.docker.io/bitnamicharts/external-dns"
_EXTERNAL_DNS_VERSION = "1.15.1"

build_external_dns = lambda spec: any {
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
                    chart = "external-dns"
                    version = spec.chartVersion if spec.chartVersion is not Undefined else _EXTERNAL_DNS_VERSION
                    sourceRef = {
                        kind = "HelmRepository"
                        name = "bitnami"
                        namespace = "flux-system"
                    }
                }
            }
            values = {
                "provider" = spec.provider if spec.provider is not Undefined else "aws"
                "policy" = spec.policy if spec.policy is not Undefined else "sync"
                "registry" = spec.registry if spec.registry is not Undefined else "txt"
                "replicaCount" = str(spec.replicas if spec.replicas is not Undefined else 2)
            }
            serviceAccountName = spec.name
        }
    }
}


