schema AccessoryAsset:
    image: str
    version: str

schema Accessory:
    type: "CRD" | "SECRET"
    name: str
    asset: AccessoryAsset
    manifests: [any]
    dependsOn?: [any]