import k8s.api.core.v1 as core
import k8s.api.apps.v1 as apps

app_test: apps.Deployment {
    apiVersion = "apps/v1"
    kind = "Deployment"
    metadata = {
        name = "name 2"
        namespace = "namespace 2"
    }
}
