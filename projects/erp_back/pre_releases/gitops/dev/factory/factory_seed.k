"""
Factory seed for erp_back development pre-release.
Sets up the release context for builders.
"""
import framework.models.release
import framework.models.gitops.gitopsstack
import framework.procedures.helper
import erp_back.pre_releases.configurations_dev as core_configurations_dev

_release_configurations = core_configurations_dev._pre_release_configurations_dev_cluster
_stack = core_configurations_dev._stack

# Full stack for complete rendering
_erp_back_development_dev_cluster_stack = gitopsstack.GitOpsStack {
    instanceConfigurations = _stack.instanceConfigurations
    k8snamespaces = _stack.k8snamespaces
    components = _stack.components
    accessories = _stack.accessories
}

# Single component extract for GitOps per-component rendering
_erp_api_stack = gitopsstack.GitOpsStack {
    instanceConfigurations = _stack.instanceConfigurations
    k8snamespaces = helper.extract_models_by_name_from_list(_stack.k8snamespaces, "erp-apps")
    components = helper.extract_models_by_name_from_list(_stack.components, "erp-api")
}

_pre_release_development_dev_cluster = release.Release {
    name = "pre_release_development_dev_cluster"
    version = "1.0.0"
    project = core_configurations_dev._project.instance
    tenant = core_configurations_dev._tenant.instance
    site = core_configurations_dev._site.instance
    profile = core_configurations_dev._profile.instance
    stack = _stack
}
