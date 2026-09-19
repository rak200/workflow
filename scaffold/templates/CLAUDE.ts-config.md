# CLAUDE.md

Guidance for Claude Code when working in this repository.

@.rak200/CONVENTIONS.md
@CONVENTIONS.md

> The second import is **local**: this repository _is_ Layer 2. Everywhere else it names this
> package under `node_modules/`, because npm does not install a package into its own tree. If it
> is missing, the standard has not been written yet — `CONVENTIONS.md` at the root is what this
> package publishes. If `.rak200/` is empty, the clone skipped its submodule:
> `git submodule update --init --recursive`.

## What this repository is

<!-- One paragraph: what it does and who consumes it. -->

## Architecture

<!-- The stable shape: directories, the units that matter, how they fit. Keep it lean —
     volatile and narrative content belongs in ROADMAP.md, CHANGELOG.md or docs/. -->
