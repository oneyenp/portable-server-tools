# portable-server-tools

Portable server-side CLI builds for older Linux hosts, with EL7/glibc 2.17 compatibility as the default target.

Initial tools:
- tmux 3.7b
- jq 1.8.2
- Neovim 0.12.4

## Design

Each tool has an isolated recipe under `tools/<name>/build.sh`. GitHub Actions calls the common dispatcher `scripts/build-tool.sh`, and every build produces a tarball in `dist/`.

Current target:
- `el7-amd64`

Build strategies:
- **tmux**: portable bundle with bundled ncurses, libevent, terminfo, and a wrapper that sets runtime paths.
- **jq**: statically linked binary using jq's bundled oniguruma.
- **neovim**: source build inside a manylinux2014 container to keep a glibc 2.17 ABI baseline; dependencies are bundled by Neovim's build.

## Local build

Requirements: Docker, curl, tar.

```bash
./scripts/build-tool.sh tmux el7-amd64
./scripts/build-tool.sh jq el7-amd64
./scripts/build-tool.sh neovim el7-amd64
```

Artifacts are written to `dist/`.

## GitHub Actions

Run **Build portable tools** manually and choose `all`, `tmux`, `jq`, or `neovim`.

## Install example

```bash
tar xzf tmux-3.7b-el7-amd64.tar.gz
export PATH="$PWD/tmux-3.7b-el7-amd64/bin:$PATH"
tmux -V
```

The tmux wrapper automatically sets `LD_LIBRARY_PATH`, `TERMINFO`, and `TERMINFO_DIRS` relative to the extracted directory.
