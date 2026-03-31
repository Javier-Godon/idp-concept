"""
NetworkPolicy builder — generates Kubernetes NetworkPolicy resources.
Supports ingress-only, egress-only, both, or deny-all policies.
"""

schema NetworkPolicySpec:
    name: str
    namespace: str
    podSelector: {str:str}
    ingressRules?: [any]
    egressRules?: [any]

build_network_policy = lambda spec: NetworkPolicySpec -> any {
    _policy_types = []
    _policy_types += ["Ingress"] if spec.ingressRules else []
    _policy_types += ["Egress"] if spec.egressRules else []

    {
        apiVersion = "networking.k8s.io/v1"
        kind = "NetworkPolicy"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            podSelector = {
                if spec.podSelector:
                    matchLabels = spec.podSelector
            }
            if spec.ingressRules:
                ingress = spec.ingressRules
            if spec.egressRules:
                egress = spec.egressRules
            if _policy_types:
                policyTypes = _policy_types
        }
    }
}
