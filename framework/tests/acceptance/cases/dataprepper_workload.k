"""
Acceptance fixture: Data Prepper standalone workload.

Uses the DataPrepperModule render path. The kind runner keeps this case
dry-run-only because its probes require the real Data Prepper runtime.
"""

import ._helpers as h
import templates.opensearch.dataprepper.v2_10_2.dataprepper as dp

_pipeline = "entry-pipeline:\n  source:\n    http:\n      path: /log/ingest\n  sink:\n    - stdout:\n"

_module = dp.DataPrepperModule {
    name = "data-prepper"
    namespace = "idp-acceptance-dataprepper"
    configurations = {}
    asset = {version = "2.10.2"}
    dependsOn = []
    replicas = 1
    pipelineConfig = _pipeline
    resources = dp.DataPrepperResources {
        cpuRequest = "100m"
        cpuLimit = "500m"
        memoryRequest = "512Mi"
        memoryLimit = "1Gi"
    }
}.instance

h.render_component("idp-acceptance-dataprepper", _module)

