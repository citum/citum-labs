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
- `rpc`: Boolean (default `false`, but automatically enabled if the Rust library is missing). If `true`, forces the use of a remote Citum server.

## RPC Mode (Automatic Fallback)

If the Citum Rust shared library (`libcitum_processor`) is not found on your system, the package will **automatically fallback to RPC mode**. This allows you to use Citum without installing custom binaries in your TeX path, provided you have the server running.

1. **Install and run `citum-server`**:
   ```bash
   # Run the server on the default port 9000
   citum-server --port 9000
   ```
2. **Compile as usual**:
   ```latex
   \usepackage[style=apa-7th, bibfile=refs]{citum}
   ```
   The package will detect the missing library and attempt to connect to the server at `localhost:9000`. You can also force RPC mode by adding the `rpc` option: `\usepackage[rpc, ...]{citum}`.

## Requirements & Workflow

- **LuaLaTeX**: This package requires LuaLaTeX.
- **Multi-pass**: Because Citum handles complex disambiguation and numbering, it requires a **two-pass workflow** (similar to BibTeX or Biber).
  - Pass 1: Collects citation keys and generates a `.citum.json` cache file.
  - Pass 2: Renders the final citations and bibliography using the cache.
- **Citum Backend**: Requires either the Citum shared library (`libcitum_processor`) or a running `citum-server` instance.
