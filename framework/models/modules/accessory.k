import models.modules.leader as base_leader

schema AccessoryAsset:
    image?: str
    version: str

schema AccessoryLeader(base_leader.Leader):
    """Leader specialisation for Accessories — inherits all fields from Leader."""

schema AccessoryInstance:
    name: str
    kind: str
    namespace: str
    configurations: any
    asset: AccessoryAsset
    leaders: [AccessoryLeader]
    manifests: [any]
    dependsOn: [any]

schema Accessory:
    instance: AccessoryInstance = AccessoryInstance {
        name = name
        kind = kind
        namespace = namespace
        configurations = configurations
        asset = asset
        leaders = leaders
        manifests = manifests
        dependsOn = dependsOn
    }
    kind: "CRD" | "SECRET"
    name: str
    namespace: str
    configurations: any
    asset: AccessoryAsset
    leaders: [AccessoryLeader]
    manifests: [any]
    dependsOn?: [any]

