"""
Acceptance fixture: Crossplane lifecycle validation with full reconciliation.

This fixture exercises the complete Crossplane V2 lifecycle:
  1. Apply XRD (CompositeResourceDefinition)
  2. Apply prerequisites (Providers, Functions)
  3. Apply Composition (Pipeline)
  4. Apply XR (CompositeResource claim instance)
  5. Wait for Ready condition
  6. Delete resources
  7. Verify cleanup

Validates:
- XRD is idempotent and properly versioned
- Composition pipeline stages (patch-and-transform → sequencer → auto-ready)
- XR instantiation and readiness detection
- Resource ordering via sequencer rules
- Provider/Function prerequisite acknowledgment
- Cleanup leaves no orphaned resources

This is a **runtime-only** fixture (not suitable for dry-run).
Use in: scripts/acceptance_runtime.sh with --runtime-profile lifecycle
"""

import manifests
import templates.webapp.v1_0_0.webapp as webapp
import templates.database.v1_0_0.database as database
import models.manifests.renderstack as rs
import models.metadata as meta
import procedures.kcl_to_crossplane as xp_proc

_namespace = "idp-acceptance-crossplane-lifecycle"

# Simple database accessory for persistent state testing
_db = database.SingleDatabaseModule {
    name = "acceptance-crossplane-db"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    port = 5432
    dataPath = "/data"
    storageSize = "256Mi"
    storageClassName = "acceptance-local-storage"
    createLocalPersistentVolume = True
    storageHostPath = "/tmp/idp-crossplane-acceptance"
    dependsOn = []
}.instance

# Simple web app that depends on the database
_app = webapp.WebAppModule {
    name = "acceptance-crossplane-app"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "database: acceptance-crossplane-db:5432\n"}
    env = [{name = "DB_HOST", value = "acceptance-crossplane-db"}]
    dependsOn = [_db]
}.instance

_stack = rs.RenderStack {
    instanceConfigurations = {}
    components = [_app]
    accessories = [_db]
    k8snamespaces = []
    metadata = meta.Metadata {
        owner = "platform-team"
        team = "platform"
        lifecycle = "testing"
        tier = "experimental"
        runbook = "https://wiki/crossplane-lifecycle-test"
    }
}

# Generate full Crossplane stack
_crossplane = xp_proc.generate_crossplane_from_render_stack(_stack, "idp-concept", "1.0.0")

# Emit all four required Crossplane resources: xrd, composition, xr, prerequisites
manifests.yaml_stream([
    _crossplane.xrd,
    _crossplane.composition,
    _crossplane.xr,
] + (_crossplane.prerequisites if _crossplane.prerequisites else []))


