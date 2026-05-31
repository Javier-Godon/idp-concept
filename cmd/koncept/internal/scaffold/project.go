package scaffold

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"text/template"
)

// ProjectSpec drives generation of a complete, validating webapp project skeleton.
type ProjectSpec struct {
	// DisplayName is the human-readable project name (e.g. "Inventory Service").
	DisplayName string
	// Slug is the KCL package name (lower_snake_case).
	Slug string
	// SchemaPrefix is the CamelCase prefix used for generated schemas.
	SchemaPrefix string
	// DashName is the kebab-case form used for Kubernetes object names/namespaces.
	DashName string
	// AppPackage is the snake_case module package name (e.g. "inventory_api").
	AppPackage string
	// AppName is the Kubernetes name of the web app (e.g. "inventory-api").
	AppName string
	// AppsNamespace is the namespace the web app is deployed to.
	AppsNamespace string
	// Image and Version pin the application container image.
	Image   string
	Version string
	// Port is the application container/service port.
	Port int
	// GitRepoURL feeds the kernel gitRepoUrl configuration.
	GitRepoURL string
	// FrameworkPath is the kcl.mod path to the framework package (relative to the project root).
	FrameworkPath string
	// FrameworkVersionConstraint documents the framework compatibility contract.
	FrameworkVersionConstraint string
	// FrameworkSupportTier documents support expectations for generated stacks.
	FrameworkSupportTier string
	// BackstageOwner is the ownership label/owner value.
	BackstageOwner string
}

var nonAlnumRE = regexp.MustCompile(`[^a-z0-9]+`)

// NewProjectSpec derives a full spec from a project name and option overrides.
func NewProjectSpec(name string) ProjectSpec {
	slug := Slugify(name)
	dash := strings.ReplaceAll(slug, "_", "-")
	return ProjectSpec{
		DisplayName:                name,
		Slug:                       slug,
		SchemaPrefix:               CamelCase(slug),
		DashName:                   dash,
		AppPackage:                 slug + "_api",
		AppName:                    dash + "-api",
		AppsNamespace:              dash + "-apps",
		Image:                      "ghcr.io/example/" + dash + "-api",
		Version:                    "0.1.0",
		Port:                       8080,
		GitRepoURL:                 "https://github.com/example/" + dash,
		FrameworkPath:              "../../framework",
		FrameworkVersionConstraint: ">=0.1.0 <1.0.0",
		FrameworkSupportTier:       "tier-1",
		BackstageOwner:             "platform-team",
	}
}

// Slugify converts an arbitrary name into a lower_snake_case KCL package name.
func Slugify(name string) string {
	s := strings.ToLower(strings.TrimSpace(name))
	s = nonAlnumRE.ReplaceAllString(s, "_")
	s = strings.Trim(s, "_")
	if s == "" {
		s = "project"
	}
	if s[0] >= '0' && s[0] <= '9' {
		s = "p_" + s
	}
	return s
}

// CamelCase converts lower_snake_case into CamelCase.
func CamelCase(slug string) string {
	parts := strings.Split(slug, "_")
	var b strings.Builder
	for _, p := range parts {
		if p == "" {
			continue
		}
		b.WriteString(strings.ToUpper(p[:1]))
		b.WriteString(p[1:])
	}
	return b.String()
}

// Generate writes the project skeleton under destRoot/<slug>. It refuses to
// overwrite an existing project directory and returns the list of files created.
func Generate(spec ProjectSpec, destRoot string) ([]string, error) {
	projectRoot := filepath.Join(destRoot, spec.Slug)
	if _, err := os.Stat(projectRoot); err == nil {
		return nil, fmt.Errorf("project directory already exists: %s", projectRoot)
	}

	var created []string
	for _, f := range projectFiles {
		rendered, err := renderTemplate(f.name, f.content, spec)
		if err != nil {
			return created, fmt.Errorf("render %s: %w", f.path, err)
		}
		relPath, err := renderTemplate(f.name+":path", f.path, spec)
		if err != nil {
			return created, fmt.Errorf("render path %s: %w", f.path, err)
		}
		outPath := filepath.Join(projectRoot, filepath.FromSlash(relPath))
		if err := os.MkdirAll(filepath.Dir(outPath), 0o755); err != nil {
			return created, err
		}
		if err := os.WriteFile(outPath, []byte(rendered), 0o644); err != nil {
			return created, err
		}
		created = append(created, outPath)
	}
	return created, nil
}

func renderTemplate(name, content string, spec ProjectSpec) (string, error) {
	tmpl, err := template.New(name).Parse(content)
	if err != nil {
		return "", err
	}
	var b strings.Builder
	if err := tmpl.Execute(&b, spec); err != nil {
		return "", err
	}
	return b.String(), nil
}
