package scaffold

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// ModuleKind distinguishes how a module is wired into a stack.
type ModuleKind string

const (
	// KindComponent modules are deployable apps wired into stack.components.
	KindComponent ModuleKind = "component"
	// KindAccessory modules are supporting resources wired into stack.accessories.
	KindAccessory ModuleKind = "accessory"
)

// moduleType describes a supported `koncept init module <type>` template.
type moduleType struct {
	// importPath is the framework template import path.
	importPath string
	// alias is the import alias used in generated KCL.
	alias string
	// baseSchema is the template schema the generated module extends.
	baseSchema string
	// area is the modules/<area> subdirectory (appops or infraops).
	area string
	// kind controls component vs accessory wiring.
	kind ModuleKind
	// defaultVersion pins the upstream image/operator version.
	defaultVersion string
	// defBody renders the schema-body defaults of the generated module def.
	defBody func(ModuleSpec) string
	// wiringFields renders the type-specific instantiation fields in the stack snippet.
	wiringFields func(ModuleSpec) string
}

// ModuleSpec drives generation of a single module definition file plus its
// stack wiring snippet.
type ModuleSpec struct {
	// ProjectSlug is the KCL package name of the target project.
	ProjectSlug string
	// Type is the module template key (webapp, database, postgres, ...).
	Type string
	// DisplayName is the human-readable module name.
	DisplayName string
	// Package is the snake_case module package directory/name.
	Package string
	// SchemaName is the CamelCase schema name prefix (without the Module suffix).
	SchemaName string
	// K8sName is the kebab-case Kubernetes object name.
	K8sName string
	// InstanceVar is the private stack variable holding the module instance.
	InstanceVar string
	// Port is the application/service port (webapp/database).
	Port int
	// Image pins the application container image (webapp/database).
	Image string
	// Version pins the image/operator version.
	Version string
	// StorageSize sizes persistent volumes for stateful modules.
	StorageSize string
}

var moduleTypes = map[string]moduleType{
	"webapp": {
		importPath:     "framework.templates.webapp.v1_0_0.webapp",
		alias:          "webapp",
		baseSchema:     "webapp.WebAppModule",
		area:           "appops",
		kind:           KindComponent,
		defaultVersion: "0.1.0",
		defBody:        webappDefBody,
		wiringFields:   webappWiring,
	},
	"database": {
		importPath:     "framework.templates.database.v1_0_0.database",
		alias:          "database",
		baseSchema:     "database.SingleDatabaseModule",
		area:           "infraops",
		kind:           KindAccessory,
		defaultVersion: "3.10",
		defBody:        emptyDefBody,
		wiringFields:   databaseWiring,
	},
	"postgres": {
		importPath:     "framework.templates.postgresql.v1_0_0.postgresql",
		alias:          "postgresql",
		baseSchema:     "postgresql.PostgreSQLClusterModule",
		area:           "infraops",
		kind:           KindAccessory,
		defaultVersion: "16.4",
		defBody:        emptyDefBody,
		wiringFields:   postgresWiring,
	},
	"redis": {
		importPath:     "framework.templates.redis.v1_0_0.redis",
		alias:          "redis",
		baseSchema:     "redis.RedisModule",
		area:           "infraops",
		kind:           KindAccessory,
		defaultVersion: "7.0.12",
		defBody:        emptyDefBody,
		wiringFields:   redisWiring,
	},
	"kafka": {
		importPath:     "framework.templates.kafka.v1_0_0.kafka",
		alias:          "kafka",
		baseSchema:     "kafka.KafkaClusterModule",
		area:           "infraops",
		kind:           KindAccessory,
		defaultVersion: "3.8.0",
		defBody:        emptyDefBody,
		wiringFields:   kafkaWiring,
	},
	"mongodb": {
		importPath:     "framework.templates.mongodb.v1_0_0.mongodb",
		alias:          "mongodb",
		baseSchema:     "mongodb.MongoDBCommunityModule",
		area:           "infraops",
		kind:           KindAccessory,
		defaultVersion: "7.0.12",
		defBody:        emptyDefBody,
		wiringFields:   mongodbWiring,
	},
	"rabbitmq": {
		importPath:     "framework.templates.rabbitmq.v1_0_0.rabbitmq",
		alias:          "rabbitmq",
		baseSchema:     "rabbitmq.RabbitMQClusterModule",
		area:           "infraops",
		kind:           KindAccessory,
		defaultVersion: "3.13.7",
		defBody:        emptyDefBody,
		wiringFields:   rabbitmqWiring,
	},
}

