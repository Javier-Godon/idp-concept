"""
Leader Builder — helpers to create Leader instances.

Provides a unified `build_leader` plus backward-compatible aliases
`build_component_leader` (defaults to Deployment/apps-v1) and
`build_accessory_leader` (requires explicit kind/apiVersion).
"""
import models.modules.leader as base_leader
import models.modules.component as component
import models.modules.accessory as accessory

build_leader = lambda name: str, namespace: str, kind: str = "Deployment", apiVersion: str = "apps/v1" -> base_leader.Leader {
    base_leader.Leader {
        name = name
        kind = kind
        apiVersion = apiVersion
        namespace = namespace
    }
}

# Backward-compatible aliases — prefer build_leader for new code
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
