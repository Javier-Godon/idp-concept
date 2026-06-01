## Legacy PostgreSQL Composition (pre-CNPG bridge)

The files `xrd_postgres_legacy.yaml`, `x_postgres_legacy.yaml`, and
`xr_instance_postgres_legacy.yaml` are **deprecated**. They wrap a raw
Deployment+PVC+ConfigMap in `provider-kubernetes` Objects with hardcoded
credentials.

This pattern is a bridge anti-pattern: it hides status, weakens schema
validation, and makes drift/debugging harder. See
`docs/CROSSPLANE_PATTERNS.md` section 4, Pattern 4 for the rules.

**Use the CNPG-based API instead:**
- `xrd_postgres_cnpg.yaml` — intent-level XRD with proper validation
- `x_postgres_cnpg.yaml` — CNPG-native Cluster composition
- `xr_instance_postgres_cnpg.yaml` — example XR/Claim

The legacy files are kept for migration reference only and will be removed
in a future platform release.
