# Venus Kernel

Custom kernel build for Xiaomi Mi 11 (`venus`, Snapdragon 888 / SM8350).

The project builds the LineageOS-derived SM8350 kernel tree used by the
Android 17 `venus` port (`seventeen`, Linux 5.4.302), integrates the ReSukiSU
non-GKI driver, and packages the resulting `Image`
and optional `dtbo.img` into an AnyKernel3 flashable ZIP.

## Build with GitHub Actions

1. Push this repository to GitHub.
2. Open **Actions → Build Xiaomi Mi 11 kernel → Run workflow**.
3. Keep the defaults for the first build.
4. Download the `venus-kernel-...` artifact from the completed run.

The workflow can also be started by pushing changes to `main` that touch the
workflow, scripts, or configuration.

The default root implementation is ReSukiSU with `Manual Hook`: Mi 11's 5.4
tree is non-GKI, while ReSukiSU documents Manual Hook for old kernels. Its
Tracepoint Hook is for GKI 2.0/5.10+, and SUSFS is not a turnkey non-GKI
feature; using it would require a separate, manually maintained backport. The
workflow exposes the setup URL/ref and Manual Hook switch so official KernelSU
`v0.9.5`, KernelSU-Next, or another compatible fork can be tested.

The selected repository also exposes a `sixteen` branch. Use `seventeen` for
the Android 17 port that this tree targets, or `sixteen` only when the ROM's
device tree and vendor modules were built against that branch. The kernel
source, defconfig, and vendor modules must match each other; changing only the
Android userspace target is not enough.

## Flashing

The bootloader must be unlocked. Before flashing, make a full backup of the
currently working `boot` and `dtbo` partitions and keep the stock images
available for recovery. Flash the ZIP in a recovery or KernelSU-compatible
kernel flasher, then reboot. If the device bootloops, restore the stock boot
image from fastboot/recovery.

The package targets the active A/B slot and uses AnyKernel3's partition
detection. It does not intentionally change the ramdisk; KernelSU is built
into the kernel image.

## Local Linux/WSL build

The same script used by Actions can be run on a Linux host after exporting the
variables from `config.env`:

```bash
set -a
. ./config.env
set +a
./scripts/build-kernel.sh
./scripts/package-anykernel.sh
```

Local builds need `git`, `curl`, `tar`, `make`, `bc`, `bison`, `flex`, `cpio`,
`zip`, `dtc`, and the usual C build libraries. The GitHub runner installs the
remaining packages and downloads the pinned Android 11 toolchains.

## Sources and licenses

- Kernel source: [RobertGarciaa/android_kernel_xiaomi_sm8350](https://github.com/RobertGarciaa/android_kernel_xiaomi_sm8350), branch `seventeen`.
- Root driver: [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU), `Manual Hook`, ref `main`.
- Flash packaging: [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3).

Each upstream project keeps its own license and notices. This repository only
contains the build orchestration and packaging configuration; upstream source
trees are fetched during the build.
