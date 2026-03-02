# Citum LuaLaTeX Integration

The Citum processor can be used directly inside LuaLaTeX documents via a
LuaJIT FFI binding to the Rust shared library. No Biber, no `.bbl` file,
and no shell-escape are required — citations and bibliography are rendered in
a single `lualatex` pass.

## Architecture

```
.tex  \cite{key}
  └─► \directlua  ──► citum.lua (LuaJIT FFI)  ──► libcitum_processor (Rust)
                                                         │
                         tex.sprint(rendered) ◄──────────┘
```

1. **Core logic (Rust)** — all citation rules, disambiguation, locale terms,
   and formatting live in the Citum engine.
2. **C FFI layer** — thin `#[no_mangle]` exports in `crates/citum-engine/src/ffi.rs`.
3. **Lua binding** — `bindings/lua/citum.lua` wraps the FFI and provides a
   clean Lua API including a helper for the full Citum citation model.
4. **LaTeX package** — `bindings/latex/citum.sty` wires the Lua API into
   standard LaTeX citation commands.

---

## Quick start

### 1 — Build the shared library

```bash
cargo build --package citum_engine --release --features ffi
```

This produces:
- `target/release/libcitum_processor.dylib` (macOS)
- `target/release/libcitum_processor.so` (Linux)
- `target/release/citum_engine.dll` (Windows)

### 2 — Make the library findable

Either set `CITUM_LIB_PATH` to the absolute path of the `.dylib`/`.so`, or
copy / symlink it into your document directory.

### 3 — Compile your document

```bash
lualatex citum-example.tex
```

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
