"""
Factory seed for erp_back v1.0.0 production release.
Uses the framework FactorySeed to eliminate boilerplate.

Contract exports: _stack, _project_name, _git_repo_url, _manifest_path
"""

import file
import framework.factory.conventions as conventions
import framework.factory.seed as seed
import erp_back.stacks.versioned.v1_0_0.stack_def as stack
import erp_back.stacks.versioned.v1_0_0.profile_def
import erp_back.tenants.acme_corp.tenant_def
import erp_back.sites.production.default.site_def
import erp_back.kernel.project_def

_context = conventions.context_from_path(file.current())

_factory = seed.FactorySeed {
    project = project_def.erp_back_project
    profile = profile_def.profile
    tenant = tenant_def.tenant
    site = site_def.site
    stackSchema = stack.Stack
    version = _context.version
    releaseName = _context.releaseName
    manifestPath = _context.manifestPath
}

# Render contract variables for render.k
_stack = _factory.renderStack
_project_name = _factory.projectName
_git_repo_url = _factory.gitRepoUrl
_manifest_path = _factory.manifestPath
