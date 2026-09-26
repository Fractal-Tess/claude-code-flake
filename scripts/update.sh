#!/usr/bin/env bash
set -euo pipefail

readonly BASE_URL="https://downloads.claude.ai/claude-code-releases"
readonly MANIFEST="packages/manifest.zst.json"
readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required tool: $1"
}

main() {
  local requested_version="${1:-}"
  local current_version version manifest_json

  require_tool curl
  require_tool jq
  require_tool nix
  require_tool sed

  cd "$ROOT_DIR"
  current_version="$(jq -r '.version' "$MANIFEST")"
  [[ -n "$current_version" && "$current_version" != "null" ]] || fail "could not read the packaged version"

  if [[ -n "$requested_version" ]]; then
    version="${requested_version#v}"
  else
    version="$(curl --silent --show-error --fail --location "${BASE_URL}/latest")"
  fi
  [[ -n "$version" ]] || fail "could not determine the upstream version"

  printf 'Current version: %s\nLatest version:  %s\n' "$current_version" "$version"
  if [[ "$current_version" == "$version" ]]; then
    printf 'Already up to date.\n'
    exit 0
  fi

  # The manifest carries the per-platform asset names and SHA-256 checksums that
  # the package reads directly, so replacing it is the whole update.
  manifest_json="$(curl --silent --show-error --fail --location "${BASE_URL}/${version}/manifest.zst.json")"
  [[ "$(jq -r '.version' <<<"$manifest_json")" == "$version" ]] || fail "manifest does not describe v${version}"

  local key
  for key in linux-x64 linux-arm64; do
    jq -e --arg key "$key" '.platforms[$key].checksum' <<<"$manifest_json" >/dev/null \
      || fail "manifest is missing a ${key} checksum"
  done

  printf '%s\n' "$manifest_json" > "$MANIFEST"

  sed -i \
    -e "s|claude--code-${current_version}|claude--code-${version}|g" \
    -e "s|Claude Code ${current_version}|Claude Code ${version}|g" \
    -e "s|blob/v${current_version}/CHANGELOG.md|blob/v${version}/CHANGELOG.md|g" \
    -e "s|./scripts/update.sh ${current_version}|./scripts/update.sh ${version}|g" \
    README.md

  nix flake check --print-build-logs
  nix build .#claude-code --print-build-logs
  test -x result/bin/claude || fail "built package does not contain bin/claude"

  printf 'Updated Claude Code from %s to %s.\n' "$current_version" "$version"
}

main "$@"
