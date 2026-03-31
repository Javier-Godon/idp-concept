"""
PodDisruptionBudget builder — generates PDB resources for high-availability deployments.
Supports minAvailable and maxUnavailable (int or percentage string).
"""

schema PDBSpec:
    name: str
    namespace: str
    matchLabels: {str:str}
    minAvailable?: int | str
    maxUnavailable?: int | str

build_pdb = lambda spec: PDBSpec -> any {
    {
        apiVersion = "policy/v1"
        kind = "PodDisruptionBudget"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            selector = {
                matchLabels = spec.matchLabels
            }
            if spec.minAvailable is not Undefined:
                minAvailable = spec.minAvailable
            if spec.maxUnavailable is not Undefined:
                maxUnavailable = spec.maxUnavailable
        }
    }
}
