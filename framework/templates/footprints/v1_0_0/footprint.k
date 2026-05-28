"""
Deployment footprint helpers.

A footprint is the resource/availability size of an infrastructure template:
- local: smallest functional shape for kind/minikube/laptop usage.
- development: low-cost shared dev shape.
- staging: production-like, smaller than production.
- production: HA/resource-conscious defaults.
"""

_ALLOWED_FOOTPRINTS = ["local", "development", "staging", "production"]

schema FootprintSpec:
    name?: str = "production"

    check:
        name in _ALLOWED_FOOTPRINTS, "footprint must be local, development, staging, or production"

is_local = lambda name: str -> bool {
    name == "local"
}

is_non_production = lambda name: str -> bool {
    name in ["local", "development", "staging"]
}

is_ha = lambda name: str -> bool {
    name in ["staging", "production"]
}

replicas = lambda name: str, local: int = 1, development: int = 1, staging: int = 2, production: int = 3 -> int {
    local if name == "local" else development if name == "development" else staging if name == "staging" else production
}

storage_size = lambda name: str, local: str = "1Gi", development: str = "2Gi", staging: str = "8Gi", production: str = "50Gi" -> str {
    local if name == "local" else development if name == "development" else staging if name == "staging" else production
}

retention_days = lambda name: str, local: int = 1, development: int = 3, staging: int = 7, production: int = 15 -> int {
    local if name == "local" else development if name == "development" else staging if name == "staging" else production
}

storage_class = lambda name: str, productionClass: str = "rook-ceph-block" -> str {
    "" if name in ["local", "development"] else productionClass
}

persistence_enabled = lambda name: str, productionDefault: bool = True -> bool {
    False if name == "local" else productionDefault
}

resource_values = lambda name: str, cpuRequest: str = "100m", cpuLimit: str = "500m", memoryRequest: str = "128Mi", memoryLimit: str = "512Mi" -> any {
    {
        requests = {
            cpu = "25m" if name == "local" else "50m" if name == "development" else cpuRequest
            memory = "64Mi" if name == "local" else "128Mi" if name == "development" else memoryRequest
        }
        limits = {
            cpu = "250m" if name == "local" else cpuLimit
            memory = "256Mi" if name == "local" else memoryLimit
        }
    }
}
