#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
kernel_root=${1:?usage: apply-source-build-fixes.sh <kernel-root>}
patch_file="${project_root}/patches/seventeen-build-fixes.patch"

test -f "${kernel_root}/kernel/taskstats.c"
test -f "${patch_file}"

if git -C "${kernel_root}" apply --check "${patch_file}"; then
  echo 'Applying source-tree build fixes for seventeen'
  git -C "${kernel_root}" apply "${patch_file}"
elif git -C "${kernel_root}" apply --reverse --check "${patch_file}"; then
  echo 'Source-tree build fixes are already present.'
else
  echo 'The source tree does not match the known seventeen build-fix patch.' >&2
  exit 1
fi
