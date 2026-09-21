#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ -f "${project_root}/config.env" && "${USE_CONFIG_DEFAULTS:-1}" == 1 ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${project_root}/config.env"
  set +a
fi
: "${ANYKERNEL_SOURCE:?ANYKERNEL_SOURCE is required}"
: "${ANYKERNEL_REF:?ANYKERNEL_REF is required}"

work_dir=${ANYKERNEL_WORK_DIR:-"${project_root}/anykernel-work"}
version=${KERNEL_VERSION:-"$(date -u +%Y%m%d)"}
artifact_dir=${ARTIFACT_DIR:-"${project_root}/dist"}

rm -rf "${work_dir}" "${artifact_dir}"
mkdir -p "${artifact_dir}"
git clone --depth=1 --branch "${ANYKERNEL_REF}" "${ANYKERNEL_SOURCE}" "${work_dir}"

cp -f "${project_root}/anykernel/anykernel.sh" "${work_dir}/anykernel.sh"
cp -f "${project_root}/Image" "${work_dir}/Image"
if [[ -s "${project_root}/dtbo.img" ]]; then
  cp -f "${project_root}/dtbo.img" "${work_dir}/dtbo.img"
fi
cp -f "${project_root}/kernel-commit.txt" "${work_dir}/kernel-commit.txt"
cp -f "${project_root}/venus.config" "${work_dir}/venus.config"
chmod +x "${work_dir}/anykernel.sh"

zip_name="venus-kernel-${version}-AnyKernel3.zip"
(
  cd "${work_dir}"
  zip -r9 "${artifact_dir}/${zip_name}" . \
    -x '.git/*' 'README.md' '*placeholder'
)

sha256sum "${artifact_dir}/${zip_name}" > "${artifact_dir}/${zip_name}.sha256"
echo "Created ${artifact_dir}/${zip_name}"
