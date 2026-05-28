import templates.footprints.v1_0_0.footprint as fp

test_footprint_replicas = lambda {
    assert fp.replicas("local") == 1
    assert fp.replicas("staging") == 2
    assert fp.replicas("production") == 3
}

test_footprint_storage_and_class = lambda {
    assert fp.storage_size("local") == "1Gi"
    assert fp.storage_size("production") == "50Gi"
    assert fp.storage_class("local") == ""
    assert fp.storage_class("production") == "rook-ceph-block"
}
