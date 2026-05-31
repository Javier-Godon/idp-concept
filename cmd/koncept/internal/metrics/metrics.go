// Package metrics provides opt-in, local-only platform telemetry for the
// koncept CLI. It records render/validate/scaffold events as JSON lines so a
// platform team can understand adoption and the most common failure modes
// without sending any data off the developer's machine.
//
// Telemetry is OFF by default. It is enabled only when the caller passes an
// explicit opt-in (the --metrics flag or KONCEPT_METRICS=1). No data ever
// leaves the local filesystem; the platform team aggregates by collecting the
// JSONL file through its own trusted channel.
package metrics

import (
	"bufio"
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Event is a single recorded CLI operation.
type Event struct {
	Timestamp     time.Time `json:"timestamp"`
	Command       string    `json:"command"`
	Format        string    `json:"format,omitempty"`
	DurationMs    int64     `json:"durationMs"`
	Success       bool      `json:"success"`
	ErrorCategory string    `json:"errorCategory,omitempty"`
	Version       string    `json:"version,omitempty"`
}

// Recorder appends events to a JSONL file when enabled.
type Recorder struct {
	enabled bool
	path    string
	version string
}

// NewRecorder builds a recorder. When enabled is false every method is a no-op,
// so callers can wire it unconditionally. The path falls back to the standard
// per-user location when empty.
func NewRecorder(enabled bool, path, version string) *Recorder {
	if path == "" {
		path = DefaultPath()
	}
	return &Recorder{enabled: enabled, path: path, version: version}
}

// Enabled reports whether the recorder will persist events.
func (r *Recorder) Enabled() bool { return r != nil && r.enabled }

// Path returns the JSONL file the recorder writes to.
func (r *Recorder) Path() string {
	if r == nil {
		return ""
	}
	return r.path
}

// Record persists a single event. Failures to write are intentionally silent:
// telemetry must never break the primary command.
func (r *Recorder) Record(command, format string, duration time.Duration, err error) {
	if !r.Enabled() {
		return
	}
	ev := Event{
		Timestamp:     time.Now().UTC(),
		Command:       command,
		Format:        format,
		DurationMs:    duration.Milliseconds(),
		Success:       err == nil,
		ErrorCategory: Categorize(err),
		Version:       r.version,
	}
	line, mErr := json.Marshal(ev)
	if mErr != nil {
		return
	}
	if dir := filepath.Dir(r.path); dir != "" {
		_ = os.MkdirAll(dir, 0o755)
	}
	f, oErr := os.OpenFile(r.path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if oErr != nil {
		return
	}
	defer f.Close()
	_, _ = f.Write(append(line, '\n'))
}

// DefaultPath resolves the standard metrics file location. KONCEPT_METRICS_FILE
// overrides it; otherwise it lives under the user config/home directory.
func DefaultPath() string {
	if p := os.Getenv("KONCEPT_METRICS_FILE"); p != "" {
		return p
	}
	if dir, err := os.UserConfigDir(); err == nil && dir != "" {
		return filepath.Join(dir, "koncept", "metrics.jsonl")
	}
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		return filepath.Join(home, ".koncept", "metrics.jsonl")
	}
	return filepath.Join(".koncept", "metrics.jsonl")
}

// EnabledFromEnv reports whether KONCEPT_METRICS opts telemetry in.
func EnabledFromEnv() bool {
	switch strings.ToLower(strings.TrimSpace(os.Getenv("KONCEPT_METRICS"))) {
	case "1", "true", "yes", "on":
		return true
	default:
		return false
	}
}

// Categorize maps an error to a small, stable set of buckets so aggregated
// reports are meaningful without leaking message contents.
func Categorize(err error) string {
	if err == nil {
		return ""
	}
	msg := strings.ToLower(err.Error())
	switch {
	case strings.Contains(msg, "cannot find") && strings.Contains(msg, "module"),
		strings.Contains(msg, "module resolution"),
		strings.Contains(msg, "failed to load") && strings.Contains(msg, "kcl.mod"):
		return "module-resolution"
	case strings.Contains(msg, "render.k not found"),
		strings.Contains(msg, "factory"):
		return "factory-setup"
	case strings.Contains(msg, "policy"):
		return "policy"
	case strings.Contains(msg, "schema") || strings.Contains(msg, "check") ||
		strings.Contains(msg, "validation") || strings.Contains(msg, "expected"):
		return "validation"
	case strings.Contains(msg, "permission") || strings.Contains(msg, "no such file"):
		return "filesystem"
	default:
		return "other"
	}
}

// Load reads all events from a JSONL file. A missing file yields no events and
// no error so callers can treat "no data yet" as an empty summary.
func Load(path string) ([]Event, error) {
	if path == "" {
		path = DefaultPath()
	}
	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	defer f.Close()

	var events []Event
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var ev Event
		if err := json.Unmarshal([]byte(line), &ev); err != nil {
			continue // skip malformed lines rather than failing the report
		}
		events = append(events, ev)
	}
	if err := scanner.Err(); err != nil {
		return events, err
	}
	return events, nil
}

