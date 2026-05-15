# Citum LaTeX Package

This directory contains the `citum.sty` package, which brings the Citum citation engine to LuaLaTeX.

## Usage

```latex
\usepackage[style=apa-7th, bibfile=refs]{citum}
```

### Options

- `style`: Path to a Citum YAML style (e.g., `apa-7th`).
- `bibfile`: Path to a Citum YAML bibliography (e.g., `refs.yaml`).
- `locale`: Optional BCP 47 locale (e.g., `en-US`).
- `rpc`: Boolean (default `false`). If `true`, uses a remote Citum server instead of the local shared library.

## RPC Mode (Fallback)

If you cannot or do not want to use the Citum Rust shared library (`libcitum_processor`), you can use **RPC mode**. This is the recommended way to distribute Citum-powered documents without requiring custom binaries.

1. **Install and run `citum-server`**:
   ```bash
   # Run the server on the default port 9000
   citum-server --port 9000
   ```
2. **Enable RPC in your document**:
   ```latex
   \usepackage[rpc, style=apa-7th, bibfile=refs]{citum}
   ```

## Requirements & Workflow

- **LuaLaTeX**: This package requires LuaLaTeX.
- **Multi-pass**: Because Citum handles complex disambiguation and numbering, it requires a **two-pass workflow** (similar to BibTeX or Biber).
  - Pass 1: Collects citation keys and generates a `.citum.json` cache file.
  - Pass 2: Renders the final citations and bibliography using the cache.
- **Citum Backend**: Requires either the Citum shared library (`libcitum_processor`) or a running `citum-server` instance.
