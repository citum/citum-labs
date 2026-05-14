# Citum Language Bindings

This directory contains language-specific bindings and documentation for interfacing with the **Citum** citation processor from other environments.

## The C-FFI Strategy

Citum is designed to be a high-performance, universal citation engine. To support languages like **Python, JavaScript (Node/Bun), Ruby, and Lua**, we provide a C-compatible Foreign Function Interface (FFI).

### Why FFI?
*   **Performance**: Avoid the overhead of re-implementing complex citation logic in interpreted languages.
*   **Consistency**: Ensure the exact same rendering logic is used across a web app (Python/JS) and a document (LaTeX).
*   **Single Source of Truth**: All citation rules, disambiguation, and locale logic reside in the Rust core.

## Enabling FFI

The FFI exports are feature-gated to maintain a safe, dependency-free core for Rust users. To build the shared library with FFI support:

```bash
cargo build --package citum_engine --release --features ffi
```

This will produce:
- `libcitum_processor.so` (Linux)
- `libcitum_processor.dylib` (macOS)
- `citum_engine.dll` (Windows)

## For Developers

### Lua / LuaLaTeX
See [bindings/lua/lua-latex.md](./lua/lua-latex.md) for detailed integration instructions using LuaJIT FFI.

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

See `crates/citum-engine/src/ffi/mod.rs` in the citum-core repository for the full C signatures.
