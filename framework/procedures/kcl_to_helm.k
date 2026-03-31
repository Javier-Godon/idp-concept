"""
Helm chart generation — produces Chart.yaml + values.yaml from stack structures.
Supports both raw manifest extraction (legacy) and parameterized output (Phase 2 Strategy B).
"""
import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace
import models.stack as stack
import manifests
import procedures.helm_values as hv

# === Legacy: raw manifest extraction (used by ArgoCD/YAML output) ===

generate_helm_components_templates_from_stack = lambda input_stack: stack.Stack -> any {
    modules = get_helm_components(input_stack.components)
    manifests.yaml_stream(modules)
}

get_helm_components = lambda components: [component.ComponentInstance] -> [any] {
    [element.manifests for element in components] if components else []
}

# === Phase 2: Parameterized chart data (Strategy B) ===

generate_chart_data = lambda module_instance: any -> {str:} {
    """Generate chart + values data for a single component or accessory."""
    {
        chart = hv.generate_chart(module_instance, module_instance.asset.version)
        values = hv.extract_helm_values(module_instance)
    }
}

generate_charts_from_stack = lambda input_stack: any -> [{str:}] {
    """Generate chart data for all components and accessories in a stack."""
    _comps = input_stack.components if input_stack.components else []
    _accs = input_stack.accessories if input_stack.accessories else []
    _comp_charts = [generate_chart_data(comp) for comp in _comps]
    _acc_charts = [generate_chart_data(acc) for acc in _accs]
    _comp_charts + _acc_charts
}