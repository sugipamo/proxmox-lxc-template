#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

ARCHIVE=${1:?usage: verify-archive.sh ARCHIVE}
[[ -f "$ARCHIVE" ]] || die "archive not found: $ARCHIVE"
require_command tar
require_command zstd

mapfile -t entries < <(tar --zstd -tf "$ARCHIVE")
((${#entries[@]} > 0)) || die 'archive is empty'

for entry in "${entries[@]}"; do
  [[ $entry != /* ]] || die "absolute archive path: $entry"
  [[ $entry != ../* && $entry != */../* ]] || die "traversal archive path: $entry"
done

for required in \
  './etc/os-release' \
  './etc/agent-image-release' \
  './etc/codex-cli-release' \
  './usr/bin/tailscale' \
  './usr/local/bin/codex'; do
  found=0
  for entry in "${entries[@]}"; do
    if [[ $entry == "$required" ]]; then
      found=1
      break
    fi
  done
  ((found)) || die "missing archive entry: $required"
done

log 'archive verification passed'
