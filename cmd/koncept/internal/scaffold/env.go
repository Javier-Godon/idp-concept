package scaffold

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"text/template"
)

// EnvSpec drives generation of a new environment (profile + site + pre-release
// factory) inside an existing project. It mirrors the development environment
// produced by `koncept init project`, parameterised by environment name.
type EnvSpec struct {
	// ProjectSlug is the KCL package name of the target project.
	ProjectSlug string
	// SchemaPrefix is the CamelCase form of ProjectSlug (e.g. "DemoSvc").
	SchemaPrefix string
	// DashName is the kebab-case project name used for namespaces.
	DashName string
	// Name is the stack/site folder name (e.g. "staging").
	Name string
	// NameCamel is the CamelCase form of Name (e.g. "Staging").
	NameCamel string
	// Short is the pre-release manifest directory and config suffix (e.g. "stg").
	Short string
	// Cluster is the site cluster folder name (e.g. "stg_cluster").
	Cluster string
	// AppsNamespace is the namespace the workloads deploy into.
	AppsNamespace string
	// AppProfile is the app profile value surfaced in configurations.
	AppProfile string
	// SiteName is the site identifier.
	SiteName string
	// StorageClass is the storage class for the site.
	StorageClass string
	// UseLocalPV controls useLocalPersistentVolumes in the site configuration.
	UseLocalPV bool
	// Tenant is the tenant package directory to reference (default "vendor").
	Tenant string
}

// ReleaseSpec drives generation of an immutable versioned release (versioned
// stack + production site + release factory) inside an existing project.
type ReleaseSpec struct {
	// ProjectSlug is the KCL package name of the target project.
	ProjectSlug string
	// SchemaPrefix is the CamelCase form of ProjectSlug.
	SchemaPrefix string
	// DashName is the kebab-case project name used for namespaces.
	DashName string
	// Version is the human version string (e.g. "1.0.0").
	Version string
	// VersionSlug is the package-safe version (e.g. "v1_0_0").
	VersionSlug string
	// SchemaVersion is the CamelCase version fragment used in schema names (e.g. "V1_0_0").
	SchemaVersion string
	// AppsNamespace is the namespace production workloads deploy into.
	AppsNamespace string
	// StorageClass is the production storage class.
	StorageClass string
	// Tenant is the tenant package directory to reference (default "vendor").
	Tenant string
}

// envPreset describes well-known environment defaults.
type envPreset struct {
	name         string
	short        string
	cluster      string
	appProfile   string
	siteName     string
	storageClass string
	useLocalPV   bool
}

var envPresets = map[string]envPreset{
	"dev":         {"development", "dev", "dev_cluster", "dev", "development", "local-path", true},
	"development": {"development", "dev", "dev_cluster", "dev", "development", "local-path", true},
	"stg":         {"staging", "stg", "stg_cluster", "staging", "staging", "local-path", true},
	"staging":     {"staging", "stg", "stg_cluster", "staging", "staging", "local-path", true},
	"prod":        {"production", "prod", "prod_cluster", "prod", "production", "local-path", true},
	"production":  {"production", "prod", "prod_cluster", "prod", "production", "local-path", true},
}

// NewEnvSpec derives an environment spec from an env name and the target project.
func NewEnvSpec(name, projectSlug string) EnvSpec {
	dash := strings.ReplaceAll(projectSlug, "_", "-")
	key := strings.ToLower(strings.TrimSpace(name))
	preset, ok := envPresets[key]
	if !ok {
		slug := Slugify(name)
		short := slug
		if len(short) > 4 {
			short = short[:4]
		}
		preset = envPreset{
			name:         slug,
			short:        short,
			cluster:      slug + "_cluster",
			appProfile:   slug,
			siteName:     slug,
			storageClass: "local-path",
			useLocalPV:   true,
		}
	}
	return EnvSpec{
		ProjectSlug:   projectSlug,
		SchemaPrefix:  CamelCase(projectSlug),
		DashName:      dash,
		Name:          preset.name,
		NameCamel:     CamelCase(preset.name),
		Short:         preset.short,
		Cluster:       preset.cluster,
		AppsNamespace: dash + "-apps",
		AppProfile:    preset.appProfile,
		SiteName:      preset.siteName,
		StorageClass:  preset.storageClass,
		UseLocalPV:    preset.useLocalPV,
		Tenant:        "vendor",
	}
}

