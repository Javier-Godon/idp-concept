"""Backward-compatible Opensearch template wrapper.

The implementation lives in `templates.opensearch.main`. Keep this root module thin so
existing imports such as `import templates.opensearch as opensearch` continue to work
without duplicating template implementation code.
"""

import templates.opensearch.main as opensearch_compat

NodePoolSpec = opensearch_compat.NodePoolSpec
DashboardsSpec = opensearch_compat.DashboardsSpec
OpenSearchClusterSpec = opensearch_compat.OpenSearchClusterSpec
build_opensearch_cluster = opensearch_compat.build_opensearch_cluster
OpenSearchClusterModule = opensearch_compat.OpenSearchClusterModule
