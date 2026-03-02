# Citum LaTeX Package

This directory contains the `citum.sty` package, which brings the Citum citation engine to LuaLaTeX.

## Usage

```latex
\usepackage[style=apa-7th, bibfile=refs]{citum}
```

For full documentation and integration details, see:
- [Citum LuaLaTeX Integration Guide](../lua/lua-latex.md)
- [Example Document](./citum-example.tex)

## Requirements

- **LuaLaTeX**: This package uses LuaJIT FFI and requires LuaLaTeX.
- **Citum Library**: You must have `libcitum_processor` available on your system.
- **citum.lua**: The Lua binding must be in your Lua path or in the same directory as `citum.sty`.
