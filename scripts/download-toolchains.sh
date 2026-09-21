#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ "${USE_CONFIG_DEFAULTS:-1}" == 1 ]]; then
  source "${project_root}/config.env"
fi
toolchain_root=${TOOLCHAIN_ROOT:-"${project_root}/.toolchains"}
mkdir -p "${toolchain_root}"
work=$(mktemp -d "${toolchain_root}/download.XXXXXXXX")
trap 'rm -rf -- "${work}"' EXIT

# Check both compiler and binutils: an executable left by an interrupted
# download alone is not a complete toolchain cache.
clang_dir="${toolchain_root}/${CLANG_VERSION}"
if [[ ! -x "${clang_dir}/bin/clang" || ! -x "${clang_dir}/bin/ld.lld" ]]; then
  git clone --depth=1 --filter=blob:none --sparse --branch "${CLANG_BRANCH}" \
    https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
    "${work}/clang"
  git -C "${work}/clang" sparse-checkout set "${CLANG_VERSION}"
  test -x "${work}/clang/${CLANG_VERSION}/bin/clang"
  test -x "${work}/clang/${CLANG_VERSION}/bin/ld.lld"
  mkdir -p "${clang_dir}"
  cp -a "${work}/clang/${CLANG_VERSION}/." "${clang_dir}/"
fi

for spec in aarch64:aarch64-linux-android arm:arm-linux-androideabi; do
  arch=${spec%%:*}
  triple=${spec#*:}
  dest="${toolchain_root}/${triple}-${GCC_VERSION}"
  # Android's GCC 4.9 prebuilts for this branch only provide the GNU
  # binutils. The kernel is compiled by Clang, while CROSS_COMPILE resolves
  # linker and object tools from this directory.
  if [[ ! -x "${dest}/bin/${triple}-ld" ]]; then
    git clone --depth=1 --branch "${GCC_BRANCH}" \
      "https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/${arch}/${triple}-${GCC_VERSION}" \
      "${work}/${arch}"
    test -x "${work}/${arch}/bin/${triple}-ld"
    mkdir -p "${dest}"
    # Copy the repository contents without its Git metadata.
    tar -C "${work}/${arch}" --exclude=./.git -cf - . | tar -C "${dest}" -xf -
  fi
  "${dest}/bin/${triple}-ld" --version
done
"${clang_dir}/bin/clang" --version
"${clang_dir}/bin/ld.lld" --version
