"""
Leader — shared base schema for module leaders.
A leader identifies the primary workload resource that represents a module
(e.g., the Deployment that fronts a web app, the Kafka CRD that defines a cluster).

ComponentLeader, AccessoryLeader, and K8sNamespaceLeader all share
this same structure.  They inherit from Leader so existing code that
references the specialised names keeps working.
"""

schema Leader:
    """The primary resource that represents a module in the dependency graph."""
    name: str
    kind: str
    apiVersion: str
    namespace?: str
