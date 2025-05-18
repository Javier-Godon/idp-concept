import k8s.api.core.v1 as core
import k8s.api.apps.v1 as apps
import schema_test2 as input

import schema_test
import schema_test2

# app_test: apps.Deployment {
#     apiVersion = "apps/v1"
#     kind = "Deployment"
#     metadata = {
#         name = "name 2"
#         namespace = "namespace 2"
#     }
# }
# output = input.app_test.metadata.name
# output2 = input.app_test.spec.replicas
schema_test2.app_test
# app_test.spec.replicas
