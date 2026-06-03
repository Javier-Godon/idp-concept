"""
Acceptance fixture: Crossplane advanced lifecycle with stateful multi-tier deployment.

This fixture exercises more sophisticated Crossplane lifecycle scenarios:
  - Multi-tier stack with persistent state (DB → cache → app)
  - Cross-component dependencies with ordering
  - Stateful workload reconciliation and readiness detection
  - Resource cleanup with correct ordering
  - Governance metadata propagation through full stack

Validates:
- Dependency sequencer correctly orders composition
- Persistent volumes are correctly bound before dependent services start
- Cleanup is deterministic and leaves no orphans
- All governance metadata is preserved through reconciliation

This is a **runtime-only** fixture for acceptance testing.
Use in: scripts/acceptance_runtime.sh with --runtime-profile lifecycle (or api-lifecycle for extended checks)
"""

import manifests
import templates.database.v1_0_0.database as database
import templates.webapp.v1_0_0.webapp as webapp
import models.manifests.renderstack as rs
import models.metadata as meta
import procedures.kcl_to_crossplane as xp_proc

_namespace = "idp-acceptance-xp-stateful"

# Tier 1: Persistent database with local storage
_database = database.SingleDatabaseModule {
    name = "acceptance-xp-primary-db"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    port = 5432
    dataPath = "/data"
    storageSize = "512Mi"
    storageClassName = "acceptance-local-storage"
    createLocalPersistentVolume = True
    storageHostPath = "/tmp/idp-acceptance-xp-primary"
    dependsOn = []
}.instance

# Tier 2: Cache service (depends on database for health checks)
_cache = webapp.WebAppModule {
    name = "acceptance-xp-cache"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    port = 6379
    replicas = 1
    configData = {
        "cache.conf" = "bind 0.0.0.0\nport 6379\n"
    }
    env = [
        {name = "DB_CHECK_ENABLED", value = "true"}
        {name = "DB_HOST", value = "acceptance-xp-primary-db"}
        {name = "DB_PORT", value = "5432"}
    ]
    dependsOn = [_database]
}.instance

# Tier 3: Application layer (depends on both cache and database)
_application = webapp.WebAppModule {
    name = "acceptance-xp-app"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    port = 8080
    replicas = 2
    configData = {
        "application.yaml" = """
server:
  port: 8080
  workers: 4
database:
  host: acceptance-xp-primary-db
  port: 5432
cache:
  host: acceptance-xp-cache
  port: 6379
"""
    }
    env = [
        {name = "APP_ENV", value = "acceptance"}
        {name = "DB_HOST", value = "acceptance-xp-primary-db"}
        {name = "CACHE_HOST", value = "acceptance-xp-cache"}
        {name = "CACHE_PORT", value = "6379"}
        {name = "LOG_LEVEL", value = "info"}
    ]
    dependsOn = [_database, _cache]
}.instance

# Build complete infrastructure stack with governance metadata
_stack = rs.RenderStack {
    instanceConfigurations = {}
    components = [_cache, _application]
    accessories = [_database]
    k8snamespaces = []
    metadata = meta.Metadata {
        owner = "platform-team"
        team = "infrastructure"
        lifecycle = "acceptance"
        tier = "testing"
        criticality = "medium"
        support = "platform-on-call"
        runbook = "https://wiki.internal/acceptance-xp-stateful"
        dataClassification = "internal"
        costCenter = "engineering"
    }
}

# Generate Crossplane composition from the stack
# This exercises the full sequencing logic with complex dependencies
_crossplane = xp_proc.generate_crossplane_from_render_stack(_stack, "idp-concept", "1.0.0")

# Emit Crossplane resources for reconciliation testing
# Order: prerequisites → XRD → Composition → XR
# The sequencer in Composition will enforce dependency ordering
manifests.yaml_stream([
    _crossplane.xrd,
    _crossplane.composition,
    _crossplane.xr,
] + (_crossplane.prerequisites if _crossplane.prerequisites else []))



