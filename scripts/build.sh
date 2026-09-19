#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

PROFILE=${PROFILE:-agent}
VERSION=${VERSION:-0.1.0}
LOCK_FILE=${LOCK_FILE:-$REPO_ROOT/bases/debian13-amd64.lock}
WORK_DIR=${WORK_DIR:-$REPO_ROOT/work}
DIST_DIR=${DIST_DIR:-$REPO_ROOT/dist}
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(git -C "$REPO_ROOT" log -1 --format=%ct 2>/dev/null || date +%s)}

[[ $EUID -eq 0 ]] || die 'build must run as root (chroot and mounts are required)'
[[ -f "$LOCK_FILE" ]] || die "lock file not found: $LOCK_FILE"
[[ -d "$REPO_ROOT/profiles/$PROFILE" ]] || die "unknown profile: $PROFILE"
for command in curl sha256sum tar zstd chroot mountpoint git jq; do require_command "$command"; done

# The lock file is maintained in this repository and contains shell assignments only.
# shellcheck disable=SC1090
source "$LOCK_FILE"
OUTPUT_BASENAME="${PROFILE}-debian${BASE_VERSION}-${BASE_ARCH}-v${VERSION}"
DOWNLOAD_DIR="$WORK_DIR/downloads"
ROOTFS="$WORK_DIR/rootfs-$PROFILE"
BASE_ARCHIVE="$DOWNLOAD_DIR/$BASE_FILENAME"
OUTPUT_ARCHIVE="$DIST_DIR/$OUTPUT_BASENAME.tar.zst"
MOUNTS=()

cleanup() {
  local index
  for ((index=${#MOUNTS[@]}-1; index>=0; index--)); do
    if mountpoint -q "${MOUNTS[$index]}"; then
      umount -l "${MOUNTS[$index]}" || true
    fi
  done
}
trap cleanup EXIT INT TERM

mkdir -p "$DOWNLOAD_DIR" "$DIST_DIR"
rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"

if [[ ! -f "$BASE_ARCHIVE" ]] || ! echo "$BASE_SHA256  $BASE_ARCHIVE" | sha256sum -c --status; then
  log "downloading $BASE_FILENAME"
  curl --fail --location --retry 3 --output "$BASE_ARCHIVE.tmp" "$BASE_URL"
  mv "$BASE_ARCHIVE.tmp" "$BASE_ARCHIVE"
fi
echo "$BASE_SHA256  $BASE_ARCHIVE" | sha256sum -c

log 'extracting base rootfs'
tar --zstd --numeric-owner -xpf "$BASE_ARCHIVE" -C "$ROOTFS"

cp --dereference /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
printf '#!/bin/sh\nexit 101\n' >"$ROOTFS/usr/sbin/policy-rc.d"
chmod 0755 "$ROOTFS/usr/sbin/policy-rc.d"

for mount_spec in 'proc:proc' 'sysfs:sys' 'none:dev'; do
  mount_type=${mount_spec%%:*}
  target=${mount_spec#*:}
  mkdir -p "$ROOTFS/$target"
  if [[ $mount_type == none ]]; then
    mount --rbind /dev "$ROOTFS/$target"
    mount --make-rslave "$ROOTFS/$target"
  else
    mount -t "$mount_type" "$mount_type" "$ROOTFS/$target"
  fi
  MOUNTS+=("$ROOTFS/$target")
done

mapfile -t packages < <(cat \
  <(read_packages "$REPO_ROOT/common/packages.txt") \
  <(read_packages "$REPO_ROOT/profiles/$PROFILE/packages.txt"))
log 'installing Debian packages'
chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get update
if ((${#packages[@]})); then
  chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends "${packages[@]}"
fi

install -m 0755 "$REPO_ROOT/profiles/$PROFILE/setup.sh" "$ROOTFS/tmp/profile-setup.sh"
chroot "$ROOTFS" /tmp/profile-setup.sh
rm -f "$ROOTFS/tmp/profile-setup.sh"

GIT_COMMIT=$(git -C "$REPO_ROOT" rev-parse --verify HEAD 2>/dev/null || true)
GIT_COMMIT=${GIT_COMMIT:-unknown}
BUILD_DATE=$(date --utc --date="@$SOURCE_DATE_EPOCH" +%Y-%m-%dT%H:%M:%SZ)
cat >"$ROOTFS/etc/agent-image-release" <<EOF
PROFILE=$PROFILE
VERSION=$VERSION
BASE_IMAGE=$BASE_FILENAME
GIT_COMMIT=$GIT_COMMIT
BUILD_DATE=$BUILD_DATE
EOF

cleanup
MOUNTS=()
"$SCRIPT_DIR/cleanup-rootfs.sh" "$ROOTFS"
"$SCRIPT_DIR/verify-rootfs.sh" "$ROOTFS"

log "creating $OUTPUT_ARCHIVE"
rm -f "$OUTPUT_ARCHIVE"
tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --clamp-mtime \
  --numeric-owner --owner=0 --group=0 --acls --xattrs \
  -C "$ROOTFS" -cf - . | zstd -T0 -10 -o "$OUTPUT_ARCHIVE"

dpkg-query --root="$ROOTFS" -W -f='${Package}\t${Version}\n' | sort \
  >"$DIST_DIR/$OUTPUT_BASENAME.packages.txt"
jq -n \
  --arg profile "$PROFILE" --arg version "$VERSION" --arg base "$BASE_FILENAME" \
  --arg commit "$GIT_COMMIT" --arg built_at "$BUILD_DATE" \
  '{profile:$profile,version:$version,base_image:$base,git_commit:$commit,built_at:$built_at}' \
  >"$DIST_DIR/$OUTPUT_BASENAME.build-info.json"
(cd "$DIST_DIR" && sha256sum "$OUTPUT_BASENAME".* >SHA256SUMS)
"$SCRIPT_DIR/verify-archive.sh" "$OUTPUT_ARCHIVE"
log "build complete: $OUTPUT_ARCHIVE"
