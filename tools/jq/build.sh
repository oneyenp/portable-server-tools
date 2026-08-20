#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?target required}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE="$ROOT/.cache/jq"
DIST="$ROOT/dist"
JQ_VERSION=1.8.2
PKG="jq-${JQ_VERSION}-${TARGET}"

mkdir -p "$CACHE" "$DIST"
SRC="$CACHE/jq.tar.gz"
[[ -s "$SRC" ]] || curl -fL --retry 3 \
  "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-${JQ_VERSION}.tar.gz" -o "$SRC"
tar tzf "$SRC" >/dev/null
rm -f "$DIST/$PKG.tar.gz"

docker run --rm \
  -e JQ_VERSION="$JQ_VERSION" \
  -e PKG="$PKG" \
  -v "$CACHE:/src:ro" \
  -v "$DIST:/dist" \
  centos:7 bash -euxo pipefail -c '
    export LC_ALL=C
    sed -i "s/mirrorlist/#mirrorlist/g" /etc/yum.repos.d/CentOS-Base.repo
    sed -i "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" /etc/yum.repos.d/CentOS-Base.repo
    yum clean all
    yum makecache
    yum install -y gcc gcc-c++ make autoconf automake libtool tar gzip

    mkdir -p /build /opt/jq
    cd /build
    tar xzf /src/jq.tar.gz
    cd jq-${JQ_VERSION}

    ./configure \
      --prefix=/opt/jq \
      --disable-docs \
      --with-oniguruma=builtin \
      --enable-static \
      --enable-all-static
    make -j"$(nproc)" LDFLAGS=-all-static
    make check VERBOSE=yes
    make install-strip

    /opt/jq/bin/jq --version
    printf "%s\n" "{\"value\":42}" | /opt/jq/bin/jq -e ".value == 42" >/dev/null

    ldd_output="$(ldd /opt/jq/bin/jq 2>&1 || true)"
    case "$ldd_output" in
      *"not a dynamic executable"*|*"statically linked"*)
        echo "jq is statically linked"
        ;;
      *)
        echo "jq static-link verification failed" >&2
        echo "$ldd_output" >&2
        exit 1
        ;;
    esac

    mkdir -p "/package/${PKG}"
    cp -a /opt/jq/. "/package/${PKG}/"
    tar -C /package -czf "/dist/${PKG}.tar.gz" "$PKG"
  '

test -s "$DIST/$PKG.tar.gz"
tar tzf "$DIST/$PKG.tar.gz" >/dev/null
echo "$DIST/$PKG.tar.gz"
