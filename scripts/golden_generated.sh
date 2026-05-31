#!/usr/bin/env bash
# Golden render snapshots for CLI-generated project scaffolds.
#
# Unlike scripts/golden.sh (which guards hand-authored reference factories such
# as erp_back), this gate guards what the Go CLI *generates*: it scaffolds each
# supported golden-path combination with `koncept init project` plus
# `koncept init module --wire`, renders Tier-1 YAML, and diffs the result against
# a committed snapshot. A change to the scaffolding templates, the wiring logic,
# or the framework templates these combos use will fail 'check' until reviewed
# and accepted with 'update'.
#
# Only the rendered YAML is committed (one file per combo), not the whole
# generated project tree, so the maintainer's accept-the-diff burden stays
# proportional to value.
#
# Usage:
#   scripts/golden_generated.sh check    # render combos and diff committed snapshots (CI)
#   scripts/golden_generated.sh update   # re-render and overwrite committed snapshots
#
# Requires the koncept Go CLI and the kcl compiler. If a prebuilt koncept binary
# is not on PATH the script builds one into cmd/koncept/bin/koncept.
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

# Resolve to an absolute path: the render/wire steps run inside 'cd' subshells.
if [[ "$KONCEPT" != /* ]]; then
  KONCEPT="$(cd "$(dirname "$KONCEPT")" && pwd)/$(basename "$KONCEPT")"
fi

GOLDEN_DIR="$ROOT_DIR/tests/golden_generated"

# Generated golden-path combinations.
# Format: "<combo-name>|<space-separated module types to wire>"
# An empty module list means a webapp-only project.
COMBOS=(
  "webapp|"
  "webapp-postgres|postgres"
  "webapp-redis|redis"
  "webapp-kafka|kafka"
)

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# Mirror the repo layout so the generated projects resolve the framework via the
# standard '../../framework' relative path used by 'koncept init project'.
ln -s "$ROOT_DIR/framework" "$WORK/framework"
mkdir -p "$WORK/projects"

FACTORY_REL="pre_releases/manifests/dev/factory"

status=0
for entry in "${COMBOS[@]}"; do
  name="${entry%%|*}"
  modules="${entry##*|}"
  slug="${name//-/_}"
  printf '==> golden-generated %s: %s\n' "$ACTION" "$name"

  if ! "$KONCEPT" init project "$name" --dest "$WORK/projects" --validate=false >/dev/null 2>&1; then
    printf '   ❌ scaffold failed for %s\n' "$name" >&2
    status=1
    continue
  fi

  project_dir="$WORK/projects/$slug"
  wire_ok=1
  for mtype in $modules; do
    if ! (cd "$project_dir" && "$KONCEPT" init module "$mtype" "$name-$mtype" --wire >/dev/null 2>&1); then
      printf '   ❌ wire %s failed for %s\n' "$mtype" "$name" >&2
      wire_ok=0
      break
    fi
  done
  [[ "$wire_ok" -eq 1 ]] || { status=1; continue; }

  out_dir="$WORK/out/$slug"
  if ! (cd "$project_dir" && "$KONCEPT" --factory "$FACTORY_REL" --output "$out_dir" render yaml >/dev/null 2>&1); then
    printf '   ❌ render failed for %s\n' "$name" >&2
    status=1
    continue
  fi

  rendered="$out_dir/kubernetes_manifests.yaml"
  golden="$GOLDEN_DIR/$name/manifests.yaml"

  if [[ "$ACTION" == "update" ]]; then
    mkdir -p "$(dirname "$golden")"
    cp "$rendered" "$golden"
    printf '   ✅ updated %s\n' "${golden#"$ROOT_DIR/"}"
    continue
  fi

  if [[ ! -f "$golden" ]]; then
    printf '   ❌ missing golden snapshot: %s (run "scripts/golden_generated.sh update")\n' \
      "${golden#"$ROOT_DIR/"}" >&2
    status=1
    continue
  fi

  if diff -u "$golden" "$rendered" >"$WORK/diff.txt"; then
    printf '   ✅ matches %s\n' "${golden#"$ROOT_DIR/"}"
  else
    printf '   ❌ drift in %s\n' "${golden#"$ROOT_DIR/"}" >&2
    sed 's/^/      /' "$WORK/diff.txt" >&2
    status=1
  fi
done

if [[ "$status" -ne 0 && "$ACTION" == "check" ]]; then
  printf '\n==> Golden-generated check failed. Review the diff above; run "scripts/golden_generated.sh update" to accept intended changes.\n' >&2
fi
exit "$status"
