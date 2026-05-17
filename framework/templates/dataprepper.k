"""Backward-compatible Dataprepper template wrapper.

The implementation lives in `templates.opensearch.dataprepper.v2_10_2.dataprepper`. Keep this root module thin so
existing imports such as `import templates.dataprepper as dataprepper` continue to work
without duplicating template implementation code.
"""

import templates.opensearch.dataprepper.v2_10_2.dataprepper as dataprepper_compat

DataPrepperResources = dataprepper_compat.DataPrepperResources
DataPrepperSpec = dataprepper_compat.DataPrepperSpec
build_dataprepper_configmap = dataprepper_compat.build_dataprepper_configmap
build_dataprepper_deployment = dataprepper_compat.build_dataprepper_deployment
build_dataprepper_service = dataprepper_compat.build_dataprepper_service
build_dataprepper_pdb = dataprepper_compat.build_dataprepper_pdb
build_dataprepper_resources = dataprepper_compat.build_dataprepper_resources
DataPrepperModule = dataprepper_compat.DataPrepperModule
