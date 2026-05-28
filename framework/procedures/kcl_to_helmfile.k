"""
Helmfile generation procedure — generates helmfile.yaml from stack components and accessories.

The generated Helmfile is configurable from KCL via `hf.HelmfileRenderOptions`.
This keeps KCL as the source of truth while exposing Helmfile-native concepts:
repositories, environments, bases, helmDefaults, release defaults, per-release
overrides, extra releases, hooks, selectors, values, and secrets.

Usage:
    import framework.procedures.kcl_to_helmfile as helmfile_proc

    _helmfile = helmfile_proc.generate_helmfile_from_stack(stack, "./charts")
    manifests.yaml_stream([_helmfile])
"""
import models.modules.component
import models.modules.accessory
import custom.helmfile.helmfile as hf

_chart_base_path = lambda options: hf.HelmfileRenderOptions, fallback: str -> str {
    options.chartBasePath if options and options.chartBasePath else fallback
}

_release_patch_dict = lambda patch: hf.ReleasePatch = None -> any {
    {
        if patch != None and patch.name != Undefined:
            name = patch.name
        if patch != None and patch.namespace != Undefined:
            namespace = patch.namespace
        if patch != None and patch.chart != Undefined:
            chart = patch.chart
        if patch != None and patch.version != Undefined:
            version = patch.version
        if patch != None and patch.condition != Undefined:
            condition = patch.condition
        if patch != None and patch.installed != Undefined:
            installed = patch.installed
        if patch != None and patch.disabled != Undefined:
            disabled = patch.disabled
        if patch != None and patch.createNamespace != Undefined:
            createNamespace = patch.createNamespace
        if patch != None and patch.kubeContext != Undefined:
            kubeContext = patch.kubeContext
        if patch != None and patch.labels != Undefined:
            labels = patch.labels
        if patch != None and patch.values != Undefined:
            values = patch.values
        if patch != None and patch.secrets != Undefined:
            secrets = patch.secrets
        if patch != None and patch.needs != Undefined:
            needs = patch.needs
        if patch != None and patch.hooks != Undefined:
            hooks = patch.hooks
        if patch != None and patch.set != Undefined:
            set = patch.set
        if patch != None and patch.setString != Undefined:
            setString = patch.setString
        if patch != None and patch.setFile != Undefined:
            setFile = patch.setFile
        if patch != None and patch.missingFileHandler != Undefined:
            missingFileHandler = patch.missingFileHandler
        if patch != None and patch.verify != Undefined:
            verify = patch.verify
        if patch != None and patch.wait != Undefined:
            wait = patch.wait
        if patch != None and patch.timeout != Undefined:
            timeout = patch.timeout
        if patch != None and patch.force != Undefined:
            force = patch.force
        if patch != None and patch.atomic != Undefined:
            atomic = patch.atomic
        if patch != None and patch.cleanupOnFail != Undefined:
            cleanupOnFail = patch.cleanupOnFail
        if patch != None and patch.chartDeps != Undefined:
            chartDeps = patch.chartDeps
        if patch != None and patch.installedTemplate != Undefined:
            installedTemplate = patch.installedTemplate
        if patch != None and patch.skipDeps != Undefined:
            skipDeps = patch.skipDeps
        if patch != None and patch.recreatePods != Undefined:
            recreatePods = patch.recreatePods
        if patch != None and patch.devel != Undefined:
            devel = patch.devel
        if patch != None and patch.historyMax != Undefined:
            historyMax = patch.historyMax
        if patch != None and patch.inherit != Undefined:
            inherit = patch.inherit
        if patch != None and patch.inheritTemplate != Undefined:
            inheritTemplate = patch.inheritTemplate
        if patch != None and patch.disableValidation != Undefined:
            disableValidation = patch.disableValidation
        if patch != None and patch.disableValidationOnInstall != Undefined:
            disableValidationOnInstall = patch.disableValidationOnInstall
        if patch != None and patch.disableOpenAPIValidation != Undefined:
            disableOpenAPIValidation = patch.disableOpenAPIValidation
    }
}

