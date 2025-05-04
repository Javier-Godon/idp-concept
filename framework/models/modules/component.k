schema ComponentAsset:
    image?: str
    helmChart?: str
    version: str

schema ComponentLeader:
    name: str
    kind: str
    apiVersion: str
    namespace?: str

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

