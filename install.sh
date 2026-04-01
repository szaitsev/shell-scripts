#!/usr/bin/env bash
set -euo pipefail

readonly BIN_DIR="${HOME}/bin"
readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "${BIN_DIR}" ]]; then
  echo "Error: ${BIN_DIR} does not exist. Create it and ensure it is in your PATH." >&2
  exit 1
fi

for script in "${REPO_DIR}"/*/*.sh; do
  [[ -f "${script}" ]] || continue
  name="$(basename "${script}" .sh)"
  target="${BIN_DIR}/${name}"
  ln -sf "${script}" "${target}"
  echo "Linked: ${target} -> ${script}"
done
