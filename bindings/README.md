# Citum Language Bindings

This directory contains language-specific bindings and documentation for
interfacing with the **Citum** citation processor from other environments.

## Integration Strategies

There are two ways to call Citum from a non-Rust environment:

### A. C FFI (shared library)

The FFI exports a C-compatible ABI from `libcitum_engine`. Build it with:

```bash
cargo build --package citum-engine --release --features ffi
```

This produces:
- `libcitum_engine.so` (Linux)
- `libcitum_engine.dylib` (macOS)
- `citum_engine.dll` (Windows)

Best for environments where loading a native shared library is straightforward
(LuaJIT, Python ctypes, Node napi).

### B. Pipe transport (citum-server)

`citum-server` speaks newline-delimited JSON-RPC over stdin/stdout. Build a
stdio-only binary (no HTTP/async dependency) with:

```bash
cargo build --package citum-server --release --no-default-features
```

Best for **TeX Live distribution** and other contexts where packages may not
include compiled shared libraries. The LuaLaTeX binding automatically uses pipe
mode when `libcitum_engine` is not found and `citum-server` is available on
`PATH` (or `CITUM_SERVER_PATH` is set). No configuration needed.

## For Developers

### Lua / LuaLaTeX
See [bindings/lua/lua-latex.md](./lua/lua-latex.md) for detailed integration
instructions.

### Python
Python developers can use `ctypes` or `cffi` to load the shared library.
*Example coming soon.*

### JavaScript / Node.js
Use `node-ffi-napi` or the native FFI support in Bun/Deno.
*Example coming soon.*

## FFI API Specification

The FFI exports the following C-compatible symbols:

### Lifecycle

- `citum_processor_new(style_json, bib_json)`: Initialize from JSON strings.
- `citum_processor_new_with_locale(style_json, bib_json, locale_json)`: Initialize from JSON with a locale.
- `citum_processor_new_from_yaml(style_yaml, bib_yaml)`: Initialize from YAML strings (preferred for Lua/LaTeX consumers).
- `citum_processor_new_with_locale_from_yaml(style_yaml, bib_yaml, locale_yaml)`: Initialize from YAML with a locale.
- `citum_processor_free(processor)`: Safely deallocate the processor.

### Citation rendering

- `citum_render_citation_latex`, `_html`, `_plain`, `_djot`, `_typst`: Render a single citation.
- `citum_render_citations_json(processor, citations_json, format)`: Render a batch of citations; `format` is one of `latex`, `html`, `plain`, `djot`, `typst`.

### Bibliography rendering

- `citum_render_bibliography_latex`, `_html`, `_plain`, `_djot`, `_typst`: Render the full bibliography.
- `citum_render_bibliography_grouped_html`, `_grouped_plain`: Render a grouped bibliography.

### Utilities

- `citum_version()`: Return the engine version string.
- `citum_get_last_error()`: Return the last error message (call after a null return).
- `citum_string_free(s)`: Free any string returned by the FFI.

See `crates/citum-engine/src/ffi/mod.rs` in the citum-core repository for the
full C signatures.
