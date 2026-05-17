"""
Acceptance fixture: Data Prepper standalone workload.

This is heavier than the default basic workload because it pulls a real Data
Prepper image. Run it explicitly with the kind acceptance script when needed.
"""

import manifests
import templates.dataprepper as dp

_namespace = {
    apiVersion = "v1"
    kind = "Namespace"
    metadata = {name = "idp-acceptance-dataprepper"}
}

_pipeline = "entry-pipeline:\n  source:\n    http:\n      path: /log/ingest\n  sink:\n    - stdout:\n"

_resources = dp.build_dataprepper_resources(dp.DataPrepperSpec {
    name = "data-prepper"
    namespace = "idp-acceptance-dataprepper"
    replicas = 1
    pipelineConfig = _pipeline
    resources = dp.DataPrepperResources {
        cpuRequest = "100m"
        cpuLimit = "500m"
        memoryRequest = "512Mi"
        memoryLimit = "1Gi"
    }
})

manifests.yaml_stream([_namespace] + _resources)

