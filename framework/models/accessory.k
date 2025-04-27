schema AccessoryAsset:
    image?: str
    version: str

schema AccessoryLeader:
    name: str
    kind: str
    apiVersion: str
    namespace?: str

schema AccessoryInstance:
    name: str
    kind: str
    namespace: str
    asset: AccessoryAsset
    leaders: [AccessoryLeader]
    manifests: [any]
    dependsOn: [any]

schema Accessory:
    instance: AccessoryInstance = AccessoryInstance {
        name=name
        kind=kind
        namespace =namespace
        asset = asset
        leaders = leaders
        manifests = manifests
        dependsOn = dependsOn
    }
    kind: "CRD" | "SECRET"
    name: str
    namespace: str
    asset: AccessoryAsset
    leaders: [AccessoryLeader]
    manifests: [any]
    dependsOn?: [any]

