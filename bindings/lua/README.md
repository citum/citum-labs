# Citum Lua Bindings

This directory contains the LuaJIT FFI bindings for the **Citum** citation engine.

## Contents

- `citum.lua`: The main Lua binding that interfaces with the Citum Rust core (`libcitum_processor`).
- [LuaLaTeX Integration Guide](./lua-latex.md): Detailed instructions on using Citum within LuaLaTeX documents.

## Usage in Lua

```lua
local citum = require("citum")

-- Initialize a processor
local proc = citum.from_yaml("style.yaml", "refs.yaml")

-- Render a citation
print(proc:render_citation("key"))

-- Cleanup
proc:free()
```

## Requirements

- **LuaJIT**: Required for the `ffi` module.
- **Citum Shared Library**: You must have `libcitum_processor.so` (Linux), `libcitum_processor.dylib` (macOS), or `citum_engine.dll` (Windows) available on your system.
