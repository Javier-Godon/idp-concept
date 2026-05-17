#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf "==> Running scoped KCL lint\n"
(
  cd "$ROOT_DIR/framework"
  kcl lint builders/*.k models/*.k models/modules/*.k procedures/*.k templates/*.k assembly/*.k factory/seed.k factory/render_entry.k factory/conventions.k
  while IFS= read -r version_dir; do
    if compgen -G "$version_dir/*.k" > /dev/null; then
      kcl lint "$version_dir"/*.k
    fi
  done < <(find templates -type d -name 'v*' | sort)
  kcl lint custom/*.k
  kcl lint custom/helm/*.k
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

