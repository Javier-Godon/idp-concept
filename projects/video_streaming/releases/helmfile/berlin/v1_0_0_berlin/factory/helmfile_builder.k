import framework.custom.helmfile.helmfile
import video_streaming.releases.helmfile.berlin.v1_0_0_berlin.factory.factory_seed

helmfile.Helmfile {
    helmfiles: [
        {
            path: "./apps/my-chart/helmfile.yaml"
        }
    ]
    releases: [
        {
            name: "my-app"
            namespace: "default"
            chart: "./charts/my-chart"
            version: "0.1.0"
            values: ["./charts/my-chart/values.yaml"]
        }
    ]
}
