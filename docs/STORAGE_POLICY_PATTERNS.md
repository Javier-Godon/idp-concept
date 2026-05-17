# Storage Policy Patterns

Use this note as a copy-paste baseline for site-level storage policy in new projects.

## Recommended Environment Pattern

| Environment | storageClassName | useLocalPersistentVolumes | Notes |
|---|---|---|---|
| local/dev (single-node) | `local-path` | `True` | Use host-backed PVs for fast local iteration |
| staging | `rook-ceph-block` | `False` | Ceph dynamic provisioning via PVC |
| production | `rook-ceph-block` | `False` | Ceph dynamic provisioning with HA control plane |

## Optional Simpler Pattern with Longhorn

If Ceph is not available and you want a simpler distributed storage setup:

| Environment | storageClassName | useLocalPersistentVolumes | Notes |
|---|---|---|---|
| local/dev | `local-path` | `True` | Same local workflow |
| staging | `longhorn` | `False` | Longhorn dynamic provisioning |
| production | `longhorn` | `False` | Longhorn dynamic provisioning |

## Example Site Config Snippets

```kcl
# dev site
_site_cfg = ProjectConfigurations {
    storageClassName = "local-path"
    useLocalPersistentVolumes = True
}
```

```kcl
# stg/prod site (Ceph)
_site_cfg = ProjectConfigurations {
    storageClassName = "rook-ceph-block"
    useLocalPersistentVolumes = False
}
```

```kcl
# stg/prod site (Longhorn alternative)
_site_cfg = ProjectConfigurations {
    storageClassName = "longhorn"
    useLocalPersistentVolumes = False
}
```

## Provisioning Templates

- Ceph stack: `framework/templates/ceph.k`
- Longhorn stack: `framework/templates/longhorn.k`

Use one storage provider per cluster unless you have a clear multi-storage strategy.

