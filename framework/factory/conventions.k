"""
Folder convention helpers for project definitions and factories.

Supported layouts:
- projects/<project>/stacks/development/profile_def.k
- projects/<project>/stacks/versioned/<version_id>/profile_def.k
- projects/<project>/tenants/<tenant_id>/tenant_def.k
- projects/<project>/sites/<environment>/<site_id>/site_def.k
- projects/<project>/pre_releases/manifests/<environment>/factory/factory_seed.k
- projects/<project>/releases/<release_id>/factory/factory_seed.k

Pass `file.current()` from the caller so values are derived from the caller's
folder, not from this framework module.
"""

import file
import models.metadata as meta
import models.profile as profile_model
import models.site as site_model
import models.tenant as tenant_model

schema ConventionContext:
    projectSlug?: str
    releaseKind?: str
    releaseID?: str
    environment?: str
    version?: str
    releaseName?: str
    manifestPath?: str
    profileName?: str
    tenantID?: str
    siteName?: str

schema ProfileSpec:
    currentFile: str
    configurations: any
    name?: str
    metadata?: meta.Metadata

schema TenantSpec:
    currentFile: str
    configurations: any
    name?: str
    description?: str = ""
    metadata?: meta.Metadata

schema SiteSpec:
    currentFile: str
    tenant: tenant_model.Tenant
    configurations: any
    name?: str
    metadata?: meta.Metadata

_tail_after = lambda value: str, marker: str -> str {
    _parts = value.split(marker)
    _parts[1] if len(_parts) > 1 else ""
}

_first_segment_after = lambda value: str, marker: str -> str {
    _tail = _tail_after(value, marker)
    _tail.split("/")[0] if _tail else ""
}

_join_path = lambda parts: [str] -> str {
    "/".join([part for part in parts if part])
}

_version_from_id = lambda version_id: str -> str {
    _parts = version_id.split("_")
    ".".join([_parts[0].replace("v", "")] + _parts[1:3]) if len(_parts) >= 3 else version_id.replace("v", "")
}

_environment_from_release_id = lambda release_id: str -> str {
    _parts = release_id.split("_")
    "_".join(_parts[3:]) if len(_parts) > 3 else ""
}

slug_to_display_name = lambda slug: str -> str {
    slug.replace("_", " ").replace("-", " ").title()
}

project_slug_from_path = lambda current_file: str -> str {
    _first_segment_after(current_file, "/projects/")
}

project_root_from_path = lambda current_file: str -> str {
    _parts = current_file.split("/projects/")
    _prefix = _parts[0] if len(_parts) > 1 else ""
    _project_slug = project_slug_from_path(current_file)
    "${_prefix}/projects/${_project_slug}" if _prefix and _project_slug else ""
}

project_version_from_path = lambda current_file: str -> str {
    _project_root = project_root_from_path(current_file)
    _mod_path = "${_project_root}/kcl.mod" if _project_root else ""
    _content = file.read(_mod_path) if _mod_path and file.exists(_mod_path) else ""
    _version_lines = [line for line in _content.split("\n") if line.strip().startswith("version")]
    _version_lines[0].split("=")[1].strip().replace('"', "").replace("'", "") if _version_lines else ""
}

profile_name_from_path = lambda current_file: str -> str {
    _versioned = _first_segment_after(current_file, "/stacks/versioned/")
    _stack = _first_segment_after(current_file, "/stacks/")
    _versioned if _versioned else _stack
}

tenant_id_from_path = lambda current_file: str -> str {
    _first_segment_after(current_file, "/tenants/")
}

site_name_from_path = lambda current_file: str -> str {
    _tail = _tail_after(current_file, "/sites/")
    _parts = _tail.split("/") if _tail else []
    _environment = _parts[0] if len(_parts) > 0 else ""
    _site = _parts[1] if len(_parts) > 1 else ""
    _environment if _site == "default" else _site
}

context_from_path = lambda current_file: str -> ConventionContext {
    _project_slug = project_slug_from_path(current_file)
    _pre_release_env = _first_segment_after(current_file, "/pre_releases/manifests/")
    _release_id = _first_segment_after(current_file, "/releases/")
    _is_pre_release = _pre_release_env != ""
    _is_release = _release_id != ""
    _release_kind = "pre_release" if _is_pre_release else ("release" if _is_release else "")
    _environment = _pre_release_env if _is_pre_release else (_environment_from_release_id(_release_id) if _is_release else "")
    _project_version = option("koncept_project_version", default=project_version_from_path(current_file))
    _version = _project_version + "-${_environment}" if _is_pre_release and _environment and _project_version else ("0.0.0-${_environment}" if _is_pre_release and _environment else (_version_from_id(_release_id) if _is_release else ""))
    _release_name = "pre_release_${_environment}" if _is_pre_release and _environment else ("release_${_release_id}" if _is_release and _release_id else "")
    _manifest_path = _join_path(["projects", _project_slug, "pre_releases", "manifests", _environment, "output"]) if _is_pre_release else (_join_path(["projects", _project_slug, "releases", _release_id, "output"]) if _is_release else "")

    ConventionContext {
        projectSlug = _project_slug
        releaseKind = _release_kind
        releaseID = _pre_release_env if _is_pre_release else _release_id
        environment = _environment
        version = _version
        releaseName = _release_name
        manifestPath = _manifest_path
        profileName = profile_name_from_path(current_file)
        tenantID = tenant_id_from_path(current_file)
        siteName = site_name_from_path(current_file)
    }
}

build_profile = lambda spec: ProfileSpec -> profile_model.Profile {
    _ctx = context_from_path(spec.currentFile)
    profile_model.Profile {
        name = spec.name if spec.name != Undefined else _ctx.profileName
        configurations = spec.configurations
        if spec.metadata != Undefined:
            metadata = spec.metadata
    }
}

build_tenant = lambda spec: TenantSpec -> tenant_model.Tenant {
    _tenant_id = tenant_id_from_path(spec.currentFile)
    tenant_model.Tenant {
        name = spec.name if spec.name != Undefined else slug_to_display_name(_tenant_id)
        description = spec.description
        configurations = spec.configurations
        if spec.metadata != Undefined:
            metadata = spec.metadata
    }
}

build_site = lambda spec: SiteSpec -> site_model.Site {
    site_model.Site {
        name = spec.name if spec.name != Undefined else site_name_from_path(spec.currentFile)
        tenant = spec.tenant
        configurations = spec.configurations
        if spec.metadata != Undefined:
            metadata = spec.metadata
    }
}


