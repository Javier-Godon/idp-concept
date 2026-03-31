"""
Factory seed for erp_back dev pre-release.
Follows the standardized factory_seed contract for render.k.

Contract exports: _stack, _project_name, _git_repo_url, _manifest_path
"""
import framework.models.gitops.gitopsstack
import erp_back.pre_releases.configurations_dev as config

_base_stack = config._stack

# Full stack for rendering (standardized contract variable)
_stack = gitopsstack.GitOpsStack {
    instanceConfigurations = _base_stack.instanceConfigurations
    k8snamespaces = _base_stack.k8snamespaces
    components = _base_stack.components
    accessories = _base_stack.accessories
}

# Standardized contract variables for render.k
_project_name = config._project.instance.name
_git_repo_url = config._pre_release_configurations_dev_cluster.gitRepoUrl
_manifest_path = "projects/erp_back/pre_releases/gitops/dev/output"