// CommandStat aggregates one command (optionally per format).
type CommandStat struct {
	Command    string
	Total      int
	Failures   int
	AvgMs      int64
	P50Ms      int64
	P95Ms      int64
	ByErrorCat map[string]int
	ByFormat   map[string]int
}

// Summary is the aggregate report over a set of events.
type Summary struct {
	Total      int
	Failures   int
	FirstSeen  time.Time
	LastSeen   time.Time
	Commands   []CommandStat
	ByFormat   map[string]int
	ByErrorCat map[string]int
}

// Summarize aggregates events into stable, sorted statistics.
func Summarize(events []Event) Summary {
	s := Summary{
		ByFormat:   map[string]int{},
		ByErrorCat: map[string]int{},
	}
	if len(events) == 0 {
		return s
	}

	byCmd := map[string][]Event{}
	for _, ev := range events {
		s.Total++
		if !ev.Success {
			s.Failures++
			if ev.ErrorCategory != "" {
				s.ByErrorCat[ev.ErrorCategory]++
			}
		}
		if ev.Format != "" {
			s.ByFormat[ev.Format]++
		}
		if s.FirstSeen.IsZero() || ev.Timestamp.Before(s.FirstSeen) {
			s.FirstSeen = ev.Timestamp
		}
		if ev.Timestamp.After(s.LastSeen) {
			s.LastSeen = ev.Timestamp
		}
		byCmd[ev.Command] = append(byCmd[ev.Command], ev)
	}

	names := make([]string, 0, len(byCmd))
	for name := range byCmd {
		names = append(names, name)
	}
	sort.Strings(names)

	for _, name := range names {
		evs := byCmd[name]
		stat := CommandStat{
			Command:    name,
			Total:      len(evs),
			ByErrorCat: map[string]int{},
			ByFormat:   map[string]int{},
		}
		durations := make([]int64, 0, len(evs))
		var sum int64
		for _, ev := range evs {
			durations = append(durations, ev.DurationMs)
			sum += ev.DurationMs
			if !ev.Success {
				stat.Failures++
				if ev.ErrorCategory != "" {
					stat.ByErrorCat[ev.ErrorCategory]++
				}
			}
			if ev.Format != "" {
				stat.ByFormat[ev.Format]++
			}
		}
		stat.AvgMs = sum / int64(len(evs))
		stat.P50Ms = percentile(durations, 50)
		stat.P95Ms = percentile(durations, 95)
		s.Commands = append(s.Commands, stat)
	}
	return s
}

func percentile(values []int64, p int) int64 {
	if len(values) == 0 {
		return 0
	}
	sorted := make([]int64, len(values))
	copy(sorted, values)
	sort.Slice(sorted, func(i, j int) bool { return sorted[i] < sorted[j] })
	if len(sorted) == 1 {
		return sorted[0]
	}
	rank := (p * (len(sorted) - 1)) / 100
	if rank < 0 {
		rank = 0
	}
	if rank >= len(sorted) {
		rank = len(sorted) - 1
	}
	return sorted[rank]
}
