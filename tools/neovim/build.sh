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
  -e NVIM_VERSION="$NVIM_VERSION" \
  -e PKG="$PKG" \
  -v "$CACHE:/src:ro" \
  -v "$DIST:/dist" \
  quay.io/pypa/manylinux2014_x86_64 bash -euxo pipefail -c '
    export LC_ALL=C
    yum install -y gcc gcc-c++ make git gettext curl unzip tar gzip patch
    /opt/python/cp311-cp311/bin/pip install --no-cache-dir cmake ninja
    export PATH="/opt/python/cp311-cp311/bin:$PATH"

    cmake --version
    ninja --version

    mkdir -p /build /opt/nvim
    cd /build
    tar xzf /src/neovim.tar.gz
    cd neovim-${NVIM_VERSION}

    cmake -S cmake.deps -B .deps -G Ninja \
      -D CMAKE_BUILD_TYPE=Release
    cmake --build .deps --parallel "$(nproc)"

    cmake -S . -B build -G Ninja \
      -D CMAKE_BUILD_TYPE=Release \
      -D CMAKE_INSTALL_PREFIX=/opt/nvim
    cmake --build build --parallel "$(nproc)"
    cmake --install build

    test -x /opt/nvim/bin/nvim
    /opt/nvim/bin/nvim --version | head -n 3
    /opt/nvim/bin/nvim --headless -u NONE -i NONE "+lua assert(vim.version().major == 0)" +qall

    ldd /opt/nvim/bin/nvim | tee /tmp/nvim.ldd
    if grep -E "(/build/|/\.deps/)" /tmp/nvim.ldd; then
      echo "Neovim has build-tree runtime dependencies" >&2
      exit 1
    fi
    if grep -q "not found" /tmp/nvim.ldd; then
      echo "Neovim has unresolved runtime dependencies" >&2
      exit 1
    fi

    mkdir -p "/package/${PKG}"
    cp -a /opt/nvim/. "/package/${PKG}/"
    tar -C /package -czf "/dist/${PKG}.tar.gz" "$PKG"
  '

test -s "$DIST/$PKG.tar.gz"
tar tzf "$DIST/$PKG.tar.gz" >/dev/null
echo "$DIST/$PKG.tar.gz"
