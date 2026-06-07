"""
Network Policies Template — Kubernetes Network Isolation and Policy Management

Provides Kubernetes NetworkPolicy resources for zero-trust networking, micro-segmentation,
and fine-grained ingress/egress controls. Works with CNI plugins that support network policies
(Calico, Cilium, Weave, etc.).

Usage:
    import templates.network_policies.v1_0_0.network_policies as np

    _deny_all = np.build_deny_all_ingress({
        namespace = "apps"
    })

    _allow_from_ns = np.build_allow_from_namespace({
        name = "allow-from-monitoring"
        namespace = "apps"
        sourceNamespace = "monitoring"
        port = 8080
    })
"""

# Network Policies Template
# Implements zero-trust networking with Kubernetes NetworkPolicy resources

build_deny_all_ingress = lambda spec: any {
    {
        apiVersion = "networking.k8s.io/v1"
        kind = "NetworkPolicy"
        metadata = {
            name = "deny-all-ingress"
            namespace = spec.namespace
        }
        spec = {
            podSelector = {}
            policyTypes = ["Ingress"]
        }
    }
}

build_deny_all_egress = lambda spec: any {
    {
        apiVersion = "networking.k8s.io/v1"
        kind = "NetworkPolicy"
        metadata = {
            name = "deny-all-egress"
            namespace = spec.namespace
        }
        spec = {
            podSelector = {}
            policyTypes = ["Egress"]
        }
    }
}

build_allow_from_namespace = lambda spec: any {
    {
        apiVersion = "networking.k8s.io/v1"
        kind = "NetworkPolicy"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            podSelector = {}
            policyTypes = ["Ingress"]
            ingress = [{
                from = [{
                    namespaceSelector = {
                        matchLabels = {"kubernetes.io/metadata.name": spec.sourceNamespace if spec.sourceNamespace is not Undefined else ""}
                    }
                }]
                ports = [{
                    "protocol" = "TCP"
                    port = spec.port if spec.port is not Undefined else 8080
                }] if spec.port is not Undefined else []
            }]
        }
    }
}

build_allow_egress = lambda spec: any {
    {
        apiVersion = "networking.k8s.io/v1"
        kind = "NetworkPolicy"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            podSelector = {}
            policyTypes = ["Egress"]
            egress = [{
                to = [{
                    ipBlock = {
                        cidr = "0.0.0.0/0"
                    }
                }]
                ports = [{
                    "protocol" = "UDP"
                    port = 53
                }]
            }]
        }
    }
}


