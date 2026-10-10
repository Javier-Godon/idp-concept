"""
Factory seed for platform dev pre-release.
Contract exports: _stack, _project_name, _git_repo_url, _manifest_path
"""

import file
import framework.factory.conventions as conventions
import framework.factory.seed as seed
import platform.stacks.development.stack_def
import platform.stacks.development.profile_def
import platform.tenants.vendor.tenant_def
import platform.sites.development.dev_cluster.site_def
import platform.kernel.project_def

_context = conventions.context_from_path(file.current())

_factory = seed.FactorySeed {
    project = project_def.platform_project
    profile = profile_def.profile
    tenant = tenant_def.tenant
    site = site_def.site
    stackSchema = stack_def.Stack
    version = _context.version
    releaseName = _context.releaseName
    manifestPath = _context.manifestPath
}

_stack = _factory.renderStack
_project_name = _factory.projectName
_git_repo_url = _factory.gitRepoUrl
_manifest_path = _factory.manifestPath
