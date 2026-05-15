# Citum LuaLaTeX Integration

The Citum processor can be used directly inside LuaLaTeX documents via two
different backends: a fast LuaJIT FFI binding to the Rust shared library,
or a network-based RPC fallback to a standalone `citum-server`.

## Architecture

```
.tex  \cite{key}
  └─► \directlua  ──► citum.lua (Record key)
                               │
            Pass 1: Cache list of all citations
            Pass 2: Load results from .citum.json ──► tex.sprint
                               │
    \AtEndDocument ──► Process Document ──► [FFI or RPC Backend]
                                                      │
                         Save results to .citum.json ◄┘
```

1. **Stateful Tracking** — Citum now uses a **multi-pass workflow** (like BibTeX or Biber). Lua collects all citations during the first pass and processes them in a single batch at the end of the run.
2. **Backends**:
   - **FFI**: Direct in-process call to `libcitum_processor`. Highest performance.
   - **RPC**: HTTP/JSON-RPC call to `citum-server`. Recommended for distribution where Rust binaries cannot be bundled (e.g., official TeX Live packages).
3. **Cache** — Results are stored in `\jobname.citum.json`. If citations change, LaTeX emits a warning to rerun the document.

---

## Quick start

### Method A: Local Shared Library (FFI)

1. **Build the shared library**:
   ```bash
   cargo build --package citum_engine --release --features ffi
   ```
2. **Make it findable**: Set `CITUM_LIB_PATH` to the absolute path of the `.dylib`/`.so`.
3. **Compile**: `lualatex citum-example.tex`

### Method B: Citum Server (RPC)

1. **Run the server**:
   ```bash
   citum-server --port 9000
   ```
2. **Configure LaTeX**:
   ```latex
   \usepackage[style=..., bibfile=...]{citum}
   ```
   If the shared library is not found, Citum **automatically falls back to RPC mode**. You can also force it with the `rpc` option if the library is present but you prefer the server.

3. **Compile twice**: `lualatex doc.tex` (Pass 1), then `lualatex doc.tex` (Pass 2).

---

## LaTeX package (`citum.sty`)

```latex
\usepackage[style=apa-7th, bibfile=refs]{citum}               % Citum YAML bib
\usepackage[style=apa-7th, bibfile=refs.bib, locale=fr-FR]{citum} % with locale
```

The bibliography format is selected automatically by file extension:
`.bib` → biblatex parser; anything else → Citum YAML parser.

### Package Options

| Option | Description |
|---|---|
| `style` | Path to a Citum YAML style file (extension optional) |
| `bibfile` | Path to a bibliography file (.yaml or .bib) |
| `locale` | Optional locale name (e.g., `en-GB`, `fr-FR`) |
| `rpc` | Use `citum-server` via RPC instead of FFI (default: `false`) |

### Citation commands

All commands are **style-driven** — punctuation, brackets, and output form
are determined by the style YAML, not by the command name.

| Command | Citum model |
|---|---|
| `\cite[loc]{key}` | non-integral; optional locator |
| `\cite[pre][suf]{key}` | non-integral; item prefix + suffix |
| `\cites{k1, k2, k3}` | non-integral; comma-separated keys |
| `\textcite[loc]{key}` | integral (author in running text) |
| `\textcites{k1, k2}` | integral; multiple keys |
| `\citestart` / `\citeitem[loc]{key}` / `\citeend` | multi-item with per-item locators |
| `\printcitumbibliography` | full bibliography |
| `\printbibliography` | alias for the above |

Locator labels are inferred from biblatex optional-argument conventions:
`p.` / `pp.` → `page`, `ch.` → `chapter`, `§` → `section`, `vol.` → `volume`, etc.
A bare number defaults to `page`.

### Library / Lua path resolution

| Env var | Effect |
|---|---|
| `CITUM_LIB_PATH` | Absolute path to the shared library |
| `CITUM_LUA_PATH` | Absolute path to `citum.lua` |

If neither is set, the package looks for `citum.lua` alongside `citum.sty`,
then falls back to `kpse` resolution.

---

## Lua API (`citum.lua`)

```lua
local citum = require("citum")

-- Engine information
print(citum.version())

-- File-based constructors (preferred for LaTeX use)
local proc = citum.from_yaml("/path/to/style.yaml", "/path/to/refs.yaml")
local proc = citum.from_bib("/path/to/style.yaml", "/path/to/refs.bib")

-- In-memory JSON constructor (lower-level)
local proc = citum.new(style_json, bib_json)
local proc = citum.new_with_locale(style_json, bib_json, locale_json)

-- Error handling
if not proc then
    print(citum.get_last_error())
end

-- Render a single citation (bare key shorthand)
local s = proc:render_citation("kuhn1962")

-- Batch rendering (returns JSON array of strings)
local results = proc:render_citations_batch({
  { id = "kuhn1962" },
  { id = "lecun2015", mode = "integral" }
}, "latex")

-- Render bibliography
local bbl = proc:render_bibliography()

-- Additional output formats
local s = proc:render_citation_html(opts)
local s = proc:render_citation_djot(opts)
local s = proc:render_citation_typst(opts)

local bbl = proc:render_bibliography_grouped_html()

proc:free()   -- optional; GC finalizer handles this automatically
```

---

## Example document

See `bindings/latex/citum-example.tex` for a full document that demonstrates:
- Integral citations with `\textcite`
- Non-integral citations with and without locators
- Multi-key citations with `\cites`
- Per-item locators with `\citestart` / `\citeitem` / `\citeend`
- Bibliography rendering with `\printcitumbibliography`

---

## Comparison with `citeproc-lua`

While `citeproc-lua` is a pure-Lua implementation of CSL 1.0, Citum offers:

- **Declarative YAML styles** — easier to author and read than CSL 1.0 XML
- **Native EDTF date support** — covers intervals, approximate dates, and seasons
- **Multilingual data model** — structured per-language title and contributor data
- **Performance** — disambiguation, sorting, and template rendering in Rust
