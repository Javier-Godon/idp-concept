"""
Helmfile generation procedure — generates helmfile.yaml from stack components and accessories.
Phase 2 implementation: auto-generates Helmfile releases pointing to per-component chart directories.

Usage:
    import framework.procedures.kcl_to_helmfile as helmfile_proc

    _helmfile = helmfile_proc.generate_helmfile(stack.components, stack.accessories, "./charts")
    manifests.yaml_stream([_helmfile])
"""
import models.modules.component
import models.modules.accessory
import custom.helmfile.helmfile as hf

generate_releases_from_components = lambda components: [component.ComponentInstance], chart_base_path: str -> [hf.Release] {
    """Generate Helmfile releases from component instances."""
    [
        hf.Release {
            name = comp.name
            namespace = comp.namespace
            chart = "${chart_base_path}/${comp.name}"
            values = ["${chart_base_path}/${comp.name}/values.yaml"]
            createNamespace = True
        }
        for comp in components
    ] if components else []
}

generate_releases_from_accessories = lambda accessories: [accessory.AccessoryInstance], chart_base_path: str -> [hf.Release] {
    """Generate Helmfile releases from accessory instances."""
    [
        hf.Release {
            name = acc.name
            namespace = acc.namespace
            chart = "${chart_base_path}/${acc.name}"
            values = ["${chart_base_path}/${acc.name}/values.yaml"]
            createNamespace = True
        }
        for acc in accessories
    ] if accessories else []
}

generate_helmfile = lambda components: [component.ComponentInstance], accessories: [accessory.AccessoryInstance], chart_base_path: str -> hf.Helmfile {
    """Generate a complete Helmfile from components and accessories."""
    _comp_releases = generate_releases_from_components(components, chart_base_path)
    _acc_releases = generate_releases_from_accessories(accessories, chart_base_path)

    hf.Helmfile {
        releases = _comp_releases + _acc_releases
    }
}
