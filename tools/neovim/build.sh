#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?target required}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE="$ROOT/.cache/neovim"
DIST="$ROOT/dist"
NVIM_VERSION=0.12.4
PKG="neovim-${NVIM_VERSION}-${TARGET}"

mkdir -p "$CACHE" "$DIST"
SRC="$CACHE/neovim.tar.gz"
[[ -s "$SRC" ]] || curl -fL --retry 3 \
  "https://github.com/neovim/neovim/archive/refs/tags/v${NVIM_VERSION}.tar.gz" -o "$SRC"
tar tzf "$SRC" >/dev/null
rm -f "$DIST/$PKG.tar.gz"

docker run --rm \
  -e NVIM_VERSION -e PKG \
  -v "$CACHE:/src:ro" \
  -v "$DIST:/dist" \
  quay.io/pypa/manylinux2014_x86_64 bash -euxo pipefail -c '
    yum install -y gcc gcc-c++ make git gettext curl unzip tar gzip
    /opt/python/cp311-cp311/bin/pip install --no-cache-dir cmake ninja
    export PATH="/opt/python/cp311-cp311/bin:$PATH"

    mkdir -p /build /opt/nvim
    cd /build
    tar xzf /src/neovim.tar.gz
    cd neovim-${NVIM_VERSION}

    make CMAKE_BUILD_TYPE=Release \
      CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=/opt/nvim"
    make install

    /opt/nvim/bin/nvim --version | head -n 3
    mkdir -p "/package/${PKG}"
    cp -a /opt/nvim/. "/package/${PKG}/"
    tar -C /package -czf "/dist/${PKG}.tar.gz" "$PKG"
  '

echo "$DIST/$PKG.tar.gz"
