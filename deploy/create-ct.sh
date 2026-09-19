#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: create-ct.sh --ctid ID --hostname NAME --template VOLUME [options]

Required:
  --ctid ID             Unused Proxmox CT ID
  --hostname NAME       Unique CT hostname
  --template VOLUME     Template volume, e.g. local:vztmpl/agent-...tar.zst

Options:
  --storage NAME        Rootfs storage (default: local-lvm)
  --bridge NAME         Network bridge (default: vmbr1)
  --cores N             CPU cores (default: 2)
  --memory MB           Memory in MiB (default: 1024)
  --swap MB             Swap in MiB (default: 512)
  --disk GB             Rootfs size in GiB (default: 8)
  --nameserver IP       DNS server, normally the OPNsense LAN IP
  --start               Start the CT after creation
EOF
}

CTID= HOSTNAME= TEMPLATE= NAMESERVER=
STORAGE=local-lvm BRIDGE=vmbr1 CORES=2 MEMORY=1024 SWAP=512 DISK=8 START=0
while (($#)); do
  case $1 in
    --ctid) CTID=${2:?}; shift 2 ;;
    --hostname) HOSTNAME=${2:?}; shift 2 ;;
    --template) TEMPLATE=${2:?}; shift 2 ;;
    --storage) STORAGE=${2:?}; shift 2 ;;
    --bridge) BRIDGE=${2:?}; shift 2 ;;
    --cores) CORES=${2:?}; shift 2 ;;
    --memory) MEMORY=${2:?}; shift 2 ;;
    --swap) SWAP=${2:?}; shift 2 ;;
    --disk) DISK=${2:?}; shift 2 ;;
    --nameserver) NAMESERVER=${2:?}; shift 2 ;;
    --start) START=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ $EUID -eq 0 ]] || { echo 'run on a Proxmox host as root' >&2; exit 1; }
command -v pct >/dev/null || { echo 'pct not found; run this on Proxmox VE' >&2; exit 1; }
[[ $CTID =~ ^[1-9][0-9]*$ ]] || { echo '--ctid must be numeric' >&2; exit 2; }
[[ -n $HOSTNAME && -n $TEMPLATE ]] || { usage >&2; exit 2; }
if pct status "$CTID" >/dev/null 2>&1; then
  echo "CT $CTID already exists" >&2
  exit 1
fi

args=(
  "$CTID" "$TEMPLATE"
  --unprivileged 1
  --hostname "$HOSTNAME"
  --ostype debian
  --arch amd64
  --cores "$CORES"
  --memory "$MEMORY"
  --swap "$SWAP"
  --rootfs "$STORAGE:$DISK"
  --net0 "name=eth0,bridge=$BRIDGE,ip=dhcp,type=veth"
  --features keyctl=1,nesting=1
  --onboot 1
)
[[ -z $NAMESERVER ]] || args+=(--nameserver "$NAMESERVER")

pct create "${args[@]}"
pct set "$CTID" --dev0 /dev/net/tun

if ((START)); then
  pct start "$CTID"
fi

echo "Created CT $CTID. Register Tailscale inside the CT; never bake an auth key into the image."
