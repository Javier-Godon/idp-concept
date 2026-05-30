package factory

import (
	"fmt"
	"regexp"
	"strings"
)

// moduleNotFoundRE matches KCL "cannot find module" / "pkgpath ... not found" style errors.
var (
	moduleNotFoundRE = regexp.MustCompile(`(?i)(cannot find|not found|failed to find|no such).*(module|package|pkg)`)
	importErrorRE    = regexp.MustCompile(`(?i)(import|module|pkgpath).*(error|fail)`)
)

// ExplainKCLError augments a raw KCL error with concise, actionable hints for the
// most common idp-concept failure modes (module resolution, missing kcl.mod, and
// stale dependency locks). The original error text is always preserved.
func ExplainKCLError(err error) error {
	if err == nil {
		return nil
	}
	msg := err.Error()
	lower := strings.ToLower(msg)

	var hints []string
	switch {
	case moduleNotFoundRE.MatchString(msg) || strings.Contains(lower, "pkgpath"):
		hints = append(hints,
			"a KCL module could not be resolved",
			"check that the import path matches a package name declared in a kcl.mod",
			"local dependencies in kcl.mod use paths relative to the kcl.mod file, not the source file",
			"nested packages should depend on the parent project so framework resolves transitively",
			"run 'koncept deps' to list resolved dependency files")
	case strings.Contains(lower, "kcl.mod") && strings.Contains(lower, "not found"):
		hints = append(hints,
			"no kcl.mod was found at or above the factory directory",
			"run koncept from inside a project pre_release/release factory, or pass --factory")
	case strings.Contains(lower, "lock") || strings.Contains(lower, "checksum"):
		hints = append(hints,
			"the dependency lock may be stale",
			"regenerate it with 'kcl mod update' in the affected package")
	case importErrorRE.MatchString(msg):
		hints = append(hints,
			"an import could not be resolved",
			"verify the package name prefix and that the dependency is declared in kcl.mod")
	}

	if len(hints) == 0 {
		return err
	}

	var b strings.Builder
	b.WriteString(msg)
	b.WriteString("\n\nhint:")
	for _, h := range hints {
		b.WriteString("\n  - ")
		b.WriteString(h)
	}
	return fmt.Errorf("%s", b.String())
}
