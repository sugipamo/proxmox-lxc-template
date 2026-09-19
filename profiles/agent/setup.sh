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
