# rak200 — conventions (Layer 1)

The invariants every rak200 repository shares, whatever it is written in. Language-specific
rules — analyser level, formatter preset, naming, idioms — are **Layer 2** and live in that
language's config package (`rak200/coding-standard-php`, `@rak200/coding-standard-ts`), imported
alongside this file.

This file travels as a tag-pinned submodule at `.rak200/`. A repository pins a version; it does
not track a moving target.

## Versioning and releases

- **[SemVer](https://semver.org)**, tagged on `master`. Tags are **bare** — `4.5.0`, no `v`
  prefix — and immutable: the ruleset refuses to move or delete one.
- **The version is derived, never typed.** `release-please` reads the commit history, opens a
  Release PR, and merging it cuts the tag and the GitHub Release. Do not hand-edit a version
  field; a manifest pin is machine state.
- **Deprecate in a minor, remove in the next major — never both in one release.** A consumer
  must have one release in which the replacement and the deprecation coexist.
- **Raising the language floor is a major.** A minor would fail *silently*: the resolver simply
  stops offering the new version and pins the consumer to an old one, with no error to read.
- **`CHANGELOG.md`** follows [Keep a Changelog](https://keepachangelog.com) and is generated.
  Hand-written entries survive above the generated ones; a hand-written *unreleased* section
  must be reconciled before the first automated release or it ships twice.

## Commits

The merge strategy is **squash-only with the PR title as the commit**, so the enforced unit is
the **pull request title**. In-branch commits are unconstrained — they are squashed away.

`type(scope)?: subject`, with `type!` or a `BREAKING CHANGE:` footer marking a break.

| Type | Use for | Release effect |
| --- | --- | --- |
| `feat` | a new capability | minor |
| `fix` | a bug fix | patch |
| `perf` | a performance change, no API change | patch |
| `revert` | reverts a prior commit | patch |
| `refactor` | internal change, no behaviour change | none |
| `style` | formatting only, no meaning change | none |
| `docs` | docs / docblocks only | none |
| `test` | tests only | none |
| `build` | build, dependencies, package manifest | none |
| `ci` | CI config only | none |
| `chore` | anything else not user-facing | none |

The set is closed at these eleven — the stock `type-enum` of
`@commitlint/config-conventional`, adopted without override. A breaking change forces a major
regardless of type.

**A revert never subtracts.** Inside an open release window it neither removes the reverted
entry from the changelog nor lowers the pending bump; it supersedes forward, as a patch.

**Branch names are a recommendation, not a rule.** `<type>/<slug>` — using the types above, so
the branch announces the title it will carry (`feat`, not `feature`). Nothing reads the name:
the squash discards it and the merge deletes it. Leave the machine namespaces alone
(`dependabot/*`, `release-please--branches--*`, `claude/*`) and keep `release/x.y` for
maintenance branches.

## The pipeline

One reusable workflow holds the pipeline; each repository carries a thin caller. The shape is
Layer 1; the steps are Layer 2, and each step invokes a **verb**, never a tool — which is what
lets the PHP and TypeScript pipelines read identically.

```
validate → install → lint → analyse → test → coverage floor → scan → mutation floor → gate
```

**The required check is `ci / gate`**, and both halves of that name are conventions: the
caller's job is `ci`, the reusable workflow's last job is `gate`. Per-matrix checks exist and
are never required by name — they are version-dependent and break at the next bump.

**Both floors are enforced inside the job**, from files in the repository, so the required check
never waits on a third party. Coverage reporting (Codecov) is reporting only.

## The shared task vocabulary

Eight verbs, one per pipeline step, bound natively (`composer <verb>` / `npm run <verb>`). A
repository's manifest must declare every one; CI asserts their **presence**, not their bodies —
Layer 1 owns the vocabulary, Layer 2 owns what each word does.

| Verb | Step |
| --- | --- |
| `validate` | the package manifest is well-formed |
| `lint` | formatting, check-only |
| `fix` | formatting, applied — the only local-only verb |
| `analyse` | static analysis |
| `test` | the suite |
| `coverage` | the coverage floor |
| `scan` | the security scanner |
| `mutation` | the mutation floor |

## Testing

- **The test tree mirrors the source tree**, one test file per unit, and the test namespace
  mirrors the source namespace.
- **Assert the contract, not the implementation**: return values, thrown exceptions, edge cases
  (empty input, boundaries, multibyte where it applies). Cover the error paths. Time-sensitive
  tests assert structural properties, never literal values.
- **Mutation floor: `minCoveredMsi: 100`.** Every mutant on covered code must die. A survivor is
  killed by strengthening the test; it is *ignored* only when provably equivalent — no input
  distinguishes it — and then with the narrowest possible annotation. **The threshold is never
  lowered to accommodate a survivor.**
- **Coverage floor: a per-repo absolute in `.coverage-floor`,** hard-floored at 95%, monotonic —
  it ratchets up as coverage improves and never down. It is per-repo state, not a seed.

## Documentation

- **Documentation is mandatory**, and the root `README.md` stays lean: overview, installation,
  badges, links. API detail lives in `docs/`.
- **`docs/` is sized by unit, not by class** — an index plus one page per unit that a reader
  would look up on its own. CI asserts that every public symbol appears somewhere in `docs/`.
- Every public unit and every public member carries a doc comment. Tags that merely restate the
  signature are noise; add one when it carries something the signature cannot (units, semantics,
  edge cases, the condition of a throw).

## Support files

| File | Holds |
| --- | --- |
| `README.md` | overview, installation, badges, links |
| `docs/` | the reference — index plus one page per unit |
| `CLAUDE.md` | stable instructions and conventions; imports this file |
| `ROADMAP.md` | pending work, ordered; each entry references its issue |
| `CHANGELOG.md` | released history, generated |
| `ARCHITECTURE.md` | design decisions |
| `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md` | propagate account-wide from `rak200/.github` |

**A delivered roadmap entry is pruned by the PR that delivers it** — removed, not annotated as
done. `CHANGELOG.md` is the historical record; `ROADMAP.md` is only what is still pending. CI
enforces it against the PR's `Closes #N`.

## Repository hygiene

- **Line endings are LF everywhere** — `.gitattributes` sets `* text=auto eol=lf`, working tree
  included. Development happens on Windows and CI on Linux; without it the tree is
  platform-dependent and fixers rewrite lines for their endings.
- **The distribution tarball carries consumption, not development.** `export-ignore` on tests,
  docs, CI configuration, tool configs and the `.rak200` gitlink.
- **Bulk reformatting commits are recorded in `.git-blame-ignore-revs`** so `git blame` skips
  them. GitHub honours the file automatically; enable it locally with
  `git config blame.ignoreRevsFile .git-blame-ignore-revs`.
- **Lockfiles follow the artifact, not the language.** An *application* commits its lockfile; a
  *library* does not, and resolves fresh against its constraints. (PHP libraries omit
  `composer.lock`; JS/TS libraries commit `package-lock.json` — the taxonomy is Layer 1, the
  convention that follows from it is Layer 2.)
- **Configuration ships as a committed `.dist` template** where the tool supports a local
  override, and the override is ignored.

## README badges

Every badge is a claim the repository must back up. Three categories, by how that honesty is
maintained:

- **Live (never hand-edit):** CI, coverage, latest release — driven by a service, so they cannot
  drift.
- **Mirror a source of truth (update the badge when the source changes):** runtime constraint,
  analyser level, mutation floor, license. **CI-enforced** — the PR that moves a source reds
  until the badge follows.
- **Stable claims (revisit only if the practice changes):** code style, SemVer, Keep a Changelog.

Prefer a verifiable badge over a vanity metric.

## Security

- **Third-party CI actions are pinned by full commit SHA**, never a floating tag, and the
  platform enforces it.
- **Least privilege for the workflow token**: read-only by default, widened per job only to what
  that job needs.
- **Credentials follow a ladder**: OIDC or an ephemeral credential first; a repo-scoped secret
  only where no OIDC path exists; an environment with a required reviewer for anything genuinely
  powerful. Never `secrets: inherit`, and nothing repo-local that a forked PR could exfiltrate.
- **Untrusted values** — PR titles, branch names, issue bodies — reach a script through `env:`,
  never through template interpolation.
- **`gitleaks` runs twice**: locally in `.githooks/pre-push` (prevention) and in CI (the
  backstop). A hit in CI means the credential is already in history.

## Non-negotiables

These exist because each was violated once and the failure was **silent**.

1. **A settings write is verified by reading it back**, never by its response code.
2. **An aggregator carries `if: always()`** and compares for **equality with `success`**. A
   skipped required check counts as satisfied; `!= 'failure'` lets a cancelled run through.
3. **A workflow producing a required check carries no `paths:` filter.** A filtered run
   publishes *no check*, and the PR waits forever.
4. **Audit a pipeline on each step's `outcome`**, never its `conclusion` — `continue-on-error`
   relabels a failure as success.
5. **A gate that has never failed has never been tested.** Make each one fail on purpose once,
   and confirm it blocks.
