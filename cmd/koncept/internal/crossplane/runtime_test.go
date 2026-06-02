package crossplane

import "testing"

func TestValidateRuntimeMode(t *testing.T) {
	cases := []string{RuntimeModeNone, RuntimeModeServerDryRun, RuntimeModeApplyDelete}
	for _, mode := range cases {
		if err := ValidateRuntimeMode(mode); err != nil {
			t.Fatalf("ValidateRuntimeMode(%q) error = %v", mode, err)
		}
	}
}

func TestValidateRuntimeModeInvalid(t *testing.T) {
	if err := ValidateRuntimeMode("dangerous-mode"); err == nil {
		t.Fatalf("expected invalid mode to return error")
	}
}
