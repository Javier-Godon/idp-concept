import models.modules.leader as base_leader

schema ComponentAsset:
    image?: str
    helmChart?: str
    version: str

schema ComponentLeader(base_leader.Leader):
    """Leader specialisation for Components — inherits all fields from Leader."""

schema ComponentInstance:
    name: str
    kind: str
    namespace: str
    configurations: any
    asset: ComponentAsset
    leaders: [ComponentLeader]
    manifests: [any]
    dependsOn: [any]

schema Component:
    instance: ComponentInstance = ComponentInstance {
        name = name
        kind = kind
        namespace = namespace
        configurations = configurations
        asset = asset
        leaders = leaders
        manifests = manifests
        dependsOn = dependsOn
    }
    kind: "APPLICATION" | "INFRASTRUCTURE"
    name: str
    namespace: str
    configurations: any
    asset: ComponentAsset
    leaders: [ComponentLeader]
    manifests: [any]
    dependsOn?: [any]

