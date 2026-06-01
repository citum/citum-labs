#!/usr/bin/env bash
# run-demo.sh — batch-export citum-demo.org via oc-citum
#
# Usage:
#   ./run-demo.sh            # export to plain text and HTML
#   ./run-demo.sh --html     # HTML only
#   ./run-demo.sh --plain    # plain text only
#
# Environment:
#   CITUM_SERVER_PATH  override path to citum-server binary (default: citum-server on PATH)
#   EMACS              override Emacs binary (default: emacs)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EMACS_BINDING="$SCRIPT_DIR/.."          # parent dir containing oc-citum.el
DEMO_ORG="$SCRIPT_DIR/citum-demo.org"

# ── Emacs ───────────────────────────────────────────────────────────────────
EMACS_BIN="${EMACS:-emacs}"
if ! command -v "$EMACS_BIN" &>/dev/null; then
  echo "error: emacs not found.  Install via 'brew install emacs' or set EMACS." >&2
  exit 1
fi
echo "emacs   : $(command -v "$EMACS_BIN") ($("$EMACS_BIN" --version 2>&1 | head -1))"

# ── citum-server ─────────────────────────────────────────────────────────────
if [ -n "${CITUM_SERVER_PATH:-}" ]; then
  export CITUM_SERVER_PATH
  echo "server  : $CITUM_SERVER_PATH (from CITUM_SERVER_PATH)"
elif command -v citum-server &>/dev/null; then
  echo "server  : $(command -v citum-server)"
else
  echo "error: citum-server not found on PATH." >&2
  echo "  Build from citum-core: cargo build -p citum-server --release --no-default-features" >&2
  echo "  Then: export CITUM_SERVER_PATH=/path/to/target/release/citum-server" >&2
  exit 1
fi

# ── Export modes ─────────────────────────────────────────────────────────────
DO_PLAIN=true
DO_HTML=true
case "${1:-}" in
  --html)  DO_PLAIN=false ;;
  --plain) DO_HTML=false ;;
esac

OUT_PLAIN="$SCRIPT_DIR/citum-demo.txt"
OUT_HTML="$SCRIPT_DIR/citum-demo.html"

# ── Emacs batch eval ─────────────────────────────────────────────────────────
run_export() {
  local backend="$1"
  local out_file="$2"
  "$EMACS_BIN" --batch \
    -L "$EMACS_BINDING" \
    --eval "(require 'oc-citum)" \
    --eval "(setq org-cite-export-processors '((t . (citum))))" \
    --eval "(find-file \"$DEMO_ORG\")" \
    --eval "(org-export-to-file '$backend \"$out_file\")" \
    2>&1
}

if $DO_PLAIN; then
  echo ""
  echo "── plain text export ────────────────────────────────────────────────"
  run_export ascii "$OUT_PLAIN"
  echo "output  : $OUT_PLAIN"
  echo ""
  grep -A 3 "^Introduction" "$OUT_PLAIN" || true
  echo "…"
  # Show the bibliography block
  sed -n '/^References/,$ p' "$OUT_PLAIN" | head -20 || true
fi

if $DO_HTML; then
  echo ""
  echo "── HTML export ──────────────────────────────────────────────────────"
  run_export html "$OUT_HTML"
  echo "output  : $OUT_HTML"
  echo ""
  # Show a snippet of citations rendered in HTML
  grep -o '<p>[^<]*<cite>[^<]*</cite>[^<]*</p>\|class="csl-entry"[^<]*>[^<]*' \
       "$OUT_HTML" | head -10 || \
  grep -o '(Chen.*)\|(Webb.*)\|(Tanaka.*)' "$OUT_HTML" | head -5 || true
fi

echo ""
echo "done."
