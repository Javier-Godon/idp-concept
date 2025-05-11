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
import framework.procedures.kcl_to_yaml
import video_streaming.pre_releases.gitops.kafka_video_consumer_mongodb_python.dev.factory.factory_seed

kcl_to_yaml.yaml_stream_stack(factory_seed._kafka_video_consumer_mongodb_python_development_dev_cluster_stack)
