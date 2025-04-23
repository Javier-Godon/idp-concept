
schema ComponentAsset:
    image: str
    version: str

schema Component:
    type: "APPLICATION" | "INFRASTRUCTURE"
    name: str
    asset: ComponentAsset
    manifests: [any]
    dependsOn?: [any]
