# Maintainer: you <you@example.com>
#
# Builds QEMU's x86_64 system emulator with the enhanced VMware SVGA II device
# from https://github.com/qemus/qemu-vmvga overlaid on the QEMU source tree.
#
# The QEMU version, patches and signing keys follow what Arch currently ships:
# run ./sync-arch.sh first (build.sh and CI do it), it writes the small files read below.
#
# Installed side by side with the stock qemu packages under /opt/qemu-vmvga, so
# nothing from the official packages is replaced. Firmware/keymaps come from the
# stock qemu-common / qemu-system-x86-firmware.

for _f in qemu.version arch.rel arch.keys arch.patches; do
  if [[ ! -f $startdir/$_f ]]; then
    echo "missing $_f: run ./sync-arch.sh first" >&2
    exit 1
  fi
done
_qemuver=$(tr -d '[:space:]' < "$startdir/qemu.version")
_archrel=$(tr -d '[:space:]' < "$startdir/arch.rel")

pkgname=qemu-vmvga
pkgver=${_qemuver}.r0          # rewritten by pkgver()
pkgrel=${_archrel}             # follows Arch's pkgrel, so patch-only changes still upgrade
pkgdesc='QEMU x86_64 system emulator with the enhanced vmware-svga device (qemus/qemu-vmvga), installed in /opt/qemu-vmvga'
arch=(x86_64)
url='https://github.com/qemus/qemu-vmvga'
license=(GPL-2.0-or-later)
depends=(
  glib2 pixman libslirp libaio liburing libusb usbredir spice gtk3
  libcap-ng libseccomp gnutls snappy lzo zstd libjpeg-turbo
  libpng libpulse dtc
  qemu-common qemu-system-x86-firmware seabios
)
makedepends=(
  git meson ninja python python-distlib python-setuptools python-pip
  spice-protocol glib2-devel
)
optdepends=(
  'dxvk-native: Direct3D 9-11 acceleration through the host GPU (upstream requires this one, not the Wine "dxvk")'
  'vulkan-driver: required for the DXVK-backed 3D path'
  'edk2-ovmf: UEFI firmware for guests'
)
options=(!lto)
install=qemu-vmvga.install
source=("https://download.qemu.org/qemu-${_qemuver}.tar.xz"
        "https://download.qemu.org/qemu-${_qemuver}.tar.xz.sig"
        "qemu-vmvga::git+https://github.com/qemus/qemu-vmvga.git")
# The QEMU tarball is authenticated through its PGP signature, so no hash.
sha256sums=('SKIP' 'SKIP' 'SKIP')
mapfile -t validpgpkeys < "$startdir/arch.keys"   # same keys Arch verifies with

pkgver() {
  printf '%s.r%s' "$_qemuver" "$(git -C "$srcdir/qemu-vmvga" rev-list --count HEAD)"
}

prepare() {
  cd "qemu-$_qemuver"

  # Arch's own patches for this exact version, in Arch's order.
  local p
  while IFS= read -r p; do
    [[ -n $p ]] || continue
    echo "Applying Arch patch $p"
    patch -Np1 -i "$startdir/arch/$p"
  done < "$startdir/arch.patches"

  if [[ ! -f $srcdir/qemu-vmvga/hw/display/vmware_vga.c ]]; then
    echo 'ERROR: upstream layout changed, hw/display/vmware_vga.c not found' >&2
    return 1
  fi

  # Overlay upstream files onto the QEMU tree (upstream documents it as an overlay).
  cp -a "$srcdir/qemu-vmvga/hw/." hw/
}

build() {
  cd "qemu-$_qemuver"
  mkdir -p build
  cd build

  ../configure \
    --prefix=/opt/qemu-vmvga \
    --datadir=/usr/share \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --target-list=x86_64-softmmu \
    --audio-drv-list=pa \
    --enable-kvm \
    --enable-slirp \
    --enable-spice \
    --enable-gtk \
    --disable-sdl \
    --disable-sdl-image \
    --disable-opengl \
    --enable-usb-redir \
    --enable-linux-aio \
    --enable-linux-io-uring \
    --enable-seccomp \
    --enable-cap-ng \
    --disable-modules \
    --disable-tools \
    --disable-guest-agent \
    --disable-docs \
    --disable-werror

  make

  # Smoke test: the package is useless without the device. Upstream registers it as
  # "vmvga" (used as -device vmvga); fail the build here if that ever changes.
  local devs
  devs=$(./qemu-system-x86_64 -device help 2>&1) || true
  if ! grep -q '"vmvga"' <<<"$devs"; then
    echo 'ERROR: built qemu-system-x86_64 does not provide the "vmvga" device' >&2
    return 1
  fi

  # Upstream's DXVK glue fakes libSDL2 in memory and refuses to start when the real
  # libSDL2 is already loaded ("cannot replace an already loaded libSDL2-2.0.so.0"),
  # so the binary must not link SDL2, directly or through another library.
  if ldd ./qemu-system-x86_64 | grep -q 'libSDL2'; then
    echo 'ERROR: qemu-system-x86_64 links libSDL2, which breaks the vmvga 3D path' >&2
    ldd ./qemu-system-x86_64 | grep 'libSDL2' >&2
    return 1
  fi
}

package() {
  cd "qemu-$_qemuver/build"
  make DESTDIR="$pkgdir" install

  # Firmware, keymaps, config and state belong to the stock qemu packages;
  # keep only the emulator binary so we never collide with them.
  rm -rf "$pkgdir"/{etc,var,usr}
  rm -rf "$pkgdir"/opt/qemu-vmvga/{share,include,libexec}

  # Convenience name on PATH (does not shadow /usr/bin/qemu-system-x86_64).
  install -d "$pkgdir/usr/bin"
  ln -s /opt/qemu-vmvga/bin/qemu-system-x86_64 "$pkgdir/usr/bin/qemu-vmvga-system-x86_64"

  install -Dm644 "$srcdir/qemu-vmvga/license.md" "$pkgdir/usr/share/licenses/$pkgname/license-vmvga.md"
}
