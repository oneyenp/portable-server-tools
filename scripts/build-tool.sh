#!/usr/bin/env bash
set -euo pipefail

TOOL="${1:-}"
TARGET="${2:-el7-amd64}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$TOOL" in
  tmux|jq|neovim) ;;
  *) echo "Usage: $0 {tmux|jq|neovim} [el7-amd64]" >&2; exit 2 ;;
esac

if [[ "$TARGET" != "el7-amd64" ]]; then
  echo "Unsupported target: $TARGET" >&2
  exit 2
fi

mkdir -p "$ROOT/.cache" "$ROOT/dist"
exec "$ROOT/tools/$TOOL/build.sh" "$TARGET"
