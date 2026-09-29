#!/bin/bash
set -euo pipefail

packages=(
  git
  curl ca-certificates
  zip unzip xz-utils
  build-essential pkg-config
  jq ripgrep
  less vim
  rsync
)

missing=()
for package in "${packages[@]}"; do
  if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null |
      grep -qx 'install ok installed'; then
    missing+=("$package")
  fi
done

if ((${#missing[@]})); then
  apt-get update
  DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends "${missing[@]}"
fi
