# rak200/workflow

[![Latest tag](https://img.shields.io/github/v/tag/rak200/workflow?sort=semver)](https://github.com/rak200/workflow/tags)

**Layer 1 of the rak200 ecosystem baseline** — the conventions every repository shares, the
lifecycle they follow, the scaffold they are built from, and the labels they apply.

This repository is consumed as a **tag-pinned git submodule** at `.rak200/`. A repository pins a
version and updates it deliberately, through a Dependabot pull request that runs that
repository's own CI. Nothing here tracks a moving target, and nothing pushes into a consumer.

| File | What it is |
| --- | --- |
| [`CONVENTIONS.md`](CONVENTIONS.md) | the language-agnostic invariants; imported into every `CLAUDE.md` |
| [`LIFECYCLE.md`](LIFECYCLE.md) | the development cycle, issue to propagation — written to be **executed**, not merely read |
| [`CONTINGENCIES.md`](CONTINGENCIES.md) | what to do when a step in that cycle goes wrong |
| [`REPOSITORY.md`](REPOSITORY.md) | onboarding a repository, reconfiguring one, retiring one |
| [`labels.yml`](labels.yml) | the canonical label set, applied additively |
| [`scaffold/`](scaffold) | the seeded files a repository is built from, plus the manifest that checks them |
| [`proposals/`](proposals) | the RFC template and the process every repository's proposals follow |
| [`scripts/new-repo.sh`](scripts/new-repo.sh) | onboarding, executable — the form of `REPOSITORY.md` §1.1 |
| [`scripts/carry-seeds.sh`](scripts/carry-seeds.sh) | carrying a release into consumers — the form of `CONTINGENCIES.md` §7 |

**These three carry commands, and a procedure is not changed until it has been run.** The last time
`REPOSITORY.md` §1 was rewritten from correct premises it still broke three times on its first
real execution, once silently — so a change there is finished when the steps have been executed,
not when they read well.

The GitHub-native half — reusable CI workflows, ruleset JSON, community health files — lives in
**[rak200/.github](https://github.com/rak200/.github)**, because GitHub reads those from a
repository of that exact name and nothing else can substitute for it.

## Using it

```bash
# a new repository
scripts/new-repo.sh my-library php 0.1.0 "What it does"

# an existing one
git submodule add https://github.com/rak200/workflow.git .rak200
git -C .rak200 checkout 0.1.0
```

Then import the conventions from the repository's `CLAUDE.md`:

```markdown
@.rak200/CONVENTIONS.md
```

## The scaffold, and why it is checked

`scaffold/` holds the files a repository is *seeded* with — `.editorconfig`, `.gitattributes`,
`CODEOWNERS`, the CI caller, the Dependabot config, `LICENSE`, the pre-push hook, the `gitleaks`
config. A copy that drifts from its seed reds the consumer's own CI, so drift stops being silently
green.

`scaffold/seeds.tsv` is the manifest: one row per seed, naming its variant, its destination, and
**how** it is compared — `exact`, `prefix:N` (a seeded header over per-repo content), or
`masked:RE` (identical once the version pin is blanked). Files that are *per-repo state* rather
than seeds are listed there too, as exclusions, so their absence is not read as an oversight.

**A new seed needs its row, and the row is what makes it a seed.** A file added under `scaffold/`
with no entry is copied once at onboarding and never compared again — silent drift, which is the
failure mode this whole design exists to remove. The file would be there, would look maintained, and
would be the one thing nothing checks.

The comparison is always against the **pinned** version, so a repository that stands still stays
green; a seed change reaches it as part of the submodule bump, in one atomic pull request.

**This repository is checked against its own scaffold.** It is the source and cannot import
itself, so its CI compares its files to `./scaffold/` instead of `.rak200/scaffold/`. The rule it
distributes applies to it first.

## Versioning

Bare SemVer tags. Consumers pin an exact tag; a bump is a reviewed pull request in the consumer,
never a push from here.

**Every change here is a change to a contract**, and the type says which. Altering a seed or a
documented rule is at least a `feat`; removing or renaming one is breaking. Below `1.0.0` those
cut a patch and a minor respectively — `CONVENTIONS.md` §Versioning explains the shift.
