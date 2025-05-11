schema Chart:
    apiVersion: str  # 'v1' or 'v2'
    name: str
    description?: str
    type?: str = "application"  # optional, default is 'application'
    version: str
    appVersion?: str
    kubeVersion?: str
    keywords?: [str]
    home?: str
    sources?: [str]
    maintainers?: [Maintainer]
    icon?: str
    dependencies?: [Dependency]
    annotations?: {str: str}
    condition?: str
    tags?: [str]

schema Maintainer:
    name: str
    email?: str
    url?: str

schema Dependency:
    name: str
    version: str
    repository: str
    alias?: str
    condition?: str
    tags?: [str]
    enabled?: bool
    importValues?: [str] | [ImportValueMap]

schema ImportValueMap:
    child: str
    parent: str

schema HelmChartValues:
    replicaCount?: int
    image?: Image
    service?: Service
    ingress?: Ingress
    resources?: Resources
    nodeSelector?: {str: str}
    tolerations?: [any]
    affinity?: any

schema Image:
    repository: str
    tag?: str
    pullPolicy?: str

schema Service:
    type: str
    port: int

schema Ingress:
    enabled: bool
    className?: str
    annotations?: {str: str}
    hosts?: [Host]
    tls?: [TLS]

schema Host:
    host: str
    paths: [Path]

schema Path:
    path: str
    pathType: str

schema TLS:
    hosts: [str]
    secretName: str

schema Resources:
    limits?: ResourceQuantity
    requests?: ResourceQuantity

schema ResourceQuantity:
    cpu?: str
    memory?: str
