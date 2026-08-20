#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?target required}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE="$ROOT/.cache/tmux"
DIST="$ROOT/dist"

TMUX_VERSION=3.7b
NCURSES_VERSION=6.4
LIBEVENT_VERSION=2.1.12-stable
PKG="tmux-${TMUX_VERSION}-${TARGET}"

mkdir -p "$CACHE" "$DIST"

fetch() {
  local url="$1" out="$2"
  [[ -s "$out" ]] || curl -fL --retry 3 "$url" -o "$out"
  tar tzf "$out" >/dev/null
}

fetch "https://invisible-mirror.net/archives/ncurses/ncurses-${NCURSES_VERSION}.tar.gz" "$CACHE/ncurses.tar.gz"
fetch "https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz" "$CACHE/libevent.tar.gz"
fetch "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz" "$CACHE/tmux.tar.gz"

rm -f "$DIST/$PKG.tar.gz"

docker run --rm \
  -e TMUX_VERSION -e NCURSES_VERSION -e LIBEVENT_VERSION -e PKG \
  -v "$CACHE:/src:ro" \
  -v "$DIST:/dist" \
  centos:7 bash -euxo pipefail -c '
    sed -i "s/mirrorlist/#mirrorlist/g" /etc/yum.repos.d/CentOS-Base.repo
    sed -i "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" /etc/yum.repos.d/CentOS-Base.repo
    yum clean all
    yum makecache
    yum install -y gcc make automake pkgconfig byacc tar gzip

    mkdir -p /build /opt/tmux

    cd /build
    tar xzf /src/ncurses.tar.gz
    cd ncurses-${NCURSES_VERSION}
    ./configure --prefix=/opt/tmux --with-shared --with-termlib --enable-pc-files \
      --with-pkg-config-libdir=/opt/tmux/lib/pkgconfig --without-tests --without-manpages
    make -j"$(nproc)"
    make install

    cd /build
    tar xzf /src/libevent.tar.gz
    cd libevent-${LIBEVENT_VERSION}
    ./configure --prefix=/opt/tmux --enable-shared --disable-openssl
    make -j"$(nproc)"
    make install

    cd /build
    tar xzf /src/tmux.tar.gz
    cd tmux-${TMUX_VERSION}
    PKG_CONFIG_PATH=/opt/tmux/lib/pkgconfig \
    CPPFLAGS="-I/opt/tmux/include" \
    LDFLAGS="-L/opt/tmux/lib -Wl,-rpath,\$ORIGIN/../lib" \
      ./configure --prefix=/opt/tmux
    make -j"$(nproc)"
    make install

    mkdir -p /opt/tmux/libexec
    mv /opt/tmux/bin/tmux /opt/tmux/libexec/tmux.real
    cat >/opt/tmux/bin/tmux <<"WRAP"
#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LD_LIBRARY_PATH="$ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export TERMINFO="$ROOT/share/terminfo"
export TERMINFO_DIRS="$ROOT/share/terminfo:"
exec "$ROOT/libexec/tmux.real" "$@"
WRAP
    chmod +x /opt/tmux/bin/tmux

    /opt/tmux/bin/tmux -V
    test -d /opt/tmux/share/terminfo
    mkdir -p "/package/${PKG}"
    cp -a /opt/tmux/. "/package/${PKG}/"
    tar -C /package -czf "/dist/${PKG}.tar.gz" "$PKG"
  '

echo "$DIST/$PKG.tar.gz"
