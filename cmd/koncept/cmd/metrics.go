package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"

	"github.com/idp-concept/koncept/internal/metrics"
	"github.com/spf13/cobra"
)

var (
	metricsJSON  bool
	metricsClear bool
)

var metricsCmd = &cobra.Command{
	Use:   "metrics",
	Short: "Summarize opt-in local platform telemetry",
	Long: `metrics aggregates the local, opt-in telemetry recorded by the koncept CLI.

Telemetry is OFF by default and never leaves the local machine. Enable it per
command with --metrics or globally with KONCEPT_METRICS=1. The platform team
collects the JSONL file through its own trusted channel to understand adoption,
render durations, and the most common failure categories.

  koncept metrics            — print an aggregate summary
  koncept metrics --json     — emit the raw summary as JSON
  koncept metrics --clear    — delete the local telemetry file`,
	RunE: runMetrics,
}

func init() {
	metricsCmd.Flags().BoolVar(&metricsJSON, "json", false, "emit the summary as JSON")
	metricsCmd.Flags().BoolVar(&metricsClear, "clear", false, "delete the local telemetry file")
}

func runMetrics(cmd *cobra.Command, args []string) error {
	path := metricsFile
	if path == "" {
		path = metrics.DefaultPath()
	}

	if metricsClear {
		if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
			return err
		}
		printSuccess(fmt.Sprintf("Telemetry file cleared: %s", path))
		return nil
	}

	events, err := metrics.Load(path)
	if err != nil {
		return err
	}
	summary := metrics.Summarize(events)

	if metricsJSON {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		return enc.Encode(summary)
	}

	printMetricsSummary(path, summary)
	return nil
}

func printMetricsSummary(path string, s metrics.Summary) {
	fmt.Printf("Platform telemetry — %s\n", path)
	if s.Total == 0 {
		fmt.Println("No telemetry recorded yet. Enable with --metrics or KONCEPT_METRICS=1.")
		return
	}

	successRate := 100.0
	if s.Total > 0 {
		successRate = float64(s.Total-s.Failures) / float64(s.Total) * 100
	}
	fmt.Printf("Window:    %s → %s\n", s.FirstSeen.Format("2006-01-02 15:04"), s.LastSeen.Format("2006-01-02 15:04"))
	fmt.Printf("Events:    %d (%d failures, %.1f%% success)\n\n", s.Total, s.Failures, successRate)

	fmt.Printf("%-12s %6s %8s %8s %8s %8s\n", "COMMAND", "RUNS", "FAILS", "AVG ms", "P50 ms", "P95 ms")
	for _, c := range s.Commands {
		fmt.Printf("%-12s %6d %8d %8d %8d %8d\n", c.Command, c.Total, c.Failures, c.AvgMs, c.P50Ms, c.P95Ms)
	}

	if len(s.ByFormat) > 0 {
		fmt.Printf("\nOutput format usage:\n")
		for _, kv := range sortedCounts(s.ByFormat) {
			fmt.Printf("  %-12s %d\n", kv.key, kv.count)
		}
	}

	if len(s.ByErrorCat) > 0 {
		fmt.Printf("\nFailure categories:\n")
		for _, kv := range sortedCounts(s.ByErrorCat) {
			fmt.Printf("  %-16s %d\n", kv.key, kv.count)
		}
	}
}

type countPair struct {
	key   string
	count int
}

func sortedCounts(m map[string]int) []countPair {
	pairs := make([]countPair, 0, len(m))
	for k, v := range m {
		pairs = append(pairs, countPair{k, v})
	}
	sort.Slice(pairs, func(i, j int) bool {
		if pairs[i].count != pairs[j].count {
			return pairs[i].count > pairs[j].count
		}
		return pairs[i].key < pairs[j].key
	})
	return pairs
}
