#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_file="${project_root}/config.env"
if [[ -f "${source_file}" && "${USE_CONFIG_DEFAULTS:-1}" == 1 ]]; then
  # config.env is simple KEY=VALUE data owned by this repository.
  set -a
  # shellcheck disable=SC1090
  source "${source_file}"
  set +a
fi

: "${KERNEL_SOURCE:?KERNEL_SOURCE is required}"
: "${KERNEL_SOURCE_REF:?KERNEL_SOURCE_REF is required}"
: "${KERNEL_CONFIG:?KERNEL_CONFIG is required}"
: "${KSU_SETUP_SOURCE:?KSU_SETUP_SOURCE is required}"
: "${KSU_REF:?KSU_REF is required}"
base_config=${KERNEL_BASE_CONFIG:-defconfig}
ksu_manual_hook=${KSU_MANUAL_HOOK:-0}

kernel_root=${KERNEL_ROOT:-"${project_root}/kernel"}
out_dir=${OUT_DIR:-"${project_root}/out"}
toolchain_root=${TOOLCHAIN_ROOT:-"${project_root}/.toolchains"}
jobs=${JOBS:-$(nproc)}

rm -rf "${kernel_root}" "${out_dir}"
mkdir -p "${out_dir}"

echo "Cloning ${KERNEL_SOURCE}@${KERNEL_SOURCE_REF}"
git clone --depth=1 --branch "${KERNEL_SOURCE_REF}" "${KERNEL_SOURCE}" "${kernel_root}"

"${project_root}/scripts/apply-source-build-fixes.sh" "${kernel_root}"

"${project_root}/scripts/integrate-kernelsu.sh" \
  "${kernel_root}" "${KSU_SETUP_SOURCE}" "${KSU_REF}"

if [[ "${ksu_manual_hook}" == 1 ]] && \
   [[ -f "${kernel_root}/KernelSU/kernel/tools/manual_hook_check.mk" ]]; then
  "${project_root}/scripts/apply-resukisu-manual-hooks.sh" "${kernel_root}"
fi

clang_bin=${CLANG_BIN:-"${toolchain_root}/${CLANG_VERSION}/bin"}
gcc64_bin=${GCC64_BIN:-"${toolchain_root}/aarch64-linux-android-${GCC_VERSION}/bin"}
gcc32_bin=${GCC32_BIN:-"${toolchain_root}/arm-linux-androideabi-${GCC_VERSION}/bin"}

export ARCH=${ARCH:-arm64}
export SUBARCH=${SUBARCH:-arm64}
export PATH="${clang_bin}:${gcc64_bin}:${gcc32_bin}:${PATH}"
export CROSS_COMPILE=${CROSS_COMPILE:-"${gcc64_bin}/aarch64-linux-android-"}
export CROSS_COMPILE_ARM32=${CROSS_COMPILE_ARM32:-"${gcc32_bin}/arm-linux-androideabi-"}
export CLANG_TRIPLE=${CLANG_TRIPLE:-aarch64-linux-gnu-}
export KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-github-actions}
export KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-github-actions}
export LOCALVERSION=${LOCALVERSION:--venus-resukisu}

make_args=(
  -C "${kernel_root}"
  O="${out_dir}"
  ARCH="${ARCH}"
  SUBARCH="${SUBARCH}"
  CC=clang
  LLVM=1
  LLVM_IAS=1
  CLANG_TRIPLE="${CLANG_TRIPLE}"
)

echo "Applying ${KERNEL_CONFIG}"
config_file="${kernel_root}/arch/${ARCH}/configs/${KERNEL_CONFIG}"
if [[ "${KERNEL_CONFIG}" == *_defconfig ]]; then
  make "${make_args[@]}" "${KERNEL_CONFIG}"
elif [[ -f "${config_file}" ]]; then
  # Xiaomi/Lineage QGKI device files are fragments, not make targets.
  make "${make_args[@]}" "${base_config}"
  bash "${kernel_root}/scripts/kconfig/merge_config.sh" \
    -m -O "${out_dir}" "${out_dir}/.config" "${config_file}"
