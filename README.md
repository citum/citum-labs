# Citum Labs

Welcome to **Citum Labs**, the companion repository for the [Citum](https://github.com/citum/citum) citation engine. 

This repository contains:
- **Language Bindings**: Interfaces for using Citum from environments like Lua, Python, and JavaScript.
- **LaTeX Incubator History**: The original experimental `citum.sty` binding. Current LuaLaTeX work lives in the standalone `citum-latex` repository.
- **Examples**: Demonstration documents and code samples.

## Project Name Change

Citum was formerly known as **CSLN** (Citation Style Language Next). We have renamed the project to better reflect its identity as a modern, high-performance citation system.

## Components

### [Bindings](./bindings/)
Citum provides a C-compatible FFI (Foreign Function Interface) that allows it to be integrated into almost any programming language.
- **Lua**: A high-level LuaJIT FFI binding retained for experiments.
- **LaTeX**: Historical LuaLaTeX binding code. Use `citum-latex` for the pipe-only package built around `citum-server`.

### [Site](./site/)
The source for the Citum project website and documentation.

## Getting Started

To use the bindings in this repository, you will first need the Citum shared library (`libcitum_processor`). See the [Bindings README](./bindings/README.md) for build instructions.

## License

This project is licensed under the Apache License 2.0 or MIT License at your option.
