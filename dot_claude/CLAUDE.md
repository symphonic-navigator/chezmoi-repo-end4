# Claude Code — Global User Preferences

## Identity & Context

- User: **Chris**
- OS: Linux (Hyprland)
- Primary role: C# backend developer
- Editors/IDEs: **Rider** (C#), **VSCode** (general), **LazyVim** (quick edits)

## Language

- **Communicate** with me in **German**
- All **code, comments, variable names, documentation, READMEs, and other artefacts** must be in **British English**
- Prefer British spelling: `colour`, `initialise`, `behaviour`, `licence` (noun), `authorise`, etc.

## Workflow & Communication Style

- **Ask rather than assume** — when requirements are ambiguous or there are multiple valid approaches, ask before implementing
- Keep responses concise and direct
- When referencing code, include `file:line` references so I can navigate quickly
- Do not use emojis unless explicitly asked

## Tech Stack Preferences

### Backend

- Primary language: **C#**, target **.NET 10** (LTS) unless otherwise specified
- Use modern C# idioms (records, pattern matching, minimal APIs where appropriate)
- **No ORM** — for own projects, prefer MongoDB or Redis directly; avoid Entity Framework or Dapper unless the project explicitly requires relational storage
- **REST** for APIs by default; open to **gRPC** where it fits (streaming, internal service-to-service)

### Frontend

- **React** with **JSX** and **Vite**
- Package manager: **pnpm**

### Python

- Always use **uv** for dependency management and virtual environments
- Never use pip directly or venv manually

### Databases

- **MongoDB** for document storage
- **Redis** for caching / sessions / pub-sub
- **SQLite** for small, file-based or embedded use cases
- Only if absolutely necessary: **PostgreSQL** for relational workloads
- Choose based on the project's actual requirements — do not over-engineer
- User hates SQL with a passion :-)

## Environment & Tooling

- **direnv** — use `.envrc` for environment variable management when it makes sense for the project
- Always provide a **`.env.example`** with realistic placeholder values for every required variable (never commit real secrets)
- Document all environment variables in `README.md` as well — what they do, expected format, and example values
- **Docker** — include a `Dockerfile` and `compose.yml` for projects that would benefit from containerisation
- **Deployment target**: Hetzner VPS via `docker compose` — keep compose files production-ready

## Project Conventions

### README.md

- Every project gets a `README.md`
- Must include: project description, prerequisites, installation instructions, usage, and (if applicable) development setup

### Obsidian

- Every repo gets an `obisdian` folder which is an Obsidian vault
- Add obsidian state files to .gitignore (but not settings)
- When user refers to the obsidian folder, this one is meant

### Git

- Commit message style: **imperative, free-form** (e.g. `Add login endpoint`, `Fix null reference in order service`)
- No Conventional Commits prefix required unless the project already uses them

### Testing

- Write tests when it is clearly appropriate for the scope and complexity of the task
- Preferred frameworks: **xUnit** (C#), **Vitest** (frontend), **pytest** (Python)
- Do not add tests for trivial getters/setters or one-liner utilities

### Licensing

- Default licence for new open-source projects: **GPL-3.0** - this does not apply to projects done for COR.energy

## Search Tools
- ALWAYS use `rg` (ripgrep) instead of `grep` — faster, respects .gitignore
- ALWAYS prefer LSP over text search for code navigation (go-to-definition, find-references)
- For broad text search where LSP doesn't apply: use `rg` with `--type cs` for C# files, similar for other languages

## General Coding Principles

- **Comments**: add comments where the logic is non-obvious or the reasoning matters; never comment trivial code (no `// increment i` style comments)
- Avoid over-engineering — solve the actual problem, not hypothetical future problems
- No unnecessary abstractions, helpers, or wrapper layers
- Do not add error handling for scenarios that cannot occur
- Prefer clarity over cleverness
- Security first: validate at system boundaries, never trust user input, avoid common OWASP vulnerabilities

## Frontloading of root cause analysis

Before fixing anything, list ALL possible root causes for this bug — including infrastructure, config, and multi-layer issues. Rank them by likelihood. Then fix them in order, verifying each.

## Subagent preferred

When using superpowers plugin always default to subagent based execution - no question necessary. 
