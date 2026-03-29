"""
Leader Builder — helpers to create ComponentLeader and AccessoryLeader instances
without repeating the boilerplate pattern.
"""
import models.modules.component as component
import models.modules.accessory as accessory

build_component_leader = lambda name: str, namespace: str, kind: str = "Deployment", apiVersion: str = "apps/v1" -> component.ComponentLeader {
    component.ComponentLeader {
        name = name
        kind = kind
        apiVersion = apiVersion
        namespace = namespace
    }
}

build_accessory_leader = lambda name: str, namespace: str, kind: str, apiVersion: str -> accessory.AccessoryLeader {
    accessory.AccessoryLeader {
        name = name
        kind = kind
        apiVersion = apiVersion
        namespace = namespace
    }
}
