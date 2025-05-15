import framework.custom.helm.helm
import video_streaming.releases.helmfile.berlin.v1_0_0_berlin.factory.factory_seed
import manifests

_chart_name = option("chart")

_chart_file = helm.Chart {
    apiVersion: "v2"
    name: _chart_name
    description: "A Helm chart for Kubernetes"
    type: "application"
    version: "0.1.0"
    appVersion: "1.0.0"
    keywords: ["example", "kcl"]
    maintainers: [
        {
            name: "Javier Godon"
            email: "you@example.com"
        }
    ]
}

manifests.yaml_stream([_chart_file])
