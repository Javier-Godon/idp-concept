package factory

import (
	"errors"
	"strings"
	"testing"
)

func TestExplainKCLErrorNil(t *testing.T) {
	if ExplainKCLError(nil) != nil {
		t.Fatal("expected nil for nil input")
	}
}

func TestExplainKCLErrorPassthrough(t *testing.T) {
	err := errors.New("some unrelated failure")
	got := ExplainKCLError(err)
	if got.Error() != err.Error() {
		t.Fatalf("expected passthrough, got %q", got.Error())
	}
}

func TestExplainKCLErrorModuleHint(t *testing.T) {
	err := errors.New("cannot find module 'framework.models.foo'")
	got := ExplainKCLError(err)
	if !strings.Contains(got.Error(), "hint:") {
		t.Fatalf("expected a hint, got %q", got.Error())
	}
	if !strings.Contains(got.Error(), "kcl.mod") {
		t.Fatalf("expected kcl.mod guidance, got %q", got.Error())
	}
}
