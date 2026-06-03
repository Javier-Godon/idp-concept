# Framework Observability Guide

> Export framework deployment inventory to Prometheus, Grafana, and custom systems for real-time visibility into framework module deployments across your platform.

---

## 1. Overview

Framework observability provides operators with visibility into deployed modules, dependencies, and resource allocations. The observability export tool converts dry-run inventory into multiple formats:

- **Prometheus metrics**: For time-series monitoring and alerting
- **Grafana dashboards**: For visualization and team dashboards
- **JSON exports**: For custom integrations (ServiceNow, Datadog, Splunk, etc.)

---

## 2. Quick Start

### Generate Observability Exports

```bash
# From a factory directory, generate all observability data
cd projects/erp_back/pre_releases/manifests/dev/factory
../../../../../../scripts/framework-observability-export.sh .

# Output:
# [observability] Found: 4 components, 5 accessories, 12 dependencies
# [observability] ✓ Prometheus metrics: output/observability/metrics.txt
# [observability] ✓ Grafana dashboard: output/observability/grafana-dashboard.json
# [observability] ✓ Inventory JSON: output/observability/inventory.json
```

### Integrate with Prometheus

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'framework'
    static_configs:
      - targets: ['localhost:8080/metrics']

  # Or scrape from file
  - job_name: 'framework-static'
    metrics_path: '/tmp/framework-metrics.txt'
    scrape_interval: 5m
```

### Import into Grafana

```bash
# Via CLI
grafana-cli admin provisioning dashboards \
  --file output/observability/grafana-dashboard.json

# Or manually:
# 1. Grafana → Dashboards → Import
# 2. Paste contents of grafana-dashboard.json
# 3. Select Prometheus as data source
# 4. Save
```

---

## 3. Observability Signals

### Module Inventory

```
idp_framework_components_total        = 4   # WebApps, services  
idp_framework_accessories_total       = 5   # Databases, caches, queues
idp_framework_namespaces_total        = 2   # Kubernetes namespaces
idp_framework_dependencies_total      = 12  # Inter-module edges
```

### Interpretation

| Metric | Healthy | Warning | Action |
|---|---|---|---|
| `components` | Stable over time | Spikes or drops | Review deployment changes |
| `accessories` | Matches dependencies | Orphaned (no deps) | Check for dead modules |
| `dependencies` | Forms DAG (no cycles) | Cycles detected | Break circular dependency |
| `namespaces` | Matches stack structure | Proliferation | Consolidate namespace strategy |

---

## 4. Resource Utilization Visibility

### CPU/Memory Predictions (from dry-run)

```json
{
  "resourceFootprint": {
    "estimatedCpuMillis": 2500,
    "estimatedMemoryMb": 4096,
    "estimatedNodesSmall": 2,
    "estimatedNodesMedium": 1
  }
}
```

### Usage

```bash
# Extract from dry-run inventory
jq '.spec.resourceFootprint' output/dry_run_plan.yaml

# Forward to monitoring system
curl -X POST http://prometheus:9100/api/v1/write \
  -d @output/observability/metrics.txt
```

---

## 5. Dependency Graph Visualization

### Export Dependency Graph (Graphviz)

```bash
# Create dependency DOT file from inventory
{
  echo "digraph framework_dependencies {"
  echo "  rankdir=LR;"
  jq -r '.dependencies[] | "\"\(.from)\" -> \"\(.to)\";"' output/observability/inventory.json
  echo "}"
} > output/observability/dependencies.dot

# Render to SVG/PNG
dot -Tsvg output/observability/dependencies.dot \
    -o output/observability/dependencies.svg
```

### Integration with Observability Systems

**Grafana Node Graph Panel**:

```json
{
  "type": "nodeGraph",
  "targets": [
    {
      "datasource": "prometheus",
      "expr": "label_replace(idp_framework_components_total, 'module', '$0', '', '.*')"
    }
  ]
}
```

---

## 6. Custom Integrations

### Example 1: ServiceNow CMDB Sync

```bash
#!/bin/bash
# Export framework modules to ServiceNow CMDB

INVENTORY="output/observability/inventory.json"

jq -r '.components[] | {
  name: .name,
  category: "software",
  type: "application_component",
  status: "in_use",
  owner: .owner
}' "$INVENTORY" | while read -r module; do
  curl -X POST "https://servicenow.company.com/api/now/table/cmdb_ci_service_discovered" \
    -H "Authorization: Bearer $SERVICENOW_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$module"
