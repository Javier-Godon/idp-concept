package scaffold

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// markerStack is a minimal wire-ready stack mirroring the koncept-generated
// stack template: an imports-end marker, a modules-end marker, and marked
// component/accessory list lines.
const markerStack = `import framework.models.stack
import proj.modules.appops.proj_api.proj_api_module_def as proj_api
# koncept:imports:end

schema ProjStack(stack.Stack):
    _apps_namespace = asm.create_namespace(instanceConfigurations.appsNamespace, instanceConfigurations)

    _app = proj_api.ProjApiModule {
        name = "proj-api"
    }.instance

    # koncept:modules:end

    components = [_app]  # koncept:components
    accessories = []  # koncept:accessories
`

func writeStack(t *testing.T, content string) string {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "proj_stack.k")
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestWireModuleAccessory(t *testing.T) {
	stackPath := writeStack(t, markerStack)
	spec, err := NewModuleSpec("redis", "cache", "proj")
	if err != nil {
		t.Fatalf("NewModuleSpec: %v", err)
	}
	if err := WireModule(spec, stackPath); err != nil {
		t.Fatalf("WireModule: %v", err)
	}

	data, _ := os.ReadFile(stackPath)
	out := string(data)

	if !strings.Contains(out, "import proj.modules.infraops.cache.cache_module_def as cache") {
		t.Errorf("import not inserted:\n%s", out)
	}
	if !strings.Contains(out, "_cache = cache.CacheModule {") {
		t.Errorf("instance block not inserted:\n%s", out)
	}
	if !strings.Contains(out, "accessories = [_cache]  # koncept:accessories") {
		t.Errorf("accessory not appended to list:\n%s", out)
	}
	// The component list must remain untouched.
	if !strings.Contains(out, "components = [_app]  # koncept:components") {
		t.Errorf("component list should be unchanged:\n%s", out)
	}
	// The import must land before the imports-end marker.
	if strings.Index(out, "cache_module_def as cache") > strings.Index(out, "# koncept:imports:end") {
		t.Errorf("import inserted after imports-end marker:\n%s", out)
	}
	// The instance block must land before the modules-end marker.
	if strings.Index(out, "_cache = cache.CacheModule") > strings.Index(out, "# koncept:modules:end") {
		t.Errorf("instance block inserted after modules-end marker:\n%s", out)
	}
}

func TestWireModuleComponentAppendsNonEmpty(t *testing.T) {
	stackPath := writeStack(t, markerStack)
	spec, err := NewModuleSpec("webapp", "worker", "proj")
	if err != nil {
		t.Fatalf("NewModuleSpec: %v", err)
	}
	if err := WireModule(spec, stackPath); err != nil {
		t.Fatalf("WireModule: %v", err)
	}
	data, _ := os.ReadFile(stackPath)
	out := string(data)
	if !strings.Contains(out, "components = [_app, _worker]  # koncept:components") {
		t.Errorf("webapp not appended to non-empty component list:\n%s", out)
	}
}

func TestWireModuleRejectsReWire(t *testing.T) {
	stackPath := writeStack(t, markerStack)
	spec, _ := NewModuleSpec("redis", "cache", "proj")
	if err := WireModule(spec, stackPath); err != nil {
		t.Fatalf("first WireModule: %v", err)
	}
	if err := WireModule(spec, stackPath); err == nil {
		t.Fatal("expected error re-wiring an already-wired module")
	}
}

func TestWireModuleRequiresMarkers(t *testing.T) {
	// A stack without markers must be refused, never silently rewritten.
	unmarked := "schema ProjStack(stack.Stack):\n    components = [_app]\n    accessories = []\n"
	stackPath := writeStack(t, unmarked)
	before, _ := os.ReadFile(stackPath)

	spec, _ := NewModuleSpec("redis", "cache", "proj")
	if err := WireModule(spec, stackPath); err == nil {
		t.Fatal("expected error for stack without markers")
	}
	after, _ := os.ReadFile(stackPath)
	if string(before) != string(after) {
		t.Error("unmarked stack must not be modified on failure")
	}
}
