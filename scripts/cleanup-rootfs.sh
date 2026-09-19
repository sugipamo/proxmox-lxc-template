#!/usr/bin/env bash
set -Eeuo pipefail

ROOTFS=${1:?usage: cleanup-rootfs.sh ROOTFS}
[[ $EUID -eq 0 ]] || { echo 'cleanup must run as root' >&2; exit 1; }
[[ -d "$ROOTFS/etc" ]] || { echo "invalid rootfs: $ROOTFS" >&2; exit 1; }

# Never clone machine or Tailscale identities.
rm -f "$ROOTFS/etc/machine-id"
: >"$ROOTFS/etc/machine-id"
rm -f "$ROOTFS/var/lib/dbus/machine-id"
rm -rf "$ROOTFS/var/lib/tailscale"/*

# Proxmox creates host keys when needed. The profile intentionally has no sshd,
# but clean these defensively if a future package adds it.
rm -f "$ROOTFS/etc/ssh/ssh_host_"*
rm -f "$ROOTFS/root/.bash_history"
find "$ROOTFS/home" -xdev -type f -name '.bash_history' -delete 2>/dev/null || true
rm -rf "$ROOTFS/var/lib/dhcp"/* "$ROOTFS/var/lib/NetworkManager"/* 2>/dev/null || true
rm -rf "$ROOTFS/var/log"/* "$ROOTFS/var/tmp"/* "$ROOTFS/tmp"/*
rm -rf "$ROOTFS/var/lib/apt/lists"/* "$ROOTFS/var/cache/apt/archives"/*

# Remove the temporary build-time service start inhibitor.
rm -f "$ROOTFS/usr/sbin/policy-rc.d"
