# Citum LuaLaTeX Binding

This directory contains the original experimental LuaLaTeX binding from
`citum-labs`.

The production-facing package has moved to the standalone `citum-latex`
repository. That package is pipe-only: it talks to `citum-server` over
stdin/stdout JSON-RPC and does not load a Rust shared library through FFI.

Use `citum-latex` for current LuaLaTeX work.

## Historical Note

The labs binding helped validate the Citum citation API, the C FFI surface, and
the `citum-server` document-formatting protocol. Its FFI mode is retained here
only as incubator history, not as the recommended LaTeX integration path.
