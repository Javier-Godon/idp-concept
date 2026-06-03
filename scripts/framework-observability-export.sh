#!/usr/bin/env bash
# Framework observability export — convert dry-run inventory to prometheus metrics, grafana dashboards, and dashboards JSON

set -euo pipefail

FACTORY_DIR="${1:-.}"
OUTPUT_DIR="${FACTORY_DIR}/output"
DRY_RUN_FILE="${OUTPUT_DIR}/dry_run_plan.yaml"

usage() {
  cat <<'EOF'
Usage: ./scripts/framework-observability-export.sh [factory_dir] [--format format] [--output dir]

Export framework deployment inventory to observability formats:
  - prometheus-metrics: Prometheus text exposition format
  - grafana-json: Grafana dashboard JSON
  - inventory-json: Complete inventory as JSON for custom processing
  - all: Generate all formats

Options:
  --format <fmt>     Output format: prometheus-metrics, grafana-json, inventory-json, all (default: all)
  --output <dir>     Output directory (default: factory_dir/output/observability)

Examples:
  # Generate all observability exports
  ./scripts/framework-observability-export.sh projects/erp_back/pre_releases/manifests/dev/factory

  # Generate only Prometheus metrics
  ./scripts/framework-observability-export.sh . --format prometheus-metrics

  # Export to custom directory
  ./scripts/framework-observability-export.sh . --output /var/lib/observability

Requirements:
  - dry_run_plan.yaml must exist in output/ directory
  - yq for YAML parsing
  - jq for JSON generation
EOF
  exit 0
}

# Parse arguments
FORMAT="all"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    --format) FORMAT="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    *)
      if [[ ! "$1" =~ ^- ]]; then
        FACTORY_DIR="$1"
        OUTPUT_DIR="${FACTORY_DIR}/output"
      fi
      shift
      ;;
  esac
done

# Verify prerequisites
for cmd in yq jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed" >&2
    exit 1
  fi
done

if [[ ! -f "$DRY_RUN_FILE" ]]; then
  echo "Error: $DRY_RUN_FILE not found" >&2
  echo "Run: koncept dry-run --factory $FACTORY_DIR" >&2
  exit 1
fi

# Create observability output directory
OBSERVABILITY_DIR="${OUTPUT_DIR}/observability"
mkdir -p "$OBSERVABILITY_DIR"

echo "[observability] Exporting framework inventory from $FACTORY_DIR"

# Extract inventory data
PROJECT=$(yq -r '.metadata.project' "$DRY_RUN_FILE" 2>/dev/null || echo "unknown")
VERSION=$(yq -r '.metadata.version' "$DRY_RUN_FILE" 2>/dev/null || echo "1.0.0")
GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

COMPONENT_COUNT=$(yq -r '.spec.inventory.components | length' "$DRY_RUN_FILE" 2>/dev/null || echo "0")
ACCESSORY_COUNT=$(yq -r '.spec.inventory.accessories | length' "$DRY_RUN_FILE" 2>/dev/null || echo "0")
NAMESPACE_COUNT=$(yq -r '.spec.inventory.namespaces | length' "$DRY_RUN_FILE" 2>/dev/null || echo "0")
DEPENDENCY_COUNT=$(yq -r '.spec.dependencies | length' "$DRY_RUN_FILE" 2>/dev/null || echo "0")

echo "[observability] Found: $COMPONENT_COUNT components, $ACCESSORY_COUNT accessories, $DEPENDENCY_COUNT dependencies"

# Generate Prometheus metrics
if [[ "$FORMAT" == "prometheus-metrics" || "$FORMAT" == "all" ]]; then
  echo "[observability] Generating Prometheus metrics..."

  PROM_FILE="${OBSERVABILITY_DIR}/metrics.txt"
  cat > "$PROM_FILE" <<EOF
# HELP idp_framework_components_total Total number of components deployed
# TYPE idp_framework_components_total gauge
idp_framework_components_total{project="$PROJECT",version="$VERSION"} $COMPONENT_COUNT

# HELP idp_framework_accessories_total Total number of accessories deployed
# TYPE idp_framework_accessories_total gauge
idp_framework_accessories_total{project="$PROJECT",version="$VERSION"} $ACCESSORY_COUNT

# HELP idp_framework_namespaces_total Total number of Kubernetes namespaces
# TYPE idp_framework_namespaces_total gauge
idp_framework_namespaces_total{project="$PROJECT",version="$VERSION"} $NAMESPACE_COUNT

# HELP idp_framework_dependencies_total Total number of inter-module dependencies
# TYPE idp_framework_dependencies_total gauge
idp_framework_dependencies_total{project="$PROJECT",version="$VERSION"} $DEPENDENCY_COUNT

# HELP idp_framework_info Framework deployment information
# TYPE idp_framework_info gauge
idp_framework_info{project="$PROJECT",version="$VERSION",generated_at="$GENERATED_AT"} 1
EOF

  echo "[observability] ✓ Prometheus metrics: $PROM_FILE"
fi

