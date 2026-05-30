package scaffold

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestNewModuleSpecUnknownType(t *testing.T) {
	if _, err := NewModuleSpec("nope", "x", "proj"); err == nil {
		t.Fatal("expected error for unknown module type")
	}
}

func TestGenerateModuleWebapp(t *testing.T) {
	root := t.TempDir()
	spec, err := NewModuleSpec("webapp", "Orders API", "inventory_service")
	if err != nil {
		t.Fatalf("NewModuleSpec: %v", err)
	}
	path, wiring, err := GenerateModule(spec, root)
	if err != nil {
		t.Fatalf("GenerateModule: %v", err)
	}

	wantPath := filepath.Join(root, "modules/appops/orders_api/orders_api_module_def.k")
	if path != wantPath {
		t.Errorf("path = %s, want %s", path, wantPath)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	content := string(data)
	if !strings.Contains(content, "schema OrdersApiModule(webapp.WebAppModule):") {
		t.Errorf("module def missing schema decl:\n%s", content)
	}
	if !strings.Contains(content, "import framework.builders.deployment as deploy") {
		t.Errorf("webapp module def must import deployment builder")
	}
	if strings.Contains(content, "{{") {
		t.Errorf("unrendered template in module def")
	}

	if !strings.Contains(wiring, "import inventory_service.modules.appops.orders_api.orders_api_module_def as orders_api") {
		t.Errorf("wiring missing import:\n%s", wiring)
	}
	if !strings.Contains(wiring, "components") {
		t.Errorf("webapp wiring should reference components list:\n%s", wiring)
	}
}

func TestGenerateModuleInfraIsAccessory(t *testing.T) {
	for _, typ := range []string{"database", "postgres", "redis", "kafka", "mongodb", "rabbitmq"} {
		root := t.TempDir()
		spec, err := NewModuleSpec(typ, typ+"-svc", "proj")
		if err != nil {
			t.Fatalf("%s: NewModuleSpec: %v", typ, err)
		}
		path, wiring, err := GenerateModule(spec, root)
		if err != nil {
			t.Fatalf("%s: GenerateModule: %v", typ, err)
		}
		if !strings.Contains(path, "modules/infraops/") {
			t.Errorf("%s: infra module should live under infraops, got %s", typ, path)
		}
		if !strings.Contains(wiring, "accessories") {
			t.Errorf("%s: infra wiring should reference accessories list:\n%s", typ, wiring)
		}
		data, _ := os.ReadFile(path)
		if strings.Contains(string(data), "{{") {
			t.Errorf("%s: unrendered template", typ)
		}
	}
}

func TestGenerateModuleRefusesExisting(t *testing.T) {
	root := t.TempDir()
	spec, _ := NewModuleSpec("redis", "cache", "proj")
	if _, _, err := GenerateModule(spec, root); err != nil {
		t.Fatalf("first generate: %v", err)
	}
	if _, _, err := GenerateModule(spec, root); err == nil {
		t.Fatal("expected error on existing module def")
	}
}

func TestDetectProjectRoot(t *testing.T) {
	root := t.TempDir()
	projDir := filepath.Join(root, "myproj")
	nested := filepath.Join(projDir, "modules", "appops")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}
	mod := "[package]\nname = \"myproj\"\n\n[dependencies]\nframework = { path = \"../../framework\" }\n"
	if err := os.WriteFile(filepath.Join(projDir, "kcl.mod"), []byte(mod), 0o644); err != nil {
		t.Fatal(err)
	}

	gotRoot, slug, err := DetectProjectRoot(nested)
	if err != nil {
		t.Fatalf("DetectProjectRoot: %v", err)
	}
	if slug != "myproj" {
		t.Errorf("slug = %q, want myproj", slug)
	}
	if filepath.Base(gotRoot) != "myproj" {
		t.Errorf("root = %s, want .../myproj", gotRoot)
	}
}
