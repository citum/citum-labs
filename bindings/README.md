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

- `citum_processor_new`: Initialize a stateful processor with Style and Bibliography JSON.
- `citum_processor_new_with_locale`: Initialize with a specific Locale JSON.
- `citum_processor_free`: Safely deallocate the processor.
- `citum_render_citation_latex`: Render a citation to LaTeX.
- `citum_render_citation_html`: Render a citation to HTML.
- `citum_render_citation_plain`: Render a citation to Plain Text.
- `citum_render_bibliography_latex`: Render the full bibliography to LaTeX.
- `citum_render_bibliography_html`: Render the full bibliography to HTML.
- `citum_render_bibliography_plain`: Render the full bibliography to Plain Text.
- `citum_string_free`: Free strings allocated by the Rust core.

See `crates/citum-engine/src/ffi.rs` in the Citum core repository for the full C signatures.
