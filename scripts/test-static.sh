#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
find "$REPO_ROOT/scripts" "$REPO_ROOT/profiles" -type f -name '*.sh' -print0 \
  | xargs -0 -r -n1 bash -n

if command -v shellcheck >/dev/null 2>&1; then
  find "$REPO_ROOT/scripts" "$REPO_ROOT/profiles" -type f -name '*.sh' -print0 \
    | xargs -0 -r shellcheck
fi

echo 'static checks passed'
