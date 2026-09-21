#!/usr/bin/env bash
set -euo pipefail

kernel_root=${1:?usage: integrate-kernelsu.sh <kernel-root> [setup-url] [ref]}
setup_url=${2:-https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh}
ksu_ref=${3:-v0.9.5}

if [[ ! -d "${kernel_root}/drivers" ]]; then
  echo "Kernel source does not contain drivers/: ${kernel_root}" >&2
  exit 1
fi

echo "Integrating KernelSU ref ${ksu_ref}"
pushd "${kernel_root}" >/dev/null
curl --fail --location --retry 5 --silent --show-error "${setup_url}" | bash -s "${ksu_ref}"
popd >/dev/null

test -e "${kernel_root}/drivers/kernelsu/Kconfig"
test -e "${kernel_root}/drivers/kernelsu/Makefile"
echo "KernelSU integration completed."
