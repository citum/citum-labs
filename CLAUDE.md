# Citum Labs — Project Instructions

> **Scope**: This file covers `citum-labs`-specific rules only.
> If you have the full Citum monorepo, `../CLAUDE.md` provides cross-repo context.
> The conventions in `citum-core/CLAUDE.md` (commit format, agent roles, bean workflow)
> apply here too — read that file if available, or see
> https://github.com/citum/citum-core for shared norms.

**All responses must be in English**, overriding any global language preference.

## What Lives Here

| Path | Language | Purpose |
|------|----------|---------|
| `bindings/lua/citum.lua` | Lua (LuaJIT FFI) | Lua binding + LuaLaTeX integration |
| `bindings/latex/citum.sty` | LaTeX / LuaLaTeX | `\citum` package |
| `bindings/latex/citum-example.tex` | LaTeX | Usage example |
| `site/` | HTML/CSS | Project website (deployed via GitHub Pages) |

No Rust lives here. All citation logic is in `citum-core`; this repo only consumes it.

## FFI Dependency

The Lua binding (`citum.lua`) loads `libcitum_processor` at runtime via LuaJIT FFI.
Before testing locally, build the shared library from `citum-core`.
If you have the monorepo checked out side-by-side (`../citum-core`):

```bash
cd ../citum-core
cargo build --package citum_engine --release --features ffi
```

Otherwise, clone it first:

```bash
git clone https://github.com/citum/citum-core
cd citum-core
cargo build --package citum_engine --release --features ffi
```

Output: `target/release/libcitum_processor.{dylib,so,dll}`.
The Lua binding searches `package.cpath` and `LD_LIBRARY_PATH` / `DYLD_LIBRARY_PATH`.

## Pre-Commit Checks

No `cargo` runs here. Apply these checks by file type:

| Changed files | Run |
|---------------|-----|
| `*.lua` | `luacheck bindings/lua/citum.lua` (if luacheck installed) |
| `*.sty`, `*.tex` | Manual review — no automated formatter required |
| `site/**` | None (static HTML, CI deploys on push to main) |
| `*.md` | None |

If `luacheck` is not installed, skip silently — do not block commits.

## Commit Messages

Follow the same Conventional Commits format as `citum-core`:
`type(scope): subject` — lowercase, 50/72 rule, no `Co-Authored-By` footers.

Relevant scopes: `lua`, `latex`, `site`, `bindings`, `docs`.

## Agents & Codex

Same agent table as `citum-core`:

| Agent | Role |
|-------|------|
| @planner | Quick planning (≤3 questions) |
| @dplanner | Deep planning + research |
| @builder | Implementation (2-retry cap, no questions) |
| @reviewer | QA after changes |

**Codex compatibility**: This repo has no build step for agents to run. Codex and
Copilot agents should treat `bindings/` as read-only file editing (Lua/LaTeX text),
not a compiled workspace. Do not attempt `cargo` or `npm` commands here.

## Site Deployment

`site/` deploys automatically via `.github/workflows/deploy_pages.yml` on push to
`main` when `site/**` changes. No manual deploy step needed.

## Confirmations Required

- `git push origin main` (branch protection via PR preferred)
- `gh pr create`
- Any change to `.github/workflows/`

## Task Management

Use `/beans` in `citum-core` for engine-related tasks. Labs-specific tasks can use
GitHub Issues on this repo.
