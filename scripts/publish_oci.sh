#!/usr/bin/env bash
#
# publish_oci.sh — publish idp-concept OCI artifacts to GitHub Container Registry.
#
# Credentials are ALWAYS read from the local, git-ignored ./credentials folder.
# This script never prompts for, echoes, or logs a token, and it must never be
# given a token on the command line.
#
# Expected credentials file (git-ignored, see .gitignore):
#
#   credentials/ghcr.env
#   ----------------------------------------------------------------
#   # GitHub Container Registry credentials (local only — never commit)
#   GHCR_USERNAME=javier-godon
#   CR_PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx   # scopes: write:packages,read:packages
#   ----------------------------------------------------------------
#
# Usage:
#   scripts/publish_oci.sh image      [VERSION]   # build + push the koncept CLI container image
#   scripts/publish_oci.sh framework  [VERSION]   # package + push the framework KCL module (oras)
#   scripts/publish_oci.sh all        [VERSION]   # both of the above
#
# VERSION defaults to `git describe --tags` (e.g. v1.0.0).
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREDENTIALS_FILE="${REPO_ROOT}/credentials/ghcr.env"

REGISTRY="ghcr.io"
## Owner namespace on GHCR (lowercase). Repository: https://github.com/Javier-Godon/idp-concept
OWNER="javier-godon"
CLI_IMAGE="${REGISTRY}/${OWNER}/idp-concept/koncept"
FRAMEWORK_PACKAGE="${REGISTRY}/${OWNER}/idp-concept-framework"
FRAMEWORK_MEDIA_TYPE="application/vnd.idp-concept.framework.v1+gzip"

log()  { printf '\033[1;34m[publish]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[publish] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

load_credentials() {
  [[ -f "${CREDENTIALS_FILE}" ]] || fail "missing ${CREDENTIALS_FILE} (see header of this script for the expected format)"
  # shellcheck disable=SC1090
  set -a; source "${CREDENTIALS_FILE}"; set +a
  : "${GHCR_USERNAME:=${OWNER}}"
  [[ -n "${CR_PAT:-}" ]] || fail "CR_PAT is not set in ${CREDENTIALS_FILE}"
}

## Authenticate without ever printing the token.
login_docker() {
  log "Logging in to ${REGISTRY} as ${GHCR_USERNAME} (docker)…"
  printf '%s' "${CR_PAT}" | docker login "${REGISTRY}" -u "${GHCR_USERNAME}" --password-stdin >/dev/null
}
login_oras() {
  command -v oras >/dev/null 2>&1 || fail "oras CLI not found (see docs/GHCR_PUBLISHING_GUIDE.md §2.2)"
  log "Logging in to ${REGISTRY} as ${GHCR_USERNAME} (oras)…"
  printf '%s' "${CR_PAT}" | oras login "${REGISTRY}" -u "${GHCR_USERNAME}" --password-stdin >/dev/null
}

resolve_version() {
  local v="${1:-}"
  if [[ -z "${v}" ]]; then
    v="$(git -C "${REPO_ROOT}" describe --tags --always --dirty 2>/dev/null || echo dev)"
  fi
  printf '%s' "${v}"
}

publish_image() {
  local version; version="$(resolve_version "${1:-}")"
  login_docker
  log "Building koncept CLI image ${CLI_IMAGE}:${version}"
  docker build -f "${REPO_ROOT}/cmd/koncept/Dockerfile" \
    --build-arg "VERSION=${version}" \
    --build-arg "BUILD_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    -t "${CLI_IMAGE}:${version}" \
    -t "${CLI_IMAGE}:latest" \
    "${REPO_ROOT}"
  log "Pushing ${CLI_IMAGE}:${version} and :latest"
  docker push "${CLI_IMAGE}:${version}"
  docker push "${CLI_IMAGE}:latest"
  log "Published CLI image: ${CLI_IMAGE}:${version}"
}

publish_framework() {
  local version; version="$(resolve_version "${1:-}")"
  login_oras
  local workdir; workdir="$(mktemp -d)"
  trap 'rm -rf "${workdir}"' RETURN
  local tarball="${workdir}/framework-${version}.tar.gz"
  log "Packaging framework/ → ${tarball}"
  tar --exclude='.git' --exclude='*.lock' --exclude='output' \
      --exclude='node_modules' --exclude='**/test_to_delete' \
      -czf "${tarball}" -C "${REPO_ROOT}" framework/
   log "Pushing ${FRAMEWORK_PACKAGE}:${version}"
   oras push "${FRAMEWORK_PACKAGE}:${version}" \
     --disable-path-validation \
     "${tarball}:${FRAMEWORK_MEDIA_TYPE}"
  log "Published framework package: ${FRAMEWORK_PACKAGE}:${version}"
  log "Consume with: framework = \"oras://${FRAMEWORK_PACKAGE}:${version}\""
}

main() {
  local target="${1:-}"; shift || true
  case "${target}" in
    ""|-h|--help)
      grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'
      return 0
      ;;
  esac
  load_credentials
  case "${target}" in
    image)     publish_image "${1:-}" ;;
    framework) publish_framework "${1:-}" ;;
    all)       publish_image "${1:-}"; publish_framework "${1:-}" ;;
    *) fail "unknown target '${target}' (expected: image | framework | all)" ;;
  esac
}

main "$@"




