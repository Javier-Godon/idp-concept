// Package golden provides helpers for committed render snapshots used to detect
// rendering drift in CI and local verification.
package golden

import (
	"fmt"
	"strings"
)

// maxDiffLines caps the size of a drift summary so CI logs stay readable.
const maxDiffLines = 80

// Summary returns a concise, human-readable line diff between a committed golden
// snapshot and a freshly rendered actual output. It reports the changed region
// only (common prefix/suffix are elided) with 1-based line numbers, '-' for
// golden lines and '+' for actual lines. An empty string means no difference.
func Summary(golden, actual string) string {
	if golden == actual {
		return ""
	}

	g := strings.Split(golden, "\n")
	a := strings.Split(actual, "\n")

	// Longest common prefix.
	prefix := 0
	for prefix < len(g) && prefix < len(a) && g[prefix] == a[prefix] {
		prefix++
	}

	// Longest common suffix that does not overlap the prefix.
	suffix := 0
	for suffix < len(g)-prefix && suffix < len(a)-prefix &&
		g[len(g)-1-suffix] == a[len(a)-1-suffix] {
		suffix++
	}

	gMid := g[prefix : len(g)-suffix]
	aMid := a[prefix : len(a)-suffix]

	var b strings.Builder
	fmt.Fprintf(&b, "@@ golden line %d, actual line %d @@\n", prefix+1, prefix+1)

	lines := 0
	truncated := false
	emit := func(sign string, base int, rows []string) {
		for i, row := range rows {
			if lines >= maxDiffLines {
				truncated = true
				return
			}
			fmt.Fprintf(&b, "%s %d: %s\n", sign, base+i+1, row)
			lines++
		}
	}

	emit("-", prefix, gMid)
	emit("+", prefix, aMid)

	if truncated {
		b.WriteString("... (diff truncated)\n")
	}
	return strings.TrimRight(b.String(), "\n")
}
