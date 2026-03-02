# Citum Labs

Welcome to **Citum Labs**, the companion repository for the [Citum](https://github.com/citum/citum) citation engine. 

This repository contains:
- **Language Bindings**: Interfaces for using Citum from environments like Lua, Python, and JavaScript.
- **LaTeX Integration**: The `citum.sty` package for modern, live citation rendering in LuaLaTeX.
- **Examples**: Demonstration documents and code samples.

## Project Name Change

Citum was formerly known as **CSLN** (Citation Style Language Next). We have renamed the project to better reflect its identity as a modern, high-performance citation system.

## Components

### [Bindings](./bindings/)
Citum provides a C-compatible FFI (Foreign Function Interface) that allows it to be integrated into almost any programming language.
- **Lua**: A high-level LuaJIT FFI binding used by our LaTeX integration.
- **LaTeX**: A package that brings Citum's power directly into LuaLaTeX without needing external tools like Biber.

### [Site](./site/)
The source for the Citum project website and documentation.

## Getting Started

To use the bindings in this repository, you will first need the Citum shared library (`libcitum_processor`). See the [Bindings README](./bindings/README.md) for build instructions.

## License

This project is licensed under the Apache License 2.0 or MIT License at your option.