else
  echo "Kernel config not found: ${config_file}" >&2
  exit 1
fi

# These options are applied after the device fragment and then normalized by
# olddefconfig so dependencies are checked by Kconfig. ReSukiSU's Manual Hook
# is compatible with old non-GKI kernels such as the Mi 11's 5.4 tree. The
# symbol is detected before enabling it so another KernelSU-compatible fork
# can still be selected from workflow_dispatch.
bash "${kernel_root}/scripts/config" --file "${out_dir}/.config" \
  --enable KPROBES \
  --enable KALLSYMS \
  --enable KALLSYMS_ALL \
  --enable BPF_SYSCALL \
  --disable BTRFS_FS \
  --disable QRTR_TUN \
  --disable QCOM_CLK_APCS_MSM8916 \
  --enable EXT4_FS \
  --enable OVERLAY_FS \
  --enable TMPFS_XATTR \
  --enable TMPFS_POSIX_ACL \
  --enable KSU

if [[ "${ksu_manual_hook}" == 1 ]] && \
   grep -Rqs 'KSU_MANUAL_HOOK' "${kernel_root}/KernelSU/kernel" 2>/dev/null; then
  bash "${kernel_root}/scripts/config" --file "${out_dir}/.config" \
    --enable KSU_MANUAL_HOOK
  echo 'Enabled CONFIG_KSU_MANUAL_HOOK'
fi

make "${make_args[@]}" olddefconfig

grep -q '^CONFIG_KSU=y$' "${out_dir}/.config" || {
  echo 'CONFIG_KSU=y was not accepted by the selected kernel config.' >&2
  exit 1
}

# This tree enables CONFIG_BPF_JIT in the device fragment.  Its trampoline
# code relies on RCU Tasks Trace, which is selected by BPF_SYSCALL; enable it
# explicitly so the configuration is internally consistent.
grep -q '^CONFIG_BPF_SYSCALL=y$' "${out_dir}/.config" || {
  echo 'CONFIG_BPF_SYSCALL=y was not accepted; BPF JIT trampoline cannot build safely.' >&2
  exit 1
}

# The seventeen tree's Btrfs backport calls probe_user_write(), which this
# arm64 5.4 base does not provide. Android on venus does not use Btrfs;
# exclude the optional filesystem rather than weakening its user-memory check.
grep -q '^# CONFIG_BTRFS_FS is not set$' "${out_dir}/.config" || {
  echo 'CONFIG_BTRFS_FS could not be disabled for this incompatible source tree.' >&2
  exit 1
}

# QRTR TUN is only a userspace test/tunnel endpoint. Its source in this tree
# has not been updated for the four-argument qrtr_endpoint_register() API.
grep -q '^# CONFIG_QRTR_TUN is not set$' "${out_dir}/.config" || {
  echo 'CONFIG_QRTR_TUN could not be disabled for this incompatible source tree.' >&2
  exit 1
}

# MSM8916's APCS CPU-clock driver is unrelated to SM8350 and has a stale
# parent-map type in this mixed source tree.
grep -q '^# CONFIG_QCOM_CLK_APCS_MSM8916 is not set$' "${out_dir}/.config" || {
  echo 'CONFIG_QCOM_CLK_APCS_MSM8916 could not be disabled for this source tree.' >&2
  exit 1
}

echo "Building kernel with ${jobs} jobs"
make "${make_args[@]}" -j"${jobs}"

image="${out_dir}/arch/arm64/boot/Image"
test -s "${image}"
cp -f "${image}" "${project_root}/Image"

for dtbo in \
  "${out_dir}/arch/arm64/boot/dtbo.img" \
  "${out_dir}/dtbo.img"; do
  if [[ -s "${dtbo}" ]]; then
    cp -f "${dtbo}" "${project_root}/dtbo.img"
    break
  fi
done

git -C "${kernel_root}" rev-parse HEAD > "${project_root}/kernel-commit.txt"
cp -f "${out_dir}/.config" "${project_root}/venus.config"
echo "Kernel image: ${project_root}/Image"
