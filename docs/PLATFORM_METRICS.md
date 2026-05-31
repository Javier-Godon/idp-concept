# Platform Metrics (opt-in local telemetry)

> Phase G of the [IDP Evolution Plan](IDP_EVOLUTION_PLAN.md). Lets a platform
> team measure adoption, render performance, and the most common failure
> categories — **without sending any data off the developer's machine**.

## Principles

- **Off by default.** Nothing is recorded unless a developer or CI explicitly opts in.
- **Local only.** Events are appended to a JSONL file on the local filesystem. The
  CLI never transmits telemetry. A platform team aggregates the file through its
  own trusted collection channel (for example a CI artifact upload).
- **No payloads or secrets.** Only the command name, output format, duration,
  success flag, a coarse error *category*, and the CLI version are recorded.
  Error messages, manifest contents, project names, and paths are never stored.
- **Never breaks the command.** Telemetry write failures are silent; the primary
  command result is unaffected.

## Enabling telemetry

Per invocation:

```bash
koncept --metrics render argocd
```

For a shell session or CI job:

```bash
export KONCEPT_METRICS=1
koncept render argocd
koncept validate
```

Accepted truthy values for `KONCEPT_METRICS`: `1`, `true`, `yes`, `on`.

## Where data is stored

Resolution order for the telemetry file:

1. `--metrics-file <path>` flag,
2. `KONCEPT_METRICS_FILE` environment variable,
3. `<user-config-dir>/koncept/metrics.jsonl` (e.g. `~/.config/koncept/metrics.jsonl`),
4. `~/.koncept/metrics.jsonl` as a fallback.

Each line is one JSON event:

```json
{"timestamp":"2026-05-31T19:10:32Z","command":"render","format":"argocd","durationMs":434,"success":true,"version":"1.0.0"}
```

## Reading the summary

```bash
koncept metrics            # aggregate table
koncept metrics --json     # machine-readable summary
koncept metrics --clear    # delete the local telemetry file
```

Example:

```text
Platform telemetry — /home/dev/.config/koncept/metrics.jsonl
Window:    2026-05-31 19:10 → 2026-05-31 19:42
Events:    128 (4 failures, 96.9% success)

COMMAND        RUNS    FAILS   AVG ms   P50 ms   P95 ms
render          110        3      274      251      612
validate         18        1       95       88      140

Output format usage:
  yaml         70
  argocd       30
  helmfile     10

Failure categories:
  module-resolution  2
  validation         1
  factory-setup      1
```

## What is tracked

| Field | Meaning |
|---|---|
| `command` | `render`, `validate`, … |
| `format` | output format for render commands (`yaml`, `argocd`, `helmfile`, …) |
| `durationMs` | wall-clock duration of the operation |
| `success` | whether the operation returned without error |
| `errorCategory` | coarse bucket: `module-resolution`, `factory-setup`, `policy`, `validation`, `filesystem`, `other` |
| `version` | CLI version string |

The summary derives render duration (avg/p50/p95), render/validation failure
counts, output-format usage, and the most common failure categories — the exact
signals called for in Phase G of the evolution plan.

## Collecting metrics in CI

Because telemetry is a plain local file, CI can opt in and upload it as a build
artifact for later aggregation:

```yaml
- name: Render with telemetry
  env:
    KONCEPT_METRICS: "1"
    KONCEPT_METRICS_FILE: ${{ runner.temp }}/koncept-metrics.jsonl
  run: koncept --factory "$FACTORY" render argocd

- uses: actions/upload-artifact@v4
  with:
    name: koncept-metrics
    path: ${{ runner.temp }}/koncept-metrics.jsonl
```

A central job can merge uploaded JSONL files and run `koncept metrics --json`
over the concatenation to produce a platform-wide view.

## Not in scope (yet)

- A hosted metrics backend or live dashboard. The current slice deliberately
  stays local and dependency-free, matching the evolution plan's "expose intent
  first, add infrastructure only after real demand" rollout pattern.
- Automatic upload. Collection is an explicit, reviewed platform-team action.
