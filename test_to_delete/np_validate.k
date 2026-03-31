import builders.network_policy as np
import manifests

manifests.yaml_stream([np.build_network_policy(np.NetworkPolicySpec {
    name = "test-policy"
    namespace = "apps"
    podSelector = {app = "web"}
    ingressRules = [
        {
            from = [{podSelector = {matchLabels = {app = "api"}}}]
            ports = [{protocol = "TCP", port = 8080}]
        }
    ]
})])
