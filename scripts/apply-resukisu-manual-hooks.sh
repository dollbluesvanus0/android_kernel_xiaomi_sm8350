#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
kernel_root=${1:?usage: apply-resukisu-manual-hooks.sh <kernel-root>}
patch_file="${project_root}/patches/resukisu-5.4-manual-hooks.patch"

test -f "${patch_file}"
test -f "${kernel_root}/fs/exec.c"

required_hooks=(
  ksu_handle_execveat
  ksu_handle_post_execveat
  ksu_handle_faccessat
  ksu_handle_stat
  ksu_handle_newfstat_ret
  ksu_handle_fstat64_ret
  ksu_handle_sys_reboot
)

all_present=1
for hook in "${required_hooks[@]}"; do
  if ! grep -Rqs -- "${hook}" \
      "${kernel_root}/fs/exec.c" \
      "${kernel_root}/fs/open.c" \
      "${kernel_root}/fs/stat.c" \
      "${kernel_root}/kernel/reboot.c"; then
    all_present=0
    break
  fi
done

if [[ "${all_present}" == 1 ]]; then
  echo 'ReSukiSU manual hooks are already present.'
  exit 0
fi

echo 'Applying ReSukiSU Manual Hook patch for the Xiaomi 5.4 kernel tree'
git -C "${kernel_root}" apply --check "${patch_file}"
git -C "${kernel_root}" apply "${patch_file}"

for hook in "${required_hooks[@]}"; do
  grep -Rqs -- "${hook}" \
    "${kernel_root}/fs/exec.c" \
    "${kernel_root}/fs/open.c" \
    "${kernel_root}/fs/stat.c" \
    "${kernel_root}/kernel/reboot.c" || {
      echo "Required ReSukiSU hook was not applied: ${hook}" >&2
      exit 1
    }
done
