# import framework.custom.helm.helm
# import framework.custom.helmfile.helmfile
# _element_to_render = option("element","")
# _concrete: helm.Chart | helmfile.Helmfile = {
#     apiVersion: "v2"
#     name: "my-chart"
#     version: "0.1.0"
#     appVersion: "1.0.0"
# }
# if _element_to_render == "CHART" or _element_to_render == "chart":
#     _concrete = helm.Chart {
#         apiVersion: "v2"
#         name: "my-chart"
#         version: "0.1.0"
#         appVersion: "1.0.0"
#     }
# if _element_to_render == "HELMFILE" or _element_to_render == "helmfile":
#     _concrete = helmfile.Helmfile {
#         helmfiles: [
#             {
#                 path: "./apps/my-chart/helmfile.yaml"
#             }
#         ]
#         releases: [
#             {
#                 name: "my-app"
#                 namespace: "default"
#                 chart: "./charts/my-chart"
#                 version: "0.1.0"
#                 values: ["./charts/my-chart/values.yaml"]
#             }
#         ]
#     }
# concrete = _concrete
import video_streaming.pre_releases.gitops.kafka_video_consumer_mongodb_python.dev.factory.factory_seed
import framework.custom.argocd.models.v1alpha1.argoproj_io_v1alpha1_application as application

_application_name = factory_seed._kafka_video_consumer_mongodb_python_development_dev_cluster_stack.components[0].name
_project_name = factory_seed._pre_release_development_dev_cluster.project.name

application.Application {
    metadata = {
        name = _application_name
        namespace = "argocd"
    }
    spec = {
        project = _project_name
        source = {
            repoURL = "https://github.com/Javier-Godon/idp-concept"
            targetRevision = "HEAD"
            path = "projects/video_streaming/pre_releases/gitops/${_application_name}/dev/output/kubernetes_manifests.yaml"
        }
        destination = {
            server = "http://kubernetes.default.svc"
            namespace = "apps"
        }
    }
}