_release_override = lambda options: hf.HelmfileRenderOptions, name: str -> any {
    _release_patch_dict(options.releaseOverrides[name]) if options and options.releaseOverrides and name in options.releaseOverrides else {}
}

_generated_release = lambda name: str, namespace: str, chart_base_path: str, options: hf.HelmfileRenderOptions -> any {
    {
        name = name
        namespace = options.namespace if options and options.namespace else namespace
        chart = "${chart_base_path}/${name}"
        values = ["${chart_base_path}/${name}/values.yaml"]
        createNamespace = True
        kubeContext = options.kubeContext if options else Undefined
        labels = options.labels if options else Undefined
    } | _release_patch_dict(options.releaseDefaults if options and options.releaseDefaults else None) | _release_override(options, name)
}

generate_releases_from_components_with_options = lambda components: [component.ComponentInstance], options: hf.HelmfileRenderOptions, chart_base_path: str -> [any] {
    """Generate Helmfile releases from component instances."""
    [_generated_release(comp.name, comp.namespace, chart_base_path, options) for comp in components] if components else []
}

generate_releases_from_components = lambda components: [component.ComponentInstance], chart_base_path: str -> [any] {
    generate_releases_from_components_with_options(components, hf.HelmfileRenderOptions {chartBasePath = chart_base_path}, chart_base_path)
}

generate_releases_from_accessories_with_options = lambda accessories: [accessory.AccessoryInstance], options: hf.HelmfileRenderOptions, chart_base_path: str -> [any] {
    """Generate Helmfile releases from accessory instances."""
    [_generated_release(acc.name, acc.namespace, chart_base_path, options) for acc in accessories] if accessories else []
}

generate_releases_from_accessories = lambda accessories: [accessory.AccessoryInstance], chart_base_path: str -> [any] {
    generate_releases_from_accessories_with_options(accessories, hf.HelmfileRenderOptions {chartBasePath = chart_base_path}, chart_base_path)
}

generate_helmfile_with_options = lambda components: [component.ComponentInstance], accessories: [accessory.AccessoryInstance], options: hf.HelmfileRenderOptions -> hf.Helmfile {
    """Generate a complete Helmfile from components, accessories, and render options."""
    _chart_base = _chart_base_path(options, "./charts")
    _generated_releases = []
    if options.includeGeneratedReleases:
        _generated_releases += generate_releases_from_components_with_options(components, options, _chart_base)
        _generated_releases += generate_releases_from_accessories_with_options(accessories, options, _chart_base)
    _extra_releases = options.extraReleases if options.extraReleases else []

    hf.Helmfile {
        bases = options.bases
        repositories = options.repositories
        releases = _generated_releases + _extra_releases
        environments = options.environments
        helmfiles = options.helmfiles
        defaults = options.defaults
        helmDefaults = options.helmDefaults
        kubeContext = options.kubeContext
        namespace = options.namespace
        selectors = options.selectors
        labels = options.labels
        commonLabels = options.commonLabels
        values = options.values
        secrets = options.secrets
        templates = options.templates
        hooks = options.hooks
        apiVersions = options.apiVersions
        missingFileHandler = options.missingFileHandler
        lockFilePath = options.lockFilePath
        suppressOutputLineRegex = options.suppressOutputLineRegex
    }
}

generate_helmfile = lambda components: [component.ComponentInstance], accessories: [accessory.AccessoryInstance], chart_base_path: str -> hf.Helmfile {
    generate_helmfile_with_options(components, accessories, hf.HelmfileRenderOptions {chartBasePath = chart_base_path})
}

generate_helmfile_from_stack = lambda input_stack: any, default_chart_base_path: str = "./charts" -> hf.Helmfile {
    _options = hf.HelmfileRenderOptions {chartBasePath = default_chart_base_path} | (input_stack.helmfile or {})
    generate_helmfile_with_options(input_stack.components, input_stack.accessories, _options)
}
