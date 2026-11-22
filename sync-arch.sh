#!/usr/bin/env bash
# Pins this repo to the QEMU that Arch currently ships, using Arch's own packaging sources.
#
#  1. reads the current qemu version from the Arch repos (pacman -Si qemu-system-x86)
#  2. clones Arch's packaging repo at that exact tag into ./arch
#  3. reads the source list from Arch's PKGBUILD and records what the build needs:
#       qemu.version  upstream QEMU version        arch.rel      Arch pkgrel
#       arch.patches  Arch's patches, in order     arch.keys     PGP keys Arch verifies with
#       release.tag   tag used for the GitHub release
#
# Overrides: ARCH_QEMU_VERSION=11.1.1-4   ARCH_LOCAL_DIR=/path/to/arch/qemu/checkout
set -euo pipefail
cd "$(dirname "$0")"

DEFAULT_KEY=8695A8BFD3F97CDAAC35775A9CA4ABB381AB73C8
REPO_URL=https://gitlab.archlinux.org/archlinux/packaging/packages/qemu.git

ver=${ARCH_QEMU_VERSION:-$(pacman -Si qemu-system-x86 | awk -F' +: +' '/^Version/{print $2; exit}')}
if [[ ! $ver =~ ^[0-9]+(\.[0-9]+)+(rc[0-9]+)?-[0-9]+$ ]]; then
  echo "unexpected Arch qemu version: '$ver'" >&2
  exit 1
fi
pkgver=${ver%-*}
pkgrel=${ver##*-}
echo "Arch ships qemu $pkgver-$pkgrel"

rm -rf arch
if [[ -n ${ARCH_LOCAL_DIR:-} ]]; then
  cp -a "$ARCH_LOCAL_DIR" arch
else
  git clone --quiet --depth 1 --branch "$ver" "$REPO_URL" arch || {
    echo "could not clone tag '$ver' from $REPO_URL" >&2
    exit 1
  }
fi
[[ -f arch/PKGBUILD ]] || { echo "arch/PKGBUILD missing" >&2; exit 1; }

# Evaluate the top-level variables of Arch's PKGBUILD (no functions are run).
meta=$(cd arch && bash -c '
  source ./PKGBUILD >/dev/null 2>&1 || exit 1
  echo "PKGVER=$pkgver"
  echo "PKGREL=$pkgrel"
  for s in "${source[@]}"; do echo "SRC=$s"; done
  for k in "${validpgpkeys[@]}"; do echo "KEY=$k"; done
') || { echo "could not evaluate arch/PKGBUILD" >&2; exit 1; }

patches=()
keys=()
seen_pkgver= seen_pkgrel=
while IFS= read -r line; do
  case $line in
    PKGVER=*) seen_pkgver=${line#PKGVER=} ;;
    PKGREL=*) seen_pkgrel=${line#PKGREL=} ;;
    KEY=*)    keys+=("${line#KEY=}") ;;
    SRC=https://download.qemu.org/qemu-"$pkgver".tar.xz | SRC=https://download.qemu.org/qemu-"$pkgver".tar.xz.sig) ;;
    SRC=*://* | SRC=*::*)
      echo "Arch's PKGBUILD has a source this repo does not handle: ${line#SRC=}" >&2
      exit 1 ;;
    SRC=*.patch | SRC=*.diff)
      f=${line#SRC=}
      [[ -f arch/$f ]] || { echo "patch listed but missing in Arch repo: $f" >&2; exit 1; }
      patches+=("$f") ;;
    SRC=*)
      echo "Arch's PKGBUILD has a source this repo does not handle: ${line#SRC=}" >&2
      exit 1 ;;
  esac
done <<<"$meta"

if [[ $seen_pkgver != "$pkgver" || $seen_pkgrel != "$pkgrel" ]]; then
  echo "Arch tag $ver does not match its PKGBUILD ($seen_pkgver-$seen_pkgrel)" >&2
  exit 1
fi
if ((${#keys[@]} == 0)); then
  echo "warning: Arch PKGBUILD lists no validpgpkeys, using default QEMU release key" >&2
  keys=("$DEFAULT_KEY")
fi

printf '%s\n' "$pkgver" > qemu.version
printf '%s\n' "$pkgrel" > arch.rel
printf '%s\n' "${keys[@]}" > arch.keys
: > arch.patches
((${#patches[@]})) && printf '%s\n' "${patches[@]}" > arch.patches

sha=$(git ls-remote https://github.com/qemus/qemu-vmvga.git HEAD | cut -c1-12)
[[ -n $sha ]] || { echo "could not read qemu-vmvga HEAD" >&2; exit 1; }
printf 'arch-%s-%s-vmvga-%s\n' "$pkgver" "$pkgrel" "$sha" > release.tag

echo "qemu $pkgver, arch pkgrel $pkgrel, ${#patches[@]} patch(es), vmvga $sha"
echo "tag: $(cat release.tag)"
