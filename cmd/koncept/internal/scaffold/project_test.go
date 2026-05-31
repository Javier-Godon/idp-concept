package scaffold

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSlugify(t *testing.T) {
	cases := map[string]string{
		"Inventory Service": "inventory_service",
		"erp-back":          "erp_back",
		"  Mixed_Case 1 ":   "mixed_case_1",
		"123go":             "p_123go",
	}
	for in, want := range cases {
		if got := Slugify(in); got != want {
			t.Errorf("Slugify(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestCamelCase(t *testing.T) {
	if got := CamelCase("inventory_service"); got != "InventoryService" {
		t.Errorf("CamelCase = %q", got)
	}
}

func TestGenerateWritesAllFiles(t *testing.T) {
	dest := t.TempDir()
	spec := NewProjectSpec("Inventory Service")
	created, err := Generate(spec, dest)
	if err != nil {
		t.Fatalf("Generate failed: %v", err)
	}
	if len(created) != len(projectFiles) {
		t.Fatalf("expected %d files, got %d", len(projectFiles), len(created))
	}

	// Key files must exist with the slug-substituted paths.
	mustExist := []string{
		"inventory_service/koncept.yaml",
		"inventory_service/kcl.mod",
		"inventory_service/core_sources/inventory_service_configurations.k",
		"inventory_service/modules/appops/inventory_service_api/inventory_service_api_module_def.k",
		"inventory_service/pre_releases/manifests/dev/factory/render.k",
	}

	konceptData, err := os.ReadFile(filepath.Join(dest, "inventory_service/koncept.yaml"))
	if err != nil {
		t.Fatalf("read generated koncept.yaml: %v", err)
	}
	if !strings.Contains(string(konceptData), "versionConstraint: \">=0.1.0 <1.0.0\"") {
		t.Errorf("generated koncept.yaml missing framework version constraint")
	}

	stackData, err := os.ReadFile(filepath.Join(dest, "inventory_service/stacks/inventory_service_stack.k"))
	if err != nil {
		t.Fatalf("read generated stack: %v", err)
	}
	if !strings.Contains(string(stackData), "compatibility = compat.FrameworkCompatibility") {
		t.Errorf("generated stack missing framework compatibility metadata")
	}
	for _, marker := range []string{
		"# koncept:imports:end",
		"# koncept:modules:end",
		"# koncept:components",
		"# koncept:accessories",
	} {
		if !strings.Contains(string(stackData), marker) {
			t.Errorf("generated stack missing wire marker %q (breaks 'init module --wire')", marker)
		}
	}
	for _, rel := range mustExist {
		if _, err := os.Stat(filepath.Join(dest, rel)); err != nil {
			t.Errorf("expected file %s: %v", rel, err)
		}
	}

	// No leftover Go-template delimiters should remain in any generated file.
	for _, p := range created {
		data, err := os.ReadFile(p)
		if err != nil {
			t.Fatalf("read %s: %v", p, err)
		}
		if strings.Contains(string(data), "{{") {
			t.Errorf("unrendered template in %s", p)
		}
	}
}

func TestGenerateRefusesExisting(t *testing.T) {
	dest := t.TempDir()
	spec := NewProjectSpec("dup")
	if _, err := Generate(spec, dest); err != nil {
		t.Fatalf("first Generate failed: %v", err)
	}
	if _, err := Generate(spec, dest); err == nil {
		t.Fatal("expected error on existing project directory")
	}
}
