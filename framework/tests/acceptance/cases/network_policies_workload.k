"""
Acceptance fixture: Kubernetes NetworkPolicy resources through the IDP render path.
Tests: Zero-trust deny-all + selective allow policies for namespace isolation.
Level: L0 (render only) — built-in Kubernetes resources, no operator needed.
"""

import ._helpers as h
import templates.network_policies.v1_0_0.network_policies as np

_namespace = "idp-acceptance-network-policies"
_deny_ingress = np.build_deny_all_ingress({namespace = _namespace})
_deny_egress = np.build_deny_all_egress({namespace = _namespace})
_allow_monitoring = np.build_allow_from_namespace({
    name = "allow-from-monitoring"
    namespace = _namespace
    sourceNamespace = "monitoring"
    port = 8080
})
_allow_egress_dns = np.build_allow_egress({
    name = "allow-egress-dns"
    namespace = _namespace
})

_module = h.wrap_accessory(
    "acceptance-network-policies",
    _namespace,
    "networking.k8s.io/v1",
    "NetworkPolicy",
    [_deny_ingress, _deny_egress, _allow_monitoring, _allow_egress_dns],
    "1.0.0"
)

h.render_accessory(_namespace, _module)