// NewReleaseSpec derives a release spec from a version string and project.
func NewReleaseSpec(version, projectSlug string) ReleaseSpec {
	dash := strings.ReplaceAll(projectSlug, "_", "-")
	vslug := versionSlug(version)
	return ReleaseSpec{
		ProjectSlug:   projectSlug,
		SchemaPrefix:  CamelCase(projectSlug),
		DashName:      dash,
		Version:       version,
		VersionSlug:   vslug,
		SchemaVersion: CamelCase(vslug),
		AppsNamespace: dash + "-apps",
		StorageClass:  "local-path",
		Tenant:        "vendor",
	}
}

// versionSlug converts "1.0.0" / "v1.0.0" into "v1_0_0".
func versionSlug(version string) string {
	v := strings.ToLower(strings.TrimSpace(version))
	v = strings.TrimPrefix(v, "v")
	v = nonAlnumRE.ReplaceAllString(v, "_")
	v = strings.Trim(v, "_")
	if v == "" {
		v = "0_0_0"
	}
	return "v" + v
}

// envFiles is the ordered set of files written by GenerateEnv. Paths are
// POSIX-style and relative to the project root.
var envFiles = []projectFile{
	{"env_stack_def", "stacks/{{.Name}}/stack_def.k", tplEnvStackDef},
	{"env_profile_configs", "stacks/{{.Name}}/profile_configurations.k", tplEnvProfileConfigs},
	{"env_profile_def", "stacks/{{.Name}}/profile_def.k", tplEnvProfileDef},
	{"env_site_configs", "sites/{{.Name}}/{{.Cluster}}/configurations.k", tplEnvSiteConfigs},
	{"env_site_def", "sites/{{.Name}}/{{.Cluster}}/site_def.k", tplEnvSiteDef},
	{"env_pre_release_configs", "pre_releases/configurations_{{.Short}}.k", tplEnvPreReleaseConfigs},
	{"env_render", "pre_releases/manifests/{{.Short}}/factory/render.k", tplRenderK},
	{"env_factory_seed", "pre_releases/manifests/{{.Short}}/factory/factory_seed.k", tplEnvFactorySeed},
}

// releaseFiles is the ordered set of files written by GenerateRelease. The
// production site files are only written if they do not already exist.
var releaseFiles = []projectFile{
	{"rel_stack_def", "stacks/versioned/{{.VersionSlug}}/stack_def.k", tplRelStackDef},
	{"rel_profile_configs", "stacks/versioned/{{.VersionSlug}}/profile_configurations.k", tplRelProfileConfigs},
	{"rel_profile_def", "stacks/versioned/{{.VersionSlug}}/profile_def.k", tplRelProfileDef},
	{"rel_site_configs", "sites/production/default/configurations.k", tplRelSiteConfigs},
	{"rel_site_def", "sites/production/default/site_def.k", tplRelSiteDef},
	{"rel_releases_mod", "releases/kcl.mod", tplReleasesMod},
	{"rel_render", "releases/{{.VersionSlug}}_production/factory/render.k", tplRenderK},
	{"rel_factory_seed", "releases/{{.VersionSlug}}_production/factory/factory_seed.k", tplRelFactorySeed},
}

// GenerateEnv writes a new environment under projectRoot and returns the created
// files. It refuses to overwrite any existing environment file.
func GenerateEnv(spec EnvSpec, projectRoot string) ([]string, error) {
	return generateFiles(envFiles, spec, projectRoot, nil)
}

// GenerateRelease writes a new versioned release under projectRoot and returns
// the created files. Shared production-site and releases/kcl.mod files are kept
// if they already exist; release-specific files must not pre-exist.
func GenerateRelease(spec ReleaseSpec, projectRoot string) ([]string, error) {
	// Files that may be shared across releases and should not error if present.
	shared := map[string]bool{
		"rel_site_configs": true,
		"rel_site_def":     true,
		"rel_releases_mod": true,
	}
	return generateFiles(releaseFiles, spec, projectRoot, shared)
}

// generateFiles renders and writes a set of templated files. For files whose
// name is marked skipIfExists, an existing file is left untouched; for all other
// files an existing target is a hard error to avoid clobbering authored content.
func generateFiles(files []projectFile, data any, projectRoot string, skipIfExists map[string]bool) ([]string, error) {
	type planned struct {
		name    string
		outPath string
		content string
	}
	var plan []planned
	for _, f := range files {
		content, err := renderText(f.name, f.content, data)
		if err != nil {
			return nil, fmt.Errorf("render %s: %w", f.path, err)
		}
		relPath, err := renderText(f.name+":path", f.path, data)
		if err != nil {
			return nil, fmt.Errorf("render path %s: %w", f.path, err)
		}
		outPath := filepath.Join(projectRoot, filepath.FromSlash(relPath))
		if _, statErr := os.Stat(outPath); statErr == nil {
			if skipIfExists[f.name] {
				continue
			}
			return nil, fmt.Errorf("refusing to overwrite existing file: %s", outPath)
		}
		plan = append(plan, planned{name: f.name, outPath: outPath, content: content})
	}

	var created []string
	for _, p := range plan {
		if err := os.MkdirAll(filepath.Dir(p.outPath), 0o755); err != nil {
			return created, err
		}
		if err := os.WriteFile(p.outPath, []byte(p.content), 0o644); err != nil {
			return created, err
		}
		created = append(created, p.outPath)
	}
	return created, nil
}

