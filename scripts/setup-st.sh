#!/usr/bin/env bash
# Build and install st with scrollback patches.
set -euo pipefail

ST_DIR="${HOME}/st"
FONT="IBM Plex Mono:pixelsize=12:antialias=true:autohint=true"

PATCH_BASE="https://st.suckless.org/patches/scrollback"
PATCHES=(
  st-scrollback-0.9.2.diff
  st-scrollback-mouse-0.9.2.diff
  st-scrollback-mouse-altscreen-20200416-5703aa0.diff
)

if [[ -d "${ST_DIR}" ]]; then
  echo "${ST_DIR} already exists."
  echo "    rm -rf ${ST_DIR}"
  exit 1
fi

git clone https://git.suckless.org/st "${ST_DIR}"
cd "${ST_DIR}"

mkdir -p patches
for p in "${PATCHES[@]}"; do
  curl -fLo "patches/${p}" "${PATCH_BASE}/${p}"
done

for p in "${PATCHES[@]}"; do
  patch -p1 < "patches/${p}"
done

cp config.def.h config.h
sed -i "s/font = \".*\"/font = \"${FONT}\"/" config.h

make clean
sudo make install

echo ">>> st installed."
