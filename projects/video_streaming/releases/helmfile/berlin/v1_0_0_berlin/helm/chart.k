import framework.custom.helm.helm
import manifests

_chart_file = helm.Chart {
    apiVersion: "v2"
    name: "my-chart"
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