func renderText(name, content string, data any) (string, error) {
	tmpl, err := template.New(name).Parse(content)
	if err != nil {
		return "", err
	}
	var b strings.Builder
	if err := tmpl.Execute(&b, data); err != nil {
		return "", err
	}
	return b.String(), nil
}

// ---- environment templates ----

const tplEnvStackDef = `"""{{.ProjectSlug}} {{.Name}} stack — only environment-specific overrides live here."""

import {{.ProjectSlug}}.stacks.{{.ProjectSlug}}_stack as common

schema Stack(common.{{.SchemaPrefix}}Stack):
    # Override image tags or sizing for {{.Name}} here.

schema {{.SchemaPrefix}}{{.NameCamel}}Stack(Stack):
    # Backward-compatible alias for existing imports.
`

const tplEnvProfileConfigs = `import {{.ProjectSlug}}.core_sources.{{.ProjectSlug}}_configurations as cfg

_{{.ProjectSlug}}_{{.Short}}_profile_configurations = cfg.{{.SchemaPrefix}}Configurations {
    appsNamespace = "{{.AppsNamespace}}"
    appProfile = "{{.AppProfile}}"
}
`

const tplEnvProfileDef = `import file
import framework.factory.conventions as conventions
import {{.ProjectSlug}}.core_sources.{{.ProjectSlug}}_configurations as cfg
import {{.ProjectSlug}}.stacks.{{.Name}}.profile_configurations

profile = conventions.build_profile(conventions.ProfileSpec {
    currentFile = file.current()
    configurations = cfg.{{.SchemaPrefix}}Configurations {
        **profile_configurations._{{.ProjectSlug}}_{{.Short}}_profile_configurations
    }
})

{{.ProjectSlug}}_{{.Short}}_profile = profile
`

const tplEnvSiteConfigs = `import {{.ProjectSlug}}.core_sources.{{.ProjectSlug}}_configurations as cfg

_{{.Cluster}}_site_configurations = cfg.{{.SchemaPrefix}}Configurations {
    siteName = "{{.Cluster}}"
    storageClassName = "{{.StorageClass}}"
    useLocalPersistentVolumes = {{if .UseLocalPV}}True{{else}}False{{end}}
}
`

const tplEnvSiteDef = `import file
import framework.factory.conventions as conventions
import {{.ProjectSlug}}.tenants.{{.Tenant}}.tenant_def as tenant_def
import {{.ProjectSlug}}.core_sources.{{.ProjectSlug}}_configurations as cfg
import {{.ProjectSlug}}.sites.{{.Name}}.{{.Cluster}}.configurations

site = conventions.build_site(conventions.SiteSpec {
    currentFile = file.current()
    tenant = tenant_def.tenant
    configurations = cfg.{{.SchemaPrefix}}Configurations {
        **configurations._{{.Cluster}}_site_configurations
    }
})

{{.Cluster}}_site = site
`

const tplEnvPreReleaseConfigs = `"""
Pre-release configurations for the {{.Name}} environment — merges all 4 layers.
"""

import {{.ProjectSlug}}.stacks.{{.Name}}.stack_def
import {{.ProjectSlug}}.stacks.{{.Name}}.profile_def
import {{.ProjectSlug}}.tenants.{{.Tenant}}
import {{.ProjectSlug}}.sites.{{.Name}}.{{.Cluster}}.site_def
import {{.ProjectSlug}}.kernel.project_def
import framework.models.configurations as base

_tenant = {{.Tenant}}.tenant_{{.Tenant}}
_project = project_def.{{.ProjectSlug}}_project
_site = site_def.{{.Cluster}}_site
_profile = profile_def.{{.ProjectSlug}}_{{.Short}}_profile

_pre_release_configurations_{{.Cluster}} = base.merge_configurations(_project.configurations, _profile.configurations, _tenant.configurations, _site.configurations)

_stack = stack_def.{{.SchemaPrefix}}{{.NameCamel}}Stack {
    instanceConfigurations = _pre_release_configurations_{{.Cluster}}
}
`

