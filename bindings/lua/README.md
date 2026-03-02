# Citum Lua Bindings

This directory contains the LuaJIT FFI bindings for the **Citum** citation engine.

## Contents

- `citum.lua`: The main Lua binding that interfaces with the Citum Rust core (`libcitum_processor`).
- [LuaLaTeX Integration Guide](./lua-latex.md): Detailed instructions on using Citum within LuaLaTeX documents.

## Usage in Lua

```lua
local citum = require("citum")

-- Check version
print("Citum Engine v" .. citum.version())

-- Initialize a processor
local proc = citum.from_yaml("style.yaml", "refs.yaml")

-- Render a citation
print(proc:render_citation("key"))

-- Render bibliography in HTML
print(proc:render_bibliography_html())

-- Batch rendering
local batch = {
  { id = "kuhn1962", locator = "52", label = "page" },
  { id = "lecun2015", mode = "integral" }
}
local results = proc:render_citations_batch(batch, "html")

-- Cleanup
proc:free()
```

## Supported Formats

The following rendering formats are supported for both citations and bibliographies:
- `latex`
- `html`
- `plain`
- `djot` (New)
- `typst` (New)

## Requirements

- **LuaJIT**: Required for the `ffi` module.
- **Citum Shared Library**: You must have `libcitum_processor.so` (Linux), `libcitum_processor.dylib` (macOS), or `citum_engine.dll` (Windows) available on your system.
