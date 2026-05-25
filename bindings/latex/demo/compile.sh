#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)/citum-core"

# citum.sty lives one level up; citum.lua two levels up
export TEXINPUTS="$SCRIPT_DIR/..:${TEXINPUTS:-}"
export CITUM_LUA_PATH="$SCRIPT_DIR/../../lua/citum.lua"

if [ "${1:-}" = "--pipe" ]; then
  # Pipe transport: look for citum-server on the PATH
  if ! command -v citum-server &> /dev/null; then
    echo "citum-server not found on PATH."
    read -p "Would you like to install it now? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      curl -fsSL https://github.com/citum/citum-core/releases/latest/download/install.sh | CITUM_COMPONENTS=citum-server sh
    else
      echo "error: citum-server is required for pipe transport." >&2
      exit 1
    fi
  fi
  export CITUM_SERVER_PATH="citum-server"
  unset CITUM_LIB_PATH || true
  echo "server  : $(command -v citum-server)"
else
  # FFI transport: locate libcitum_engine
  if [ -z "${CITUM_LIB_PATH:-}" ]; then
    CANDIDATE="$CORE_ROOT/target/release"
    for ext in dylib so dll; do
      if [ -f "$CANDIDATE/libcitum_engine.$ext" ]; then
        CITUM_LIB_PATH="$CANDIDATE/libcitum_engine.$ext"
        break
      fi
    done
  fi
  if [ -z "${CITUM_LIB_PATH:-}" ]; then
    echo "error: set CITUM_LIB_PATH or build with: cargo build -p citum-engine --release --features ffi" >&2
    exit 1
  fi
  export CITUM_LIB_PATH
  echo "library : $CITUM_LIB_PATH"
fi

echo "pass 1…"
lualatex --shell-escape --interaction=nonstopmode citum-example.tex
echo "pass 2…"
lualatex --shell-escape --interaction=nonstopmode citum-example.tex
echo "done → citum-example.pdf"
