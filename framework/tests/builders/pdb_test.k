import builders.pdb as pdb

# --- Test: PDB with minAvailable ---
test_build_pdb_min_available = lambda {
    _spec = pdb.PDBSpec {
        name = "my-app-pdb"
        namespace = "apps"
        matchLabels = {app = "my-app"}
        minAvailable = 1
    }
    _result = pdb.build_pdb(_spec)
    assert _result.apiVersion == "policy/v1"
    assert _result.kind == "PodDisruptionBudget"
    assert _result.metadata.name == "my-app-pdb"
    assert _result.metadata.namespace == "apps"
    assert _result.spec.selector.matchLabels.app == "my-app"
    assert _result.spec.minAvailable == 1
    assert _result.spec.maxUnavailable is Undefined
}

# --- Test: PDB with maxUnavailable ---
test_build_pdb_max_unavailable = lambda {
    _spec = pdb.PDBSpec {
        name = "api-pdb"
        namespace = "apps"
        matchLabels = {app = "api"}
        maxUnavailable = 1
    }
    _result = pdb.build_pdb(_spec)
    assert _result.spec.maxUnavailable == 1
    assert _result.spec.minAvailable is Undefined
}

# --- Test: PDB with percentage string ---
test_build_pdb_percentage = lambda {
    _spec = pdb.PDBSpec {
        name = "web-pdb"
        namespace = "web"
        matchLabels = {app = "web"}
        minAvailable = "50%"
    }
    _result = pdb.build_pdb(_spec)
    assert _result.spec.minAvailable == "50%"
}

# --- Test: PDB with both (maxUnavailable takes precedence) ---
test_build_pdb_both_fields = lambda {
    _spec = pdb.PDBSpec {
        name = "both-pdb"
        namespace = "apps"
        matchLabels = {app = "test"}
        minAvailable = 2
        maxUnavailable = 1
    }
    _result = pdb.build_pdb(_spec)
    assert _result.spec.minAvailable == 2
    assert _result.spec.maxUnavailable == 1
}
