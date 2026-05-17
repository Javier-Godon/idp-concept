"""Backward-compatible Ceph template wrapper.

The implementation lives in `templates.ceph.main`. Keep this root module thin so
existing imports such as `import templates.ceph as ceph` continue to work
without duplicating template implementation code.
"""

import templates.ceph.main as ceph_compat

CephSpec = ceph_compat.CephSpec
build_ceph_block_pool = ceph_compat.build_ceph_block_pool
build_ceph_storage_class = ceph_compat.build_ceph_storage_class
build_ceph_cluster = ceph_compat.build_ceph_cluster
build_ceph_release = ceph_compat.build_ceph_release
build_ceph_resources = ceph_compat.build_ceph_resources
CephModule = ceph_compat.CephModule
