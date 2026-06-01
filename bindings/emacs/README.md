# Citum Emacs Binding — `oc-citum`

An [Org mode `org-cite`](https://orgmode.org/manual/Citations.html) export
processor that drives the Citum citation engine over a
newline-delimited JSON-RPC pipe.  **Zero FFI** — Emacs spawns
`citum-server` as a subprocess, sends one `format_document` request per
export, and reads one line of JSON back.

Works with any `.bib` bibliography, including your existing
[citar](https://github.com/emacs-citar/citar) library.

## Requirements

| Requirement | Version | Notes |
|-------------|---------|-------|
| Emacs | ≥ 29.1 | uses `json-parse-string` / `json-serialize` |
| Org mode | ≥ 9.6 | ships with Emacs 29+ |
| `citum-server` | ≥ 0.62 (biblatex support) | on `PATH` or set `CITUM_SERVER_PATH` |

### Install `citum-server`

`oc-citum` passes bibliography data as inline BibLaTeX
(`{"kind":"biblatex","value":"..."}`) which requires citum-server built
from the `feat/biblatex-refs-input` branch of citum-core or any release
≥ 0.62.  Using an older binary will produce a confusing parse error.

```bash
# Build the biblatex-capable server from source:
git clone https://github.com/citum/citum-core
cd citum-core
git checkout feat/biblatex-refs-input   # until merged to main
cargo build -p citum-server --release --no-default-features
export CITUM_SERVER_PATH="$PWD/target/release/citum-server"
```

The `--no-default-features` flag builds a lightweight stdio-only binary
(no HTTP/async dependencies).

## Quick Start (export only, no citar)

Add to your Emacs config:

```elisp
(add-to-list 'load-path "/path/to/citum-labs/bindings/emacs")
(require 'oc-citum)

;; Use citum as the default export processor for all backends
(setq org-cite-export-processors '((t . (citum))))

;; Your bibliography (also used by citar if configured)
(setq org-cite-global-bibliography '("/path/to/refs.bib"))
```

In any Org document:

```org
#+cite_export: citum
#+bibliography: refs.bib
```

Then export normally: `C-c C-e h h` (HTML), `C-c C-e l p` (LaTeX PDF), etc.

## citar Integration

citar handles **insert / follow / activate**; `oc-citum` handles **export**.
They share the same `.bib` file:

```elisp
;; Your bibliography — shared between citar and oc-citum
(setq citar-bibliography '("/path/to/refs.bib"))
(setq org-cite-global-bibliography citar-bibliography)

;; citar for in-buffer operations
(setq org-cite-insert-processor   'citar
      org-cite-follow-processor   'citar
      org-cite-activate-processor 'citar)

;; citum for export (all backends)
(setq org-cite-export-processors '((t . (citum))))
```

Per-backend overrides are also supported:

```elisp
(setq org-cite-export-processors
      '((latex . (citum "apa"))       ; APA on LaTeX
        (html  . (citum "chicago"))   ; Chicago on HTML
        (t     . (citum))))           ; default APA for rest
```

The second element is a style id or path passed to citum-server as
`{"kind":"id","value":"apa"}` or `{"kind":"path","value":"/abs/style.yaml"}`.

## Supported Citation Styles

Declare styles with `[cite/STYLE/VARIANT:@key]` in Org documents.

| Style | Shortcut | Citum mapping | Example output |
|-------|----------|---------------|---------------|
| *(default)* | — | `mode: non-integral` | `(Author, 2024)` |
| `text` | `t` | `mode: integral` | `Author (2024)` |
| `author` | `a` | `mode: integral` | `Author (2024)` |
| `noauthor` | `na` | `suppress_author: true` | `(2024)` |
| `year` | `y` | `suppress_author: true` | `(2024)` |
| `nocite` | `n` | included in bibliography only | `(Author, 2024)` *(inline suppression pending)* |

### Variants (append after a second `/`)

| Variant | Shortcut | Effect |
|---------|----------|--------|
| `caps` | `c` | Capitalize first character |
| `bare` | `b` | Strip surrounding brackets/parens |
| `bare-caps` | `bc` | Both |
| `full` | `f` | *(reserved; no-op in current implementation)* |
| `caps-full` | `cf` | Capitalize + full |
| `bare-caps-full` | `bcf` | All three |

**Example styles:**

```org
[cite:@key]              → (Author, 2024)
[cite/t:@key]            → Author (2024)
[cite/na:@key]           → (2024)
[cite//c:@key]           → (Author, 2024)  ← capitalized first char
[cite/t//c:@key]         → Author (2024)   ← integral + caps
[cite:@key p. 42]        → (Author, 2024, p. 42)
[cite:@a; @b]            → (A, 2024; B, 2020)
[cite/n:@key]            → (Author, 2024)  ← also renders inline (see limitations)
```

**Known limitations / best-effort styles:**

- `author`/`a` renders as integral (same as `text`/`t`); author-only
  suppression is not independently modelled by Citum.
- `nocite`/`n` currently renders a full parenthetical citation inline
  in addition to adding the entry to the bibliography (Citum does not
  suppress the inline render independently of the bibliography pass).
- Non-en-US locales: `oc-citum-locale` is forwarded to the server but
  Citum currently warns and falls back to en-US for most non-en-US tags.

## Configuration Reference

```elisp
;; Path to citum-server (default: CITUM_SERVER_PATH env var → "citum-server")
(setq oc-citum-server-path "/usr/local/bin/citum-server")

;; Default style (nil → APA via server's built-in resolver)
(setq oc-citum-style '(:kind "path" :value "/abs/path/chicago.yaml"))

;; Locale for rendering (nil → en-US)
(setq oc-citum-locale "de-DE")
```

## Running the Demo

```bash
cd bindings/emacs/demo

# Use the system-installed citum-server (if on PATH):
./run-demo.sh

# Or point at a locally-built binary:
CITUM_SERVER_PATH=/path/to/target/release/citum-server ./run-demo.sh

# Export only plain text or HTML:
./run-demo.sh --plain
./run-demo.sh --html
```

This exports `citum-demo.org` (which uses all citation styles in this
directory's `refs.bib`) to `citum-demo.txt` and `citum-demo.html`.

## How It Works

1. On the first `:export-citation` call, `oc-citum` gathers **all** citations
   in document order via `org-cite-list-citations`, serialises them as
   `CitationOccurrence` objects, reads the `.bib` file(s) and sends one
   `format_document` JSON-RPC request to `citum-server` via `call-process-region`.
2. `citum-server` parses the BibLaTeX input (via the `biblatex` crate →
   Citum schema), runs the style, and returns all rendered citations plus the
   full bibliography in a single JSON response line.
3. Results are memoised in the Org export communication channel (`info`).
   Subsequent citation callbacks and the bibliography callback are pure
   table lookups — no additional process spawning.

This single-round-trip design ensures proper cross-citation disambiguation
and author-name abbreviation, which require global document context.

## Comparison with the LaTeX binding

| | LaTeX (`citum.sty`) | Emacs (`oc-citum`) |
|-|---------------------|--------------------|
| Transport | Pipe (via LuaTeX) | Pipe (via `call-process-region`) |
| FFI | Optional (preferred) | None |
| Passes | 2 (LaTeX multi-pass) | 1 |
| Bib format | Citum YAML | `.bib` (biblatex) |
| Persistent server | No | No |
