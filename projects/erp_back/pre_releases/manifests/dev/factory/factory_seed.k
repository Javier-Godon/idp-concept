"""
Factory seed for erp_back dev pre-release.
Uses the framework FactorySeed to eliminate boilerplate.

Contract exports: _stack, _project_name, _git_repo_url, _manifest_path
"""

import file
import framework.factory.conventions as conventions
import framework.factory.seed as seed
import erp_back.stacks.development.stack_def
import erp_back.stacks.development.profile_def
import erp_back.tenants.vendor.tenant_def
import erp_back.sites.development.dev_cluster.site_def
import erp_back.kernel.project_def

_context = conventions.context_from_path(file.current())

_factory = seed.FactorySeed {
    project = project_def.erp_back_project
    profile = profile_def.profile
    tenant = tenant_def.tenant
    site = site_def.site
    stackSchema = stack_def.Stack
    version = _context.version
    releaseName = _context.releaseName
    manifestPath = _context.manifestPath
}

# Render contract variables for render.k
_stack = _factory.renderStack
_project_name = _factory.projectName
_git_repo_url = _factory.gitRepoUrl
_manifest_path = _factory.manifestPath
