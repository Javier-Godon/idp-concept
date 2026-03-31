import runtime
import builders.network_policy as np

# --- Test: basic network policy with ingress ---
test_build_network_policy_ingress = lambda {
    _spec = np.NetworkPolicySpec {
        name = "allow-web"
        namespace = "apps"
        podSelector = {app = "web"}
        ingressRules = [
            {
                from = [{podSelector = {matchLabels = {app = "api"}}}]
                ports = [{protocol = "TCP", port = 8080}]
            }
        ]
    }
    _result = np.build_network_policy(_spec)
    assert _result.apiVersion == "networking.k8s.io/v1"
    assert _result.kind == "NetworkPolicy"
    assert _result.metadata.name == "allow-web"
    assert _result.metadata.namespace == "apps"
    assert _result.spec.podSelector.matchLabels.app == "web"
    assert len(_result.spec.ingress) == 1
    assert "Ingress" in _result.spec.policyTypes
}

# --- Test: egress only ---
test_build_network_policy_egress = lambda {
    _spec = np.NetworkPolicySpec {
        name = "allow-dns"
        namespace = "apps"
        podSelector = {app = "api"}
        egressRules = [
            {
                to = [{namespaceSelector = {matchLabels = {"kubernetes.io/metadata.name" = "kube-system"}}}]
                ports = [{protocol = "UDP", port = 53}]
            }
        ]
    }
    _result = np.build_network_policy(_spec)
    assert "Egress" in _result.spec.policyTypes
    assert len(_result.spec.egress) == 1
    assert _result.spec.ingress is Undefined
}

# --- Test: both ingress and egress ---
test_build_network_policy_both = lambda {
    _spec = np.NetworkPolicySpec {
        name = "full-policy"
        namespace = "apps"
        podSelector = {app = "web"}
        ingressRules = [
            {from = [{podSelector = {matchLabels = {app = "api"}}}]}
        ]
        egressRules = [
            {to = [{podSelector = {matchLabels = {app = "db"}}}]}
        ]
    }
    _result = np.build_network_policy(_spec)
    assert "Ingress" in _result.spec.policyTypes
    assert "Egress" in _result.spec.policyTypes
    assert len(_result.spec.ingress) == 1
    assert len(_result.spec.egress) == 1
}

# --- Test: deny-all (no rules) ---
test_build_network_policy_deny_all = lambda {
    _spec = np.NetworkPolicySpec {
        name = "deny-all"
        namespace = "default"
        podSelector = {}
    }
    _result = np.build_network_policy(_spec)
    assert _result.spec.podSelector.matchLabels is Undefined or len(_result.spec.podSelector.matchLabels) == 0
    assert _result.spec.ingress is Undefined
    assert _result.spec.egress is Undefined
}
