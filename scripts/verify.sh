#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf "==> Running scoped KCL lint\n"
(
  cd "$ROOT_DIR/framework"
  shopt -s nullglob
  for source_file in builders/*.k models/*.k models/modules/*.k procedures/*.k templates/*.k assembly/*.k factory/seed.k factory/render_entry.k factory/conventions.k custom/*.k custom/helm/*.k; do
    kcl lint "$source_file"
  done
  while IFS= read -r source_file; do
    kcl lint "$source_file"
  done < <(find templates -type f -name '*.k' | sort)
  for fixture in tests/acceptance/cases/*.k; do
    kcl lint "$fixture"
  done
)

printf "==> Rendering acceptance template fixtures\n"
(
  cd "$ROOT_DIR/framework"
  for fixture in tests/acceptance/cases/*_workload.k; do
    printf "   - %s\n" "$fixture"
    kcl run "$fixture" >/tmp/idp-concept-acceptance-"$(basename "$fixture" .k)".yaml
  done
)

printf "==> Running framework tests\n"
(
  cd "$ROOT_DIR/framework"
  kcl test ./...
)

printf "==> Running render smoke checks (erp_back/dev factory)\n"
(
  cd "$ROOT_DIR/projects/erp_back/pre_releases/manifests/dev/factory"
  outputs=(yaml argocd helmfile helm kustomize timoni crossplane backstage)
  for output in "${outputs[@]}"; do
    printf "   - %s\n" "$output"
    kcl run render.k -D output="$output" >/tmp/idp-concept-render-"$output".out
  done
)

printf "==> Verification complete\n"

