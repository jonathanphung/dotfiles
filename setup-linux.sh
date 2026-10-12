#!/usr/bin/env bash
set -euo pipefail
if ! command -v python3 >/dev/null 2>&1; then
  echo 'Install Python 3.9+ with your Linux package manager first.' >&2
  exit 1
fi
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$repo_dir/scripts/setup_linux.py" "$@"
