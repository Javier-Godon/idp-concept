"""
OpenSearch Cluster Template — OpenSearch Kubernetes Operator pattern.
Generates: OpenSearchCluster CRD manifest.

CRD API: opensearch.org/v1
Operator: opensearch-k8s-operator (https://github.com/opensearch-project/opensearch-k8s-operator)

Usage:
    import framework.templates.opensearch as os

    schema MyOpenSearch(os.OpenSearchClusterModule):
        clusterName = "my-os"
        version = "2.17.0"
        nodePools = [os.NodePoolSpec {
            component = "nodes"
            replicas = 3
            diskSize = "30Gi"
            roles = ["cluster_manager", "data"]
        }]
        dashboards = os.DashboardsSpec { enable = True, replicas = 1, version = "2.17.0" }
"""
import models.modules.accessory as accessory
import builders.leader as leader

schema NodePoolSpec:
    """Specification for an OpenSearch node pool."""
    component: str
    replicas: int = 3
    diskSize: str
    roles: [str]
    resources?: any
    jvm?: str
    labels?: {str:str}
    annotations?: {str:str}

    check:
        replicas >= 1, "replicas must be >= 1"
        len(diskSize) > 0, "diskSize must not be empty"
        len(roles) > 0, "roles must not be empty"

schema DashboardsSpec:
    """Specification for OpenSearch Dashboards."""
    enable: bool = True
    replicas: int = 1
    version?: str
    resources?: any
    basePath?: str

schema OpenSearchClusterSpec:
    """Specification for an OpenSearchCluster resource."""
    name: str
    namespace: str
    version: str
    nodePools: [NodePoolSpec]
    dashboards?: DashboardsSpec
    additionalConfig?: {str:str}
    monitoring?: bool
    pluginsList?: [str]
    securityDisabled?: bool

    check:
        len(version) > 0, "version must not be empty"
        len(nodePools) > 0, "nodePools must not be empty"

build_opensearch_cluster = lambda spec: OpenSearchClusterSpec -> any {
    _additional_config = {if spec.additionalConfig: additionalConfig = spec.additionalConfig}
    _monitoring = {if spec.monitoring: monitoring = {enable = True}}
    _plugins = {if spec.pluginsList: pluginsList = spec.pluginsList}
    _security = {if spec.securityDisabled: security = {disable = True}}
    _dashboards = {
        if spec.dashboards:
            dashboards = {
                enable = spec.dashboards.enable
                replicas = spec.dashboards.replicas
                if spec.dashboards.version:
                    version = spec.dashboards.version
                if spec.dashboards.resources:
                    resources = spec.dashboards.resources
                if spec.dashboards.basePath:
                    basePath = spec.dashboards.basePath
            }
    }
    _node_pools = [{
        component = np.component
        replicas = np.replicas
        diskSize = np.diskSize
        roles = np.roles
        if np.resources:
            resources = np.resources
        if np.jvm:
            jvm = np.jvm
        if np.labels:
            labels = np.labels
        if np.annotations:
            annotations = np.annotations
    } for np in spec.nodePools]
    {
        apiVersion = "opensearch.org/v1"
        kind = "OpenSearchCluster"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            general = {
                serviceName = spec.name
                version = spec.version
            } | _additional_config | _monitoring | _plugins
            nodePools = _node_pools
        } | _dashboards | _security
    }
}

schema OpenSearchClusterModule(accessory.Accessory):
    """High-level template for OpenSearch clusters via the k8s operator.

    Extends Accessory with kind="CRD" and generates OpenSearchCluster CRD manifest.
    """
    kind = "CRD"

    # User-configurable
    clusterName: str
    version: str
    nodePools: [NodePoolSpec]
    dashboards?: DashboardsSpec
    additionalConfig?: {str:str}
    monitoring?: bool
    pluginsList?: [str]
    securityDisabled?: bool

    # Auto-computed
    leaders = [leader.build_accessory_leader(clusterName, namespace, "OpenSearchCluster", "opensearch.org/v1")]

    _cluster_manifest = build_opensearch_cluster(OpenSearchClusterSpec {
        name = clusterName
        namespace = namespace
        version = version
        nodePools = nodePools
        dashboards = dashboards
        additionalConfig = additionalConfig
        monitoring = monitoring
        pluginsList = pluginsList
        securityDisabled = securityDisabled
    })

    manifests = [_cluster_manifest]
