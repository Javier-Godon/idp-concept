package golden

import (
	"strings"
	"testing"
)

func TestSummaryNoDiff(t *testing.T) {
	if s := Summary("a\nb\nc", "a\nb\nc"); s != "" {
		t.Errorf("expected empty summary for identical input, got %q", s)
	}
}

func TestSummaryChangedLine(t *testing.T) {
	golden := "line1\nline2\nline3\n"
	actual := "line1\nCHANGED\nline3\n"
	s := Summary(golden, actual)
	if !strings.Contains(s, "- 2: line2") {
		t.Errorf("summary should show removed golden line:\n%s", s)
	}
	if !strings.Contains(s, "+ 2: CHANGED") {
		t.Errorf("summary should show added actual line:\n%s", s)
	}
	// Unchanged surrounding lines must be elided.
	if strings.Contains(s, "line1") || strings.Contains(s, "line3") {
		t.Errorf("summary should elide common prefix/suffix:\n%s", s)
	}
}

func TestSummaryAddedLinesShown(t *testing.T) {
	golden := "a\nb\n"
	actual := "a\nx\ny\nb\n"
	s := Summary(golden, actual)
	if !strings.Contains(s, "+ 2: x") || !strings.Contains(s, "+ 3: y") {
		t.Errorf("summary should show inserted lines:\n%s", s)
	}
}

func TestSummaryTruncates(t *testing.T) {
	var gb, ab strings.Builder
	for i := 0; i < 200; i++ {
		gb.WriteString("g\n")
		ab.WriteString("a\n")
	}
	s := Summary(gb.String(), ab.String())
	if !strings.Contains(s, "diff truncated") {
		t.Errorf("large diff should be truncated:\n%s", s)
	}
	if got := strings.Count(s, "\n"); got > maxDiffLines+5 {
		t.Errorf("truncated diff too long: %d lines", got)
	}
}
