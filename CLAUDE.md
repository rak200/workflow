# CLAUDE.md

Guidance for Claude Code when working in this repository.

@CONVENTIONS.md

> The import above is deliberately local. Every other repository writes
> `@.rak200/CONVENTIONS.md`; this one **is** `.rak200`, and cannot import itself.

## What this repository is

Layer 1 of the ecosystem baseline: conventions, lifecycle, scaffold, labels, the RFC process,
and the onboarding script. It is consumed as a tag-pinned submodule, so **every change here is a
change to a contract**, and consumers adopt it only when they bump their pin.

## Where the rules are

In the import above, and in [README.md](README.md), where a human reads them. This file restates
none of them.

The ones this repository is asked to break most often:

- **Changing a seed** reaches every consumer at its next bump, and a seed without a row in
  `scaffold/seeds.tsv` is never checked again — [README.md](README.md), §*The scaffold, and why
  it is checked*.
- **What a change here costs in version** — [README.md](README.md) §*Versioning*.
- **Layer 1 or Layer 2** — `CONVENTIONS.md`, first paragraph, which carries the test.
- **A procedure is not changed until it has been run** — [README.md](README.md), above the file
  table. `LIFECYCLE.md` carries commands; changing one means executing it.
