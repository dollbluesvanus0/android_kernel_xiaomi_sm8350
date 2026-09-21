#!/sbin/sh

### AnyKernel3 installation script for Xiaomi Mi 11 (venus)

properties() { '
kernel.string=Venus Kernel with KernelSU
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=venus
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

## The stock Mi 11 boot image is A/B and uses a separate DTBO partition.
BLOCK=boot
IS_SLOT_DEVICE=auto
RAMDISK_COMPRESSION=auto
PATCH_VBMETA_FLAG=auto

# Import AnyKernel3 functions and variables.
. tools/ak3-core.sh

# Replace only the kernel payload so the existing ROM ramdisk is preserved.
split_boot
flash_boot

# Use the matching DTBO when the source tree produced one. AnyKernel3's
# flash_generic handles the active slot automatically for this A/B device.
[ -f dtbo.img ] && flash_generic dtbo
