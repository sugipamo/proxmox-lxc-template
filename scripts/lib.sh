#!/usr/bin/env bash

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

read_packages() {
  local file=$1
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$file"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}
