#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

ROOTFS=${1:?usage: verify-rootfs.sh ROOTFS}
[[ -d "$ROOTFS/etc" ]] || die "invalid rootfs: $ROOTFS"

for path in \
  etc/os-release \
  etc/agent-image-release \
  usr/bin/curl \
  usr/bin/git \
  usr/bin/jq \
  usr/bin/tailscale \
  usr/sbin/tailscaled \
  usr/local/bin/codex \
  usr/bin/codex \
  etc/codex-cli-release; do
  [[ -e "$ROOTFS/$path" || -L "$ROOTFS/$path" ]] || die "missing required path: /$path"
done

[[ ! -s "$ROOTFS/etc/machine-id" ]] || die '/etc/machine-id is not empty'
[[ ! -e "$ROOTFS/var/lib/dbus/machine-id" ]] || die 'dbus machine-id is present'
[[ ! -e "$ROOTFS/var/lib/tailscale/tailscaled.state" ]] || die 'Tailscale identity is present'
[[ ! -e "$ROOTFS/usr/sbin/sshd" ]] || die 'OpenSSH server is present'
[[ ! -e "$ROOTFS/root/.codex/auth.json" ]] || die 'Codex authentication is present'
mkdir -p "$ROOTFS/tmp/codex-verify"
chroot "$ROOTFS" /usr/bin/env CODEX_HOME=/tmp/codex-verify \
  /usr/bin/codex --version >/dev/null 2>&1
rm -rf "$ROOTFS/tmp/codex-verify"

if find "$ROOTFS/etc/ssh" -maxdepth 1 -type f -name 'ssh_host_*_key' -print -quit 2>/dev/null | grep -q .; then
  die 'SSH host private key is present'
fi

if grep -RIlE --exclude='*.list' --exclude='*.gpg' \
  '(tskey-(auth|client)-|gh[pousr]_[A-Za-z0-9_]{20,}|BEGIN (OPENSSH|RSA|EC) PRIVATE KEY)' \
  "$ROOTFS/etc" "$ROOTFS/root" 2>/dev/null | grep -q .; then
  die 'possible credential found in rootfs'
fi

log 'rootfs verification passed'
