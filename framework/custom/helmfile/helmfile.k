schema Helmfile:
    repositories?: [Repository]
    releases?: [Release]
    environments?: {str: Environment}
    helmfiles?: [HelmfilePath]
    defaults?: ReleaseDefaults
    baseChartPath?: str
    kubeContext?: str
    namespace?: str
    selectors?: [Selector]
    labels?: {str: str}
    values?: [any]
    secrets?: [str]
    templates?: {str: str}
    hooks?: Hooks
    _kcl_annotation?: str  # For KCL conditional expressions if needed

schema Repository:
    name: str
    url: str
    username?: str
    password?: str
    certFile?: str
    keyFile?: str
    caFile?: str
    insecureSkipTLSverify?: bool

schema Release:
    name: str
    namespace?: str
    chart: str
    version?: str
    condition?: str
    installed?: bool
    disabled?: bool
    createNamespace?: bool
    kubeContext?: str
    labels?: {str: str}
    values?: [any]  # YAML object or string path
    secrets?: [str]
    needs?: [str]
    hooks?: Hooks
    set?: [SetValue]
    setString?: [SetValue]
    setFile?: [SetValue]
    missingFileHandler?: str
    verify?: bool
    wait?: bool
    timeout?: int
    force?: bool
    atomic?: bool
    cleanupOnFail?: bool
    chartDeps?: bool
    installedTemplate?: str
    skipDeps?: bool

schema SetValue:
    name: str
    value: any

schema Environment:
    values?: [any]
    secrets?: [str]
    missingFileHandler?: str

schema HelmfilePath:
    path: str
    selectors?: [Selector]
    environment?: str
    values?: [any]

schema ReleaseDefaults:
    namespace?: str
    kubeContext?: str
    chart?: str
    version?: str
    installed?: bool
    wait?: bool
    timeout?: int
    force?: bool
    atomic?: bool
    cleanupOnFail?: bool

schema Selector:
    name: str
    value: str

schema Hooks:
    preApply?: [Hook]
    postApply?: [Hook]
    preDelete?: [Hook]
    postDelete?: [Hook]
    preSync?: [Hook]
    postSync?: [Hook]

schema Hook:
    command: str
    args?: [str]
    showOutput?: bool