const tplEnvFactorySeed = `"""
Factory seed for {{.ProjectSlug}} {{.Name}} pre-release.
Contract exports: _stack, _project_name, _git_repo_url, _manifest_path
"""

import file
import framework.factory.conventions as conventions
import framework.factory.seed as seed
import {{.ProjectSlug}}.stacks.{{.Name}}.stack_def
import {{.ProjectSlug}}.stacks.{{.Name}}.profile_def
import {{.ProjectSlug}}.tenants.{{.Tenant}}.tenant_def
import {{.ProjectSlug}}.sites.{{.Name}}.{{.Cluster}}.site_def
import {{.ProjectSlug}}.kernel.project_def

_context = conventions.context_from_path(file.current())

_factory = seed.FactorySeed {
    project = project_def.{{.ProjectSlug}}_project
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
`

// ---- release templates ----

const tplRelStackDef = `"""{{.ProjectSlug}} {{.Version}} release stack — only version-specific pins live here."""

import {{.ProjectSlug}}.stacks.{{.ProjectSlug}}_stack as common

schema Stack(common.{{.SchemaPrefix}}Stack):
    appVersion = "{{.Version}}"

schema {{.SchemaPrefix}}{{.SchemaVersion}}Stack(Stack):
    # Backward-compatible alias for existing imports.
`

const tplRelProfileConfigs = `import {{.ProjectSlug}}.core_sources.{{.ProjectSlug}}_configurations as cfg

_{{.ProjectSlug}}_{{.VersionSlug}}_profile_configurations = cfg.{{.SchemaPrefix}}Configurations {
    appsNamespace = "{{.AppsNamespace}}"
    appProfile = "prod"
}
`

const tplRelProfileDef = `import file
import framework.factory.conventions as conventions
import {{.ProjectSlug}}.core_sources.{{.ProjectSlug}}_configurations as cfg
import {{.ProjectSlug}}.stacks.versioned.{{.VersionSlug}}.profile_configurations

profile = conventions.build_profile(conventions.ProfileSpec {
    currentFile = file.current()
    configurations = cfg.{{.SchemaPrefix}}Configurations {
        **profile_configurations._{{.ProjectSlug}}_{{.VersionSlug}}_profile_configurations
    }
})

{{.ProjectSlug}}_{{.VersionSlug}}_profile = profile
`

const tplRelSiteConfigs = `import {{.ProjectSlug}}.core_sources.{{.ProjectSlug}}_configurations as cfg

_production_site_configurations = cfg.{{.SchemaPrefix}}Configurations {
    siteName = "production"
    storageClassName = "{{.StorageClass}}"
    useLocalPersistentVolumes = True
}
`

const tplRelSiteDef = `import file
import framework.factory.conventions as conventions
import {{.ProjectSlug}}.tenants.{{.Tenant}}.tenant_def as tenant_def
import {{.ProjectSlug}}.core_sources.{{.ProjectSlug}}_configurations as cfg
import {{.ProjectSlug}}.sites.production.default.configurations

site = conventions.build_site(conventions.SiteSpec {
    currentFile = file.current()
    tenant = tenant_def.tenant
    configurations = cfg.{{.SchemaPrefix}}Configurations {
        **configurations._production_site_configurations
    }
})

production_site = site
`

const tplReleasesMod = `[package]
name = "releases"
edition = "v0.10.0"
version = "0.0.1"

[dependencies]
{{.ProjectSlug}} = { path = "../" }
`

const tplRelFactorySeed = `"""
Factory seed for {{.ProjectSlug}} {{.Version}} production release.
Contract exports: _stack, _project_name, _git_repo_url, _manifest_path
"""

import file
import framework.factory.conventions as conventions
import framework.factory.seed as seed
import {{.ProjectSlug}}.stacks.versioned.{{.VersionSlug}}.stack_def as stack
import {{.ProjectSlug}}.stacks.versioned.{{.VersionSlug}}.profile_def
import {{.ProjectSlug}}.tenants.{{.Tenant}}.tenant_def
import {{.ProjectSlug}}.sites.production.default.site_def
import {{.ProjectSlug}}.kernel.project_def

_context = conventions.context_from_path(file.current())

_factory = seed.FactorySeed {
    project = project_def.{{.ProjectSlug}}_project
    profile = profile_def.profile
    tenant = tenant_def.tenant
    site = site_def.site
    stackSchema = stack.Stack
    version = _context.version
    releaseName = _context.releaseName
    manifestPath = _context.manifestPath
}

_stack = _factory.renderStack
_project_name = _factory.projectName
_git_repo_url = _factory.gitRepoUrl
_manifest_path = _factory.manifestPath
`
