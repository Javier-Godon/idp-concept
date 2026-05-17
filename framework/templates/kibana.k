"""Backward-compatible Kibana template wrapper.

New code should prefer explicit versioned imports such as:
`import templates.elastic.v7_10_2.kibana as kibana` or
`import templates.elastic.v9_4_1.kibana as kibana`.
"""

import templates.elastic.v7_10_2.kibana as kibana_v7_wrapper

KibanaResources = kibana_v7_wrapper.KibanaResources
KibanaSpec = kibana_v7_wrapper.KibanaSpec
KibanaModule = kibana_v7_wrapper.KibanaModule
build_kibana_config = kibana_v7_wrapper.build_kibana_config
build_kibana_configmap = kibana_v7_wrapper.build_kibana_configmap
build_kibana_deployment = kibana_v7_wrapper.build_kibana_deployment
build_kibana_service = kibana_v7_wrapper.build_kibana_service
build_kibana_pdb = kibana_v7_wrapper.build_kibana_pdb
build_kibana_resources = kibana_v7_wrapper.build_kibana_resources
