#!/usr/bin/env bash
# Bootstrap dotagents on a machine: make sure Node meets requirements.json
# (using nvm when it's installed), then hand off to `bin/dotagents setup`, which
# installs the pinned rulesync, links ~/.aiglobal, installs external skills and
# agents, generates every tool's files and finishes with `doctor`.
#
#   ./setup.sh            set up / repair
#   ./setup.sh --check    only run doctor (no changes)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIN_NODE="$(sed -n 's/.*"node": *">=\([0-9.]*\)".*/\1/p' "$ROOT/requirements.json")"

ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

node_ok() {
  command -v node >/dev/null 2>&1 && ver_ge "$(node -p process.versions.node)" "$MIN_NODE"
}

if [ "${1:-}" = "--check" ]; then
  node_ok || { echo "FAIL  node ${MIN_NODE}+ required (found: $(node -v 2>/dev/null || echo none))"; exit 1; }
  exec node "$ROOT/bin/dotagents" doctor
fi

if ! node_ok; then
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
    echo "Node $(node -v 2>/dev/null || echo none) is older than $MIN_NODE; installing Node 22 with nvm"
    nvm install 22
    nvm use 22 >/dev/null
    nvm alias default 22 >/dev/null
  else
    echo "Node $MIN_NODE+ is required (found: $(node -v 2>/dev/null || echo none))."
    echo "Install it (https://nodejs.org or nvm), then re-run ./setup.sh."
    exit 1
  fi
fi

exec node "$ROOT/bin/dotagents" setup "$@"
