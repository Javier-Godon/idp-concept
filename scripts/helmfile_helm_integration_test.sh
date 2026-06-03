#!/bin/bash
# helmfile_helm_integration_test.sh
# Validates generated Helmfile with real helm template execution
# Usage: ./helmfile_helm_integration_test.sh [helmfile_path] [output_dir]

set -e

HELMFILE_PATH="${1:-output/helmfile.yaml}"
OUTPUT_DIR="${2:-output/helm-validation}"
CHARTS_DIR="${3:-output/charts}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v helm &> /dev/null; then
        log_error "helm CLI not found. Install with: brew install helm"
        return 1
    fi

    if ! command -v yq &> /dev/null; then
        log_warn "yq not found. Some validations will be skipped."
        return 0
    fi

    if command -v kubeconform &> /dev/null; then
        log_success "kubeconform available for schema validation"
    else
        log_warn "kubeconform not found. Schema validation will be skipped."
    fi

    return 0
}

# Verify Helmfile exists and parse
validate_helmfile() {
    log_info "Validating Helmfile syntax..."

    if [ ! -f "$HELMFILE_PATH" ]; then
        log_error "Helmfile not found at $HELMFILE_PATH"
        return 1
    fi

    # Check basic YAML syntax
    if ! yq eval '.' "$HELMFILE_PATH" > /dev/null 2>&1; then
        log_error "Helmfile has invalid YAML syntax"
        return 1
    fi

    log_success "Helmfile syntax valid"
    return 0
}

# Template each release with helm
template_helm_releases() {
    log_info "Templating Helm releases..."

    mkdir -p "$OUTPUT_DIR"

    # Get all release names
    local releases=$(yq eval '.releases[].name' "$HELMFILE_PATH" 2>/dev/null || echo "")

    if [ -z "$releases" ]; then
        log_warn "No releases found in Helmfile"
        return 0
    fi

    local template_count=0
    local failed_releases=()

    while IFS= read -r release; do
        if [ -z "$release" ]; then continue; fi

        log_info "Processing release: $release"

        # Extract chart reference
        local chart=$(yq eval ".releases[] | select(.name == \"$release\") | .chart" "$HELMFILE_PATH")
        local namespace=$(yq eval ".releases[] | select(.name == \"$release\") | .namespace" "$HELMFILE_PATH")

        if [ -z "$chart" ]; then
            log_warn "  No chart found for release $release, skipping"
            continue
        fi

        namespace="${namespace:-default}"

        # Create temporary values file
        local values_file="$OUTPUT_DIR/values-${release}.yaml"
        yq eval ".releases[] | select(.name == \"$release\") | .values" "$HELMFILE_PATH" > "$values_file" 2>/dev/null || true

        # Template the chart
        local output_file="$OUTPUT_DIR/templates-${release}.yaml"
        if helm template "$release" "$chart" \
            -n "$namespace" \
            -f "$values_file" 2>/dev/null \
            > "$output_file"; then

            log_success "  Templated: $chart → $output_file"
            ((template_count++))
        else
            log_error "  Failed to template $chart"
            failed_releases+=("$release")
        fi
    done <<< "$releases"

    if [ ${#failed_releases[@]} -gt 0 ]; then
        log_error "Failed to template ${#failed_releases[@]} release(s): ${failed_releases[*]}"
        return 1
    fi

    log_success "Templated $template_count releases successfully"
    return 0
}

# Validate templated manifests
validate_manifests() {
    log_info "Validating templated manifests..."

    if ! command -v kubeconform &> /dev/null; then
        log_warn "kubeconform not available, skipping manifest validation"
        return 0
    fi

    local validation_failed=0

    for template_file in "$OUTPUT_DIR"/templates-*.yaml; do
        if [ ! -f "$template_file" ]; then continue; fi

        local release_name=$(basename "$template_file" | sed 's/templates-\(.*\)\.yaml/\1/')
        log_info "Validating release: $release_name"

        if kubeconform -summary "$template_file" > /dev/null 2>&1; then
            log_success "  Manifests valid"
        else
            log_error "  Schema validation failed"
            kubeconform -output json "$template_file" | head -20 || true
            validation_failed=1
        fi
    done

    if [ $validation_failed -eq 1 ]; then
        return 1
    fi

    return 0
}

# Check dependency ordering
validate_dependencies() {
    log_info "Checking dependency ordering..."

    # Extract needs entries
    local needs_found=0
    local needs=$(yq eval '.releases[].needs[]' "$HELMFILE_PATH" 2>/dev/null | sort -u)

    if [ -z "$needs" ]; then
        log_info "  No dependencies found"
        return 0
    fi

    # For each need, verify it references an existing release
    local release_names=$(yq eval '.releases[].name' "$HELMFILE_PATH" | sort -u)
    local missing_deps=0

    while IFS= read -r need; do
        if [ -z "$need" ]; then continue; fi

        # Extract namespace/release from needs entry (format: namespace/release-name)
        local needed_release=$(echo "$need" | awk -F'/' '{print $NF}')

        if ! echo "$release_names" | grep -q "^${needed_release}$"; then
            log_warn "  Unresolved dependency: $need (release $needed_release not found)"
            ((missing_deps++))
        else
            log_success "  Dependency resolved: $need"
        fi
        ((needs_found++))
    done <<< "$needs"

    if [ $missing_deps -gt 0 ]; then
        log_error "Found $missing_deps missing dependencies"
        return 1
    fi

    if [ $needs_found -gt 0 ]; then
        log_success "All $needs_found dependencies verified"
    fi

    return 0
}

# Generate summary report
generate_report() {
    log_info "Generating validation report..."

    local reportfile="$OUTPUT_DIR/validation-report.txt"

    cat > "$reportfile" <<EOF
Helmfile Validation Report
==========================
Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
Helmfile: $HELMFILE_PATH

Test Results:
EOF

    # Count templates
    local template_count=$(ls -1 "$OUTPUT_DIR"/templates-*.yaml 2>/dev/null | wc -l)
    echo "  - Templates generated: $template_count" >> "$reportfile"

    # Add template list
    if [ $template_count -gt 0 ]; then
        echo "" >> "$reportfile"
        echo "Templates:" >> "$reportfile"
        ls -1 "$OUTPUT_DIR"/templates-*.yaml | while read f; do
            local lines=$(wc -l < "$f")
            echo "  - $(basename $f): $lines lines" >> "$reportfile"
        done
    fi

    echo "" >> "$reportfile"
    echo "Artifacts:" >> "$reportfile"
    echo "  - Output directory: $OUTPUT_DIR" >> "$reportfile"
    echo "  - Full report: $reportfile" >> "$reportfile"

    log_success "Report written to $reportfile"
    cat "$reportfile"
}

# Main execution
main() {
    log_info "Starting Helmfile validation..."
    log_info "Helmfile: $HELMFILE_PATH"
    log_info "Output: $OUTPUT_DIR"

    check_prerequisites || exit 1
    validate_helmfile || exit 1
    validate_dependencies || exit 1
    template_helm_releases || exit 1
    validate_manifests || exit 1
    generate_report

    log_success "All validations passed ✓"
    exit 0
}

main "$@"

