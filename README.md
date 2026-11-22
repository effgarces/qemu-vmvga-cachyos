# qemu-vmvga for CachyOS / Arch

Packages [qemus/qemu-vmvga](https://github.com/qemus/qemu-vmvga) (enhanced VMware SVGA II
device, 2D + DXVK-backed D3D9–11) as a `.pkg.tar.zst`.

Upstream is not a standalone program: it is source files overlaid on a QEMU tree. So this
repo builds `qemu-system-x86_64` from **the QEMU version Arch currently ships**, with the overlay
applied, and installs it **next to** your normal QEMU, in `/opt/qemu-vmvga`. Nothing from the
official `qemu-*` packages is replaced. Firmware and keymaps are taken from the stock
`qemu-common` and `qemu-system-x86-firmware`.

## Install

From a release (built by GitHub Actions):

```
sudo pacman -U qemu-vmvga-*.pkg.tar.zst
```

Or build locally on CachyOS (uses your own makepkg flags):

```
./build.sh install
```

## Use it

Plain QEMU:

```
/opt/qemu-vmvga/bin/qemu-system-x86_64 ... -vga vmware      # or: -device vmware-svga
```

(also on PATH as `qemu-vmvga-system-x86_64`).

virt-manager / libvirt: edit the domain XML (`virsh edit <vm>`):

```xml
<devices>
  <emulator>/opt/qemu-vmvga/bin/qemu-system-x86_64</emulator>
  ...
  <video><model type="vmvga"/></video>
</devices>
```

The guest needs a VMware SVGA display driver (VMware Tools / open-vm-tools) for the acceleration.
3D needs a Vulkan GPU on the host plus DXVK (optional dependency); without it, it falls back to 2D.

## How tracking works

`sync-arch.sh` is the single source of truth. It:

1. reads the current version from the Arch repos (`pacman -Si qemu-system-x86`, e.g. `11.1.1-4`),
2. clones [Arch's packaging repo](https://gitlab.archlinux.org/archlinux/packaging/packages/qemu)
   at exactly that tag,
3. takes from Arch's PKGBUILD the QEMU version, `pkgrel`, the patches (applied in the same order)
   and the PGP keys the tarball is verified with.

It stops with an error if Arch's PKGBUILD lists a source it does not know how to handle, so a
change in how Arch packages QEMU fails loudly instead of building something different.

`.github/workflows/build.yml` runs daily in an Arch container. If there is no release tagged
`arch-<qemu version>-<arch pkgrel>-vmvga-<upstream commit>` yet (a new Arch version, a changed Arch
patch set, or a new qemu-vmvga commit), it builds and publishes one. The package version is
`<qemu version>.r<upstream commit count>` with Arch's `pkgrel`, so `pacman -U` always sees newer
builds as upgrades.

## Notes

- Upstream's overlay targets a specific QEMU version. When Arch moves to a version the overlay does
  not support yet, that day's build fails and the previous release stays available.
- `build.sh` locally reads the version from your pacman sync databases (as of your last
  `pacman -Sy`). If your CachyOS repos carry a different qemu than Arch, the Arch tag clone fails;
  set `ARCH_QEMU_VERSION=<ver>-<rel>` to force a tag.
- Network bridge helper is not built (`--disable-tools`); libvirt-managed networking is unaffected.
- The configure flags are this repo's own, not copied from Arch's PKGBUILD.
