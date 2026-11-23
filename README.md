# qemu-vmvga for CachyOS / Arch

Packages [qemus/qemu-vmvga](https://github.com/qemus/qemu-vmvga) (VMware SVGA II device with 2D and
DXVK-backed D3D9–11 3D) as a `.pkg.tar.zst`.

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

Check that the device is there:

```
/opt/qemu-vmvga/bin/qemu-system-x86_64 -device help | grep vmvga
```

## Use it

**The device is called `vmvga`.** It replaces the stock VMware SVGA device in this binary, so
`-vga vmware`, `-device vmware-svga` and libvirt's built-in "vmvga" video model do **not** work with it
(libvirt asks QEMU for `vmware-svga`, which this binary no longer has).

Three things are needed:

1. The device and the VMware backdoor port on the machine:

   ```
   /opt/qemu-vmvga/bin/qemu-system-x86_64 -machine q35,accel=kvm,vmport=on -device vmvga ...
   ```

2. KVM must allow the VMware backdoor port, otherwise the guest driver disables 3D:

   ```
   echo "options kvm enable_vmware_backdoor=Y" | sudo tee /etc/modprobe.d/kvm-vmware-backdoor.conf
   sudo reboot
   ```

   (This changes KVM for every VM on the host, which is why the package does not do it for you.)

3. For 3D: the `dxvk-native` package (not the Wine `dxvk`) and a Vulkan-capable GPU on the host, and the
   VMware SVGA driver in the guest. Without DXVK the device falls back to 2D. Upstream recommends driver
   9.17.11 (VMware Tools 13.1.5) for Windows 10/11, see the
   [driver table](https://github.com/qemus/qemu-vmvga#recommended-drivers-).

### libvirt / virt-manager

libvirt has no model for this device, so it is added as a raw QEMU argument and the libvirt video
device is set to `none`. Use `virsh edit <vm>` (virt-manager's XML editor may drop the `qemu:` part):

```xml
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  ...
  <features>
    ...
    <vmport state='on'/>
  </features>
  <devices>
    <emulator>/opt/qemu-vmvga/bin/qemu-system-x86_64</emulator>
    ...
    <video>
      <model type='none'/>
    </video>
  </devices>
  <qemu:commandline>
    <qemu:arg value='-device'/>
    <qemu:arg value='vmvga'/>
  </qemu:commandline>
</domain>
```

The emulator is also on PATH as `qemu-vmvga-system-x86_64`.

## How tracking works

`sync-arch.sh` is the single source of truth. It:

1. reads the current version from the Arch repos (`pacman -Si qemu-system-x86`, e.g. `11.1.1-4`),
2. clones [Arch's packaging repo](https://gitlab.archlinux.org/archlinux/packaging/packages/qemu)
   at exactly that tag,
3. takes from Arch's PKGBUILD the QEMU version, `pkgrel`, the patches (applied in the same order)
   and the PGP keys the tarball is verified with.

It stops with an error if Arch's PKGBUILD lists a remote source it does not know how to handle, so a
change in how Arch packages QEMU fails loudly instead of building something different. Other local files
in Arch's repo (such as `bridge.conf`) are skipped, since only the emulator binary is packaged.

`.github/workflows/build.yml` runs daily in an Arch container. If there is no release tagged
`arch-<qemu version>-<arch pkgrel>-vmvga-<upstream commit>` yet (a new Arch version, a changed Arch
patch set, or a new qemu-vmvga commit), it builds and publishes one. The package version is
`<qemu version>.r<upstream commit count>` with Arch's `pkgrel`, so `pacman -U` always sees newer
builds as upgrades.

## Notes

- Upstream's overlay targets a specific QEMU version. When Arch moves to a version the overlay does
  not support yet, that day's build fails and the previous release stays available.
- The build ends with a smoke test that fails if the binary has no `vmvga` device, so an upstream
  rename cannot silently produce a useless package.
- `build.sh` locally reads the version from your pacman sync databases (as of your last
  `pacman -Sy`). If your CachyOS repos carry a different qemu than Arch, the Arch tag clone fails;
  set `ARCH_QEMU_VERSION=<ver>-<rel>` to force a tag.
- Network bridge helper is not built (`--disable-tools`); libvirt-managed networking is unaffected.
- The configure flags are this repo's own, not copied from Arch's PKGBUILD.