done
```

### Example 2: Datadog Event Stream

```bash
#!/bin/bash
# Push framework deployment events to Datadog

INVENTORY="output/observability/inventory.json"
TIMESTAMP=$(date +%s)

{
  echo "title: Framework Deployment Update"
  echo "text: "
  echo "- Components: $(jq -r '.summary.components' "$INVENTORY")"
  echo "- Accessories: $(jq -r '.summary.accessories' "$INVENTORY")"
  echo "- Dependencies: $(jq -r '.summary.dependencies' "$INVENTORY")"
  echo "timestamp: $TIMESTAMP"
  echo "tags: [framework, deployment, platform]"
} | curl -X POST "https://api.datadoghq.com/api/v1/events" \
  -H "DD-API-KEY: $DD_API_KEY" \
  -H "Content-Type: application/json" \
  -d @-
```

### Example 3: Splunk HTTP Event Collector

```bash
#!/bin/bash
# Stream framework metrics to Splunk

METRICS="output/observability/metrics.txt"

curl -X POST "https://splunk.company.com:8088/services/collector" \
  -H "Authorization: Splunk $SPLUNK_HEC_TOKEN" \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
  "event": $(cat "$METRICS" | jq -Rs '.'),
  "source": "framework",
  "sourcetype": "prometheus_exposition",
  "host": "$(hostname)"
}
EOF
```

---

## 7. Alerting Strategies

### Prometheus Alert Rules

```yaml
groups:
  - name: framework
    rules:
      - alert: FrameworkModuleCountSpike
        expr: abs(delta(idp_framework_components_total[5m])) > 2
        for: 5m
        annotations:
          summary: "Significant module count change"

      - alert: HighFrameworkCpuPrediction
        expr: idp_framework_cpu_millicores_predicted > 8000
        annotations:
          summary: "Framework predicted to exceed 8 CPU cores"

      - alert: FrameworkDependencyChainDepth
        expr: idp_framework_max_dependency_depth > 5
        annotations:
          summary: "Deep dependency chain detected (>5 levels)"
```

### Grafana Alerts

Import alerting rules from Prometheus to Grafana:

```bash
grafana-cli admin alert-rule-provisioning \
  --file prometheus-alert-rules.yaml
```

---

## 8. Troubleshooting

### Metrics Not Loading in Prometheus

```bash
# Verify metrics file format
promtool check metrics output/observability/metrics.txt

# If errors, regenerate with --format prometheus-metrics
scripts/framework-observability-export.sh --format prometheus-metrics --output /tmp/test
```

### Grafana Dashboard Import Fails

```bash
# Validate JSON
jq empty output/observability/grafana-dashboard.json

# Check Prometheus data source exists
curl -s http://grafana:3000/api/datasources | jq '.[] | select(.type=="prometheus")'
```

### Inventory Missing Dependencies

```bash
# Ensure dry-run was generated with full stack
koncept dry-run --factory . --output output

# Verify dry-run contains dependencies section
yq '.spec.dependencies' output/dry_run_plan.yaml | head -20
```

---

## 9. Observability Roadmap

### Near-term (Q3 2026)

- [ ] Real-time module deployment events (webhook notifications)
- [ ] Resource prediction auto-scaling signals
- [ ] Dependency cycle detection alerts

### Medium-term (Q4 2026)

- [ ] Cost estimation dashboard (per-module resource costs)
- [ ] Multi-cluster framework inventory aggregation
- [ ] Historical trend analysis (module growth patterns)

### Long-term (2027)

- [ ] AI-based recommendation engine (consolidation, optimization)
- [ ] Platform maturity scoring (based on module sophistication)
- [ ] Compliance dashboard (security posture, vulnerabilities)

---

## 10. Best Practices

| Practice | Why | How |
|---|---|---|
| **Regular exports** | Track deployment evolution | Cron job: `*/15 * * * * cd factory && framework-observability-export.sh` |
| **Archive history** | Build trends and baselines | Git commit observability snapshots weekly |
| **Alert on changes** | Catch unintended modifications | Prometheus rules for delta metrics |
| **Validate dependencies** | Prevent circular deps | Automated checks in CI/CD |
| **Document ownership** | Facilitate troubleshooting | Metadata sync to CMDB weekly |

---