// SupportedModuleTypes returns the sorted list of supported module type keys.
func SupportedModuleTypes() []string {
	keys := make([]string, 0, len(moduleTypes))
	for k := range moduleTypes {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

// NewModuleSpec derives a module spec from a type, name and project slug.
func NewModuleSpec(typ, name, projectSlug string) (ModuleSpec, error) {
	mt, ok := moduleTypes[typ]
	if !ok {
		return ModuleSpec{}, fmt.Errorf("unknown module type %q (supported: %s)",
			typ, strings.Join(SupportedModuleTypes(), ", "))
	}
	slug := Slugify(name)
	dash := strings.ReplaceAll(slug, "_", "-")
	return ModuleSpec{
		ProjectSlug: projectSlug,
		Type:        typ,
		DisplayName: name,
		Package:     slug,
		SchemaName:  CamelCase(slug),
		K8sName:     dash,
		InstanceVar: "_" + slug,
		Port:        8080,
		Image:       "ghcr.io/example/" + dash,
		Version:     mt.defaultVersion,
		StorageSize: "1Gi",
	}, nil
}

func (s ModuleSpec) typeConfig() moduleType { return moduleTypes[s.Type] }

// DetectProjectRoot walks up from start looking for a project kcl.mod (one that
// declares a framework dependency) and returns its directory and package name.
func DetectProjectRoot(start string) (root, slug string, err error) {
	dir, err := filepath.Abs(start)
	if err != nil {
		return "", "", err
	}
	for {
		modPath := filepath.Join(dir, "kcl.mod")
		if data, readErr := os.ReadFile(modPath); readErr == nil {
			content := string(data)
			if strings.Contains(content, "framework") && strings.Contains(content, "[dependencies]") {
				if name := kclModName(content); name != "" && name != "pre_releases" && name != "releases" {
					return dir, name, nil
				}
			}
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return "", "", fmt.Errorf("no project kcl.mod with a framework dependency found from %s", start)
}

// kclModName extracts the package name from kcl.mod TOML content.
func kclModName(content string) string {
	for _, line := range strings.Split(content, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "name") && strings.Contains(line, "=") {
			value := strings.TrimSpace(line[strings.Index(line, "=")+1:])
			return strings.Trim(value, "\"'")
		}
	}
	return ""
}

// ModuleDefPath returns the project-relative path of the generated module def file.
func (s ModuleSpec) ModuleDefPath() string {
	mt := s.typeConfig()
	return filepath.ToSlash(filepath.Join(
		"modules", mt.area, s.Package, s.Package+"_module_def.k"))
}

// GenerateModule writes the module definition file under projectRoot and returns
// the created file path together with a ready-to-paste stack wiring snippet. It
// refuses to overwrite an existing module def file.
func GenerateModule(spec ModuleSpec, projectRoot string) (createdPath, wiring string, err error) {
	mt := spec.typeConfig()
	rel := spec.ModuleDefPath()
	outPath := filepath.Join(projectRoot, filepath.FromSlash(rel))
	if _, statErr := os.Stat(outPath); statErr == nil {
		return "", "", fmt.Errorf("module already exists: %s", outPath)
	}
	if err := os.MkdirAll(filepath.Dir(outPath), 0o755); err != nil {
		return "", "", err
	}

	def := renderModuleDef(spec, mt)
	if err := os.WriteFile(outPath, []byte(def), 0o644); err != nil {
		return "", "", err
	}
	return outPath, renderWiring(spec, mt), nil
}

func renderModuleDef(spec ModuleSpec, mt moduleType) string {
	var b strings.Builder
	fmt.Fprintf(&b, "\"\"\"\n%s %s module — generated by koncept init module.\n\"\"\"\n",
		spec.DisplayName, spec.Type)
	fmt.Fprintf(&b, "import %s as %s\n", mt.importPath, mt.alias)
	if spec.Type == "webapp" {
		b.WriteString("import framework.builders.deployment as deploy\n")
	}
	b.WriteString("\n")
	fmt.Fprintf(&b, "schema %sModule(%s):\n", spec.SchemaName, mt.baseSchema)
	body := mt.defBody(spec)
	if strings.TrimSpace(body) == "" {
		// Keep a valid, empty-but-documented schema body.
		b.WriteString("    # Override template defaults here; instance fields are set in the stack.\n")
	} else {
		b.WriteString(body)
	}
	return b.String()
}

func renderWiring(spec ModuleSpec, mt moduleType) string {
	listName := "components"
	if mt.kind == KindAccessory {
		listName = "accessories"
	}
	var b strings.Builder
	b.WriteString(moduleImportLine(spec, mt) + "\n\n")
	b.WriteString(renderInstanceBlock(spec, mt, "") + "\n")
	fmt.Fprintf(&b, "# Append %s to the stack %s list:\n", spec.InstanceVar, listName)
	fmt.Fprintf(&b, "#     %s = [..., %s]\n", listName, spec.InstanceVar)
	return b.String()
}

// Stack wiring markers emitted by `koncept init project`. `--wire` edits only the
// regions delimited by these markers and refuses to touch stacks that lack them,
// so hand-authored stacks are never silently rewritten.
const (
	markerImportsEnd  = "# koncept:imports:end"
	markerModulesEnd  = "# koncept:modules:end"
	markerComponents  = "# koncept:components"
	markerAccessories = "# koncept:accessories"
)

// moduleImportLine returns the KCL import statement that exposes the generated
// module def under its package alias.
func moduleImportLine(spec ModuleSpec, mt moduleType) string {
	return fmt.Sprintf("import %s.modules.%s.%s.%s_module_def as %s",
		spec.ProjectSlug, mt.area, spec.Package, spec.Package, spec.Package)
}

// renderInstanceBlock renders the `_<pkg> = <Schema> { ... }.instance` block,
// prefixing every line with indent (empty for a top-level snippet, four spaces
// when wired inside a schema body).
func renderInstanceBlock(spec ModuleSpec, mt moduleType, indent string) string {
	var b strings.Builder
	fmt.Fprintf(&b, "%s = %s.%sModule {\n", spec.InstanceVar, spec.Package, spec.SchemaName)
	fmt.Fprintf(&b, "    name = %q\n", spec.K8sName)
	b.WriteString("    namespace = _apps_namespace.name\n")
	b.WriteString("    configurations = instanceConfigurations\n")
	b.WriteString(mt.wiringFields(spec))
	b.WriteString("    dependsOn = [_apps_namespace]\n")
	b.WriteString("}.instance\n")
	if indent == "" {
		return b.String()
	}
	lines := strings.Split(strings.TrimRight(b.String(), "\n"), "\n")
	var out strings.Builder
	for _, line := range lines {
		if line == "" {
			out.WriteString("\n")
			continue
		}
		out.WriteString(indent + line + "\n")
	}
	return out.String()
}

// WireModule inserts the generated module's import, instance block, and stack
// list membership into a marker-annotated stack file. It edits only the regions
// delimited by koncept markers; if any required marker is missing it returns an
// error and leaves the file untouched. Re-wiring an already-wired module is also
// rejected so the operation stays idempotent and non-destructive.
func WireModule(spec ModuleSpec, stackPath string) error {
	mt := spec.typeConfig()
	data, err := os.ReadFile(stackPath)
	if err != nil {
		return fmt.Errorf("read stack %s: %w", stackPath, err)
	}
	content := string(data)

	listMarker := markerComponents
	if mt.kind == KindAccessory {
		listMarker = markerAccessories
	}
	for _, marker := range []string{markerImportsEnd, markerModulesEnd, listMarker} {
		if !strings.Contains(content, marker) {
			return fmt.Errorf("stack %s is not wire-ready: missing marker %q\n"+
				"  re-run without --wire and paste the printed snippet, or add the marker manually",
				stackPath, marker)
		}
	}

	importLine := moduleImportLine(spec, mt)
	if strings.Contains(content, importLine) || strings.Contains(content, spec.InstanceVar+" =") {
		return fmt.Errorf("module %q already appears wired into %s", spec.Package, stackPath)
	}

	lines := strings.Split(content, "\n")
	var out []string
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		switch {
		case trimmed == markerImportsEnd:
			out = append(out, importLine, line)
		case trimmed == markerModulesEnd:
			out = append(out, renderInstanceBlock(spec, mt, "    "), line)
		case strings.Contains(line, listMarker):
			out = append(out, appendToListLine(line, spec.InstanceVar))
		default:
			out = append(out, line)
		}
	}

	if err := os.WriteFile(stackPath, []byte(strings.Join(out, "\n")), 0o644); err != nil {
		return fmt.Errorf("write stack %s: %w", stackPath, err)
	}
	return nil
}

// appendToListLine appends a variable to a KCL list assignment line of the form
// `    name = [a, b]  # marker`, producing `    name = [a, b, var]  # marker`.
// An empty list `[]` becomes `[var]`.
func appendToListLine(line, variable string) string {
	close := strings.LastIndex(line, "]")
	if close < 0 {
		return line
	}
	open := strings.LastIndex(line[:close], "[")
	if open < 0 {
		return line
	}
	inner := strings.TrimSpace(line[open+1 : close])
	var newInner string
	if inner == "" {
		newInner = variable
	} else {
		newInner = inner + ", " + variable
	}
	return line[:open+1] + newInner + line[close:]
}

func emptyDefBody(ModuleSpec) string { return "" }

func webappDefBody(spec ModuleSpec) string {
	return fmt.Sprintf(`    port = %d
    serviceType = "ClusterIP"
    replicas = 1
    imagePullPolicy = "IfNotPresent"

    resources = deploy.ResourceSpec {
        cpuRequest = "100m"
        cpuLimit = "1"
        memoryRequest = "256Mi"
        memoryLimit = "512Mi"
    }

    livenessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/healthz"
        port = %d
        initialDelaySeconds = 10
        periodSeconds = 10
    }

    readinessProbe = deploy.ProbeSpec {
        probeType = "http"
        path = "/readyz"
        port = %d
        initialDelaySeconds = 5
        periodSeconds = 5
    }
`, spec.Port, spec.Port, spec.Port)
}

func webappWiring(spec ModuleSpec) string {
	return fmt.Sprintf("    asset = {\n        image = %q\n        version = %q\n    }\n",
		spec.Image, spec.Version)
}

func databaseWiring(spec ModuleSpec) string {
	return fmt.Sprintf(`    asset = {
        image = "registry.k8s.io/pause"
        version = %q
    }
    port = %d
    dataPath = "/data"
    storageSize = %q
`, spec.Version, spec.Port, spec.StorageSize)
}

func postgresWiring(spec ModuleSpec) string {
	return fmt.Sprintf(`    asset = {version = %q}
    clusterName = %q
    instances = 1
    storageSize = %q
`, spec.Version, spec.K8sName, spec.StorageSize)
}

func redisWiring(spec ModuleSpec) string {
	return fmt.Sprintf(`    asset = {version = %q}
    redisName = %q
    storageSize = %q
`, spec.Version, spec.K8sName, spec.StorageSize)
}

func kafkaWiring(spec ModuleSpec) string {
	return fmt.Sprintf(`    asset = {version = %q}
    clusterName = %q
    kafkaReplicas = 1
    zookeeperReplicas = 1
    storageSize = %q
`, spec.Version, spec.K8sName, spec.StorageSize)
}

func mongodbWiring(spec ModuleSpec) string {
	return fmt.Sprintf(`    asset = {version = %q}
    clusterName = %q
    members = 1
    mongodbVersion = %q
    storageSize = %q
`, spec.Version, spec.K8sName, spec.Version, spec.StorageSize)
}

func rabbitmqWiring(spec ModuleSpec) string {
	return fmt.Sprintf(`    asset = {version = %q}
    clusterName = %q
    replicas = 1
    storageSize = %q
`, spec.Version, spec.K8sName, spec.StorageSize)
}