# Generate Grafana JSON dashboard
if [[ "$FORMAT" == "grafana-json" || "$FORMAT" == "all" ]]; then
  echo "[observability] Generating Grafana dashboard..."

  GRAFANA_FILE="${OBSERVABILITY_DIR}/grafana-dashboard.json"

  # Build component list for Grafana
  COMPONENT_NAMES=$(yq -r '.spec.inventory.components[] | .name' "$DRY_RUN_FILE" 2>/dev/null | jq -R . | jq -s '.' || echo '[]')
  ACCESSORY_NAMES=$(yq -r '.spec.inventory.accessories[] | .name' "$DRY_RUN_FILE" 2>/dev/null | jq -R . | jq -s '.' || echo '[]')

  cat > "$GRAFANA_FILE" <<'GRAFANA_TEMPLATE'
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {"type": "grafana", "uid": "-- Grafana --"},
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "description": "idp-concept framework deployment inventory and status",
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "fieldConfig": {
        "defaults": {"color": {"mode": "palette-classic"}, "custom": {}, "mappings": [], "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": null}]}},
        "overrides": []
      },
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
      "id": 1,
      "options": {"orientation": "auto", "reduceOptions": {"values": false, "fields": "", "calcs": ["lastNotNull"]}, "showThresholdLabels": false, "showThresholdMarkers": true},
      "pluginVersion": "10.0.0",
      "targets": [
        {
          "expr": "idp_framework_components_total + idp_framework_accessories_total",
          "legendFormat": "Total Modules",
          "refId": "A"
        }
      ],
      "title": "Total Framework Modules",
      "type": "gauge"
    },
    {
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "fieldConfig": {
        "defaults": {"custom": {}, "mappings": [], "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": null}]}},
        "overrides": []
      },
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
      "id": 2,
      "options": {"orientation": "auto", "reduceOptions": {"values": false, "fields": "", "calcs": ["lastNotNull"]}, "showThresholdLabels": false, "showThresholdMarkers": true},
      "pluginVersion": "10.0.0",
      "targets": [
        {
          "expr": "idp_framework_dependencies_total",
          "legendFormat": "Dependencies",
          "refId": "A"
        }
      ],
      "title": "Module Dependencies",
      "type": "gauge"
    },
    {
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "fieldConfig": {
        "defaults": {"custom": {}, "mappings": [], "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": null}]}},
        "overrides": []
      },
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
      "id": 3,
      "options": {"orientation": "auto", "reduceOptions": {"values": false, "fields": "", "calcs": ["lastNotNull"]}, "showThresholdLabels": false, "showThresholdMarkers": true},
      "pluginVersion": "10.0.0",
      "targets": [
        {
          "expr": "idp_framework_namespaces_total",
          "legendFormat": "Namespaces",
          "refId": "A"
        }
      ],
      "title": "Kubernetes Namespaces",
      "type": "gauge"
    }
  ],
  "refresh": "30s",
  "schemaVersion": 38,
  "style": "dark",
  "tags": ["idp-concept", "framework", "observability"],
  "templating": {"list": []},
  "time": {"from": "now-6h", "to": "now"},
  "timepicker": {},
  "timezone": "",
  "title": "IDP Concept Framework Deployment",
  "uid": "idp-framework-deployment",
  "version": 1
}
GRAFANA_TEMPLATE

  echo "[observability] ✓ Grafana dashboard: $GRAFANA_FILE"
fi

# Generate inventory JSON
if [[ "$FORMAT" == "inventory-json" || "$FORMAT" == "all" ]]; then
  echo "[observability] Generating inventory JSON..."

  JSON_FILE="${OBSERVABILITY_DIR}/inventory.json"
  {
    echo "{"
    echo "  \"project\": \"$PROJECT\","
    echo "  \"version\": \"$VERSION\","
    echo "  \"generated_at\": \"$GENERATED_AT\","
    echo "  \"summary\": {"
    echo "    \"components\": $COMPONENT_COUNT,"
    echo "    \"accessories\": $ACCESSORY_COUNT,"
    echo "    \"namespaces\": $NAMESPACE_COUNT,"
    echo "    \"dependencies\": $DEPENDENCY_COUNT"
    echo "  },"

    # Extract components
    echo "  \"components\": ["
    yq -r '.spec.inventory.components[] | "    { \"name\": \"\(.name)\", \"namespace\": \"\(.namespace)\", \"kind\": \"\(.kind)\" }"' "$DRY_RUN_FILE" 2>/dev/null | sed '$ s/,$//' || echo "  "
    echo "  ],"

    # Extract accessories
    echo "  \"accessories\": ["
    yq -r '.spec.inventory.accessories[] | "    { \"name\": \"\(.name)\", \"namespace\": \"\(.namespace)\", \"kind\": \"\(.kind)\" }"' "$DRY_RUN_FILE" 2>/dev/null | sed '$ s/,$//' || echo "  "
    echo "  ],"

    # Extract dependencies
    echo "  \"dependencies\": ["
    yq -r '.spec.dependencies[] | "    { \"from\": \"\(.from)\", \"to\": \"\(.to)\", \"dependencyKind\": \"\(.dependencyKind)\" }"' "$DRY_RUN_FILE" 2>/dev/null | sed '$ s/,$//' || echo "  "
    echo "  ]"
    echo "}"
  } > "$JSON_FILE"

  echo "[observability] ✓ Inventory JSON: $JSON_FILE"
fi

echo "[observability] Export complete: $OBSERVABILITY_DIR"
echo ""
echo "Next steps:"
echo "  1. Prometheus: Add metrics from $OBSERVABILITY_DIR/metrics.txt to scrape config"
echo "  2. Grafana: Import dashboard from $OBSERVABILITY_DIR/grafana-dashboard.json"
echo "  3. Custom: Use $OBSERVABILITY_DIR/inventory.json for custom integrations"

