#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)/citum-core"

# citum.sty lives one level up; citum.lua two levels up
export TEXINPUTS="$SCRIPT_DIR/..:${TEXINPUTS:-}"
export CITUM_LUA_PATH="$SCRIPT_DIR/../../lua/citum.lua"

if [ "${1:-}" = "--pipe" ]; then
  # Pipe transport: build citum-server (stdio-only, no HTTP/tokio)
  echo "building citum-server (stdio-only)…"
  cargo build --manifest-path "$CORE_ROOT/Cargo.toml" \
    -p citum-server --release --no-default-features
  export CITUM_SERVER_PATH="$CORE_ROOT/target/release/citum-server"
  unset CITUM_LIB_PATH || true
  echo "server  : $CITUM_SERVER_PATH"
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
