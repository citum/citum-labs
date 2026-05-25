# Citum Python Bindings

This directory contains a lightweight Python wrapper for the **Citum** citation processor using `ctypes`.

## Prerequisites

You must have the Citum shared library (`libcitum_processor`) built and available on your system.

### Build Instructions

From the core Citum repository:

```bash
cargo build --package citum-engine --release --features ffi
```

This will produce:
- `libcitum_engine.dylib` (macOS)
- `libcitum_engine.so` (Linux)
- `citum_engine.dll` (Windows)

## Installation

Simply copy `citum.py` into your project or add this directory to your `PYTHONPATH`.

## Quick Start

```python
from citum import CitumProcessor

# Initialize from YAML strings or files
style_yaml = """
# Your Citum Style YAML here
"""
bib_yaml = """
# Your Citum Bibliography YAML here
"""

# Or load from files
with open("style.yaml", "r") as f: style_yaml = f.read()
with open("refs.yaml", "r") as f: bib_yaml = f.read()

processor = CitumProcessor.from_yaml(style_yaml, bib_yaml)

# Render a citation
print(processor.render_citation("some-bib-id", format="plain"))

# Render the bibliography
print(processor.render_bibliography(format="html"))
```

## Configuration

The wrapper looks for the Citum shared library in the following order:
1. The path specified in the `CITUM_LIB_PATH` environment variable.
2. The current working directory.
3. Standard system library paths.

## Supported Formats

- `latex`
- `html`
- `plain`
- `djot`
- `typst`
