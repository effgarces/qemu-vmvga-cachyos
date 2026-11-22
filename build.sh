#!/usr/bin/env bash
# Local build on CachyOS. Uses your own /etc/makepkg.conf (so CachyOS' CPU flags apply).
#   ./build.sh            sync with the current Arch qemu, then build the package
#   ./build.sh install    same, then install it with pacman -U
set -euo pipefail
cd "$(dirname "$0")"

bash ./sync-arch.sh

while read -r key; do
  [[ -n $key ]] || continue
  gpg --list-keys "$key" >/dev/null 2>&1 || gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key"
done < arch.keys

rm -f ./*.pkg.tar.zst
makepkg -sf --noconfirm

if [[ ${1:-} == install ]]; then
  sudo pacman -U --noconfirm ./qemu-vmvga-*.pkg.tar.zst
fi
