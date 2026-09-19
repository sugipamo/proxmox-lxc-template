#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

install -d -m 0755 /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg \
  -o /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list \
  -o /etc/apt/sources.list.d/tailscale.list

apt-get update
apt-get install -y --no-install-recommends tailscale
# The Proxmox Debian base includes sshd. Agent administration uses Tailscale
# SSH, so retain the client while removing the conventional SSH server.
apt-get purge -y openssh-server openssh-sftp-server ssh
apt-get autoremove -y
systemctl enable tailscaled.service

CODEX_VERSION=$(cat /tmp/codex.version)
curl -fsSL https://chatgpt.com/codex/install.sh -o /tmp/install-codex.sh
CODEX_RELEASE="$CODEX_VERSION" \
CODEX_NON_INTERACTIVE=1 \
CODEX_INSTALL_DIR=/usr/local/bin \
CODEX_HOME=/usr/local/lib/codex \
  sh /tmp/install-codex.sh --release "$CODEX_VERSION"
rm -f /tmp/install-codex.sh
install -d -m 0700 /root/.codex
/usr/local/bin/codex --version
# Tailscale SSH uses a minimal root PATH without /usr/local/bin.
ln -sfn /usr/local/bin/codex /usr/bin/codex
printf '%s\n' "$CODEX_VERSION" >/etc/codex-cli-release
