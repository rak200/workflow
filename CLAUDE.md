# CLAUDE.md

Guidance for Claude Code when working in this repository.

@CONVENTIONS.md

> The import above is deliberately local. Every other repository writes
> `@.rak200/CONVENTIONS.md`; this one **is** `.rak200`, and cannot import itself.

## What this repository is

Layer 1 of the ecosystem baseline: conventions, lifecycle, scaffold, labels, the RFC process,
and the onboarding script. It is consumed as a tag-pinned submodule, so **every change here is a
change to a contract**, and consumers adopt it only when they bump their pin.

## What that implies for editing

1. **Editing a file under `scaffold/` edits every repository that bumps to the next tag.** A
   seed change reds the conformance check in each consumer until that consumer's bump PR
   re-copies it. That is the intended mechanism — but it means a careless whitespace change
   costs a pull request in every repository. Make seed changes deliberately.
2. **A new seed needs a row in `scaffold/seeds.tsv`,** naming its variant, destination and check
   form. A seed with no row is copied at onboarding and then never checked again — silent drift,
   which is the failure mode this whole design exists to remove.
3. **A file that is per-repo state is not a seed.** `.release-please-manifest.json` and
   `.coverage-floor` are excluded, and the exclusions are written in the manifest rather than
   merely implied.
4. **`CONVENTIONS.md` is Layer 1 only.** If a rule mentions a specific analyser, formatter,
   test runner or language idiom, it belongs in `rak200/coding-standard-php` or
   `@rak200/coding-standard-ts`. The test: would it still make sense in a repository written in
   the other language?
5. **`LIFECYCLE.md` is written to be executed, not merely read.** It carries commands. When a
   procedure changes, run it — the last time §8 was written from correct premises it still broke
   three times on its first real execution, once silently.

## Releasing

Bare SemVer tags, and the version is derived from commit history. A change that alters a seed or
a documented rule is at least a `feat`; a change that removes or renames one is breaking.
