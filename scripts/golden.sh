#!/usr/bin/env bash
# Golden render snapshot management for reference projects.
#
# Golden files are committed expected-render snapshots used to detect rendering
# drift. A framework or project change that alters rendered output will fail
# 'check' until the change is reviewed and accepted with 'update'.
#
# Usage:
#   scripts/golden.sh check    # render and diff against committed goldens (CI)
#   scripts/golden.sh update   # re-render and overwrite committed goldens
#
# Requires the koncept Go CLI. If a prebuilt binary is not on PATH the script
# builds one into cmd/koncept/bin/koncept.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION="${1:-check}"

case "$ACTION" in
  check|update) ;;
  *) echo "usage: $0 [check|update]" >&2; exit 2 ;;
esac

KONCEPT="${KONCEPT:-}"
if [[ -z "$KONCEPT" ]]; then
  if command -v koncept >/dev/null 2>&1; then
    KONCEPT="$(command -v koncept)"
  else
    printf '==> Building koncept CLI\n'
    (cd "$ROOT_DIR/cmd/koncept" && go build -o bin/koncept .)
    KONCEPT="$ROOT_DIR/cmd/koncept/bin/koncept"
  fi
fi

# Reference factories and the formats each one snapshots.
# Format: "<factory-dir>|<comma-separated-formats>"
TARGETS=(
  "projects/erp_back/pre_releases/manifests/dev/factory|yaml,argocd"
  "projects/erp_back/pre_releases/manifests/stg/factory|yaml"
  "projects/erp_back/releases/v1_0_0_production/factory|yaml"
)

status=0
for target in "${TARGETS[@]}"; do
  factory="${target%%|*}"
  formats="${target##*|}"
  printf '==> golden %s: %s (%s)\n' "$ACTION" "$factory" "$formats"
  if ! "$KONCEPT" --factory "$ROOT_DIR/$factory" golden "$ACTION" --formats "$formats"; then
    status=1
  fi
done

if [[ "$status" -ne 0 ]]; then
  printf '\n==> Golden %s failed. Review the diff above; run "scripts/golden.sh update" to accept intended changes.\n' "$ACTION" >&2
fi
exit "$status"
