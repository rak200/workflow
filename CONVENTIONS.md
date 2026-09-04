# rak200 — conventions (Layer 1)

The invariants every rak200 repository shares, whatever it is written in. Language-specific
rules — analyser level, formatter preset, naming, idioms — are **Layer 2** and live in that
language's config package (`rak200/coding-standard-php`, `@rak200/coding-standard-ts`), imported
alongside this file. **The test is one question: would the rule still make sense in a repository
written in the other language?** If it would not, it is Layer 2.

This file travels as a tag-pinned submodule at `.rak200/`. A repository pins a version; it does
not track a moving target.

Its counterpart in the same submodule is **`LIFECYCLE.md`**, the operator's document: this file says
what is *true* of a rak200 repository, that one says what to *do* — the cycle from issue to
propagation, the contingencies when a step goes wrong, and the onboarding of a new repository. A
rule belongs here; the procedure that satisfies it belongs there.

## How to read a rule here

**Every rule in this file names the mechanism that would catch its violation, and how far that
mechanism reaches** — a CI step, a seeded file, a tool configuration, by name. Where none exists,
the rule says so in the same breath.

Silence is the unacceptable answer, because a reader cannot tell it from enforcement. The
half-answer is worse: most of what has gone wrong here was not an unchecked rule but a *partly*
checked one, where the sentence claimed the whole and the mechanism covered a corner of it. Reach is
part of the answer, not a footnote to it.

**A rule states its result; the argument that produced it lives in the change that decided it.**
The paragraph ends with a bare reference to that change and nothing else — one or more, qualified
with the repository, because this file is also read at `.rak200/` inside a consumer where a bare
`#118` names the wrong thing. Where no change decided a rule, the reasoning stays, because nothing
else holds it. rak200/workflow#122, rak200/workflow#123

Nothing enforces either rule. No check can decide whether a sentence states a requirement or
whether a paragraph is argument rather than result, so both are enforced by whoever writes the next
one.

## Versioning and releases

- **[SemVer](https://semver.org)**, tagged on `master`. Tags are **bare** — `4.5.0`, no `v`
  prefix — and immutable: the ruleset refuses to move or delete one.
- **The version is derived, never typed.** `release-please` reads the commit history, opens a
  Release PR, and merging it cuts the tag and the GitHub Release. Do not hand-edit a version
  field; a manifest pin is machine state.
- **Below `1.0.0` every effect shifts one level down**, and that is the majority of the estate at
  any given moment — a repository starts at `initial-version: "0.1.0"`. A break cuts a **minor**,
  a `feat` cuts a **patch**. Two flags in the seeded `release-please-config.json` do it,
  `bump-minor-pre-major` and `bump-patch-for-minor-pre-major`, both `true` in every variant and
  neither a release-please default. `0.x` has two levels for three classes, so one pair must
  collapse, and this is the pair that costs nothing: `^0.3.0` resolves to `>=0.3.0 <0.4.0` in both
  Composer and npm, so the caret already treats a minor as breaking. A break has to leave that
  range; an additive `feat` does not. **`1.0.0` is never reached by accumulation** — it is asked
  for, with `Release-As: 1.0.0`.
- **Deprecate in a minor, remove in the next major — never both in one release.** A consumer
  must have one release in which the replacement and the deprecation coexist. **Nothing checks
  this, and nothing can from inside one pull request**: it is a property of two releases read side
  by side. Below `1.0.0` it does not bind at all — `0.x` promises nothing.
- **Raising the language floor is a major**, or a minor below `1.0.0` — whichever level the
  consumer's caret refuses. A lesser bump would fail *silently*: the resolver simply stops offering
  the new version and pins the consumer to an old one, with no error to read. The **mirror-badge
  check** catches the visible half — the floor cannot move without the README badge following, or
  the pull request reds. It does not reach the bump itself: `release-please` derives that from the
  commit type, so a floor raise typed `build:` cuts no release at all.
- **`CHANGELOG.md`** follows [Keep a Changelog](https://keepachangelog.com) and is generated.
  Hand-written entries survive above the generated ones; a hand-written *unreleased* section
  must be reconciled before the first automated release or it ships twice.

## Commits

The merge strategy is **squash-only with the PR title as the commit**, so the enforced unit is
the **pull request title**. In-branch commits are unconstrained — they are squashed away.

`type(scope)?: subject`, with `type!` or a `BREAKING CHANGE:` footer marking a break.

| Type | Use for | `≥ 1.0.0` | `0.x` |
| --- | --- | --- | --- |
| `feat` | a new capability | minor | **patch** |
| `fix` | a bug fix | patch | patch |
| `perf` | a performance change, no API change | patch | patch |
| `revert` | reverts a prior commit | patch | patch |
| `refactor` | internal change, no behaviour change | none | none |
| `style` | formatting only, no meaning change | none | none |
| `docs` | docs / docblocks only | none * | none * |
| `test` | tests only | none | none |
| `build` | build, dependencies, package manifest | none | none |
| `ci` | CI config only | none | none |
| `chore` | anything else not user-facing | none | none |

\* **The `docs` row is the one that varies by variant.** The `none` variant leaves the section
visible, because there the prose *is* the product: `rak200/workflow` cuts a patch on a `docs:`
commit and nothing else does. `LIFECYCLE.md` §3.9 carries the reasoning and the measurement.

The set is closed at these eleven — the stock `type-enum` of
`@commitlint/config-conventional`, adopted without override. A breaking change forces a **major**
regardless of type — a **minor** below `1.0.0`, where §Versioning explains why.

**`none` means no release at all, not a release with nothing in it.** It holds while the type's
changelog section stays **hidden**: `release-please` opens no Release PR for a window whose commits
are all hidden, so those commits wait and ship with the next visible one. Every seed declares
`changelog-sections` in full: the field **replaces** the defaults rather than extending them, and
the release types disagree about what those defaults are — leaving it out selects whichever one
this repository's release type happens to carry, which is how two versions were once published for
a file-mode change. `release-please-config.json` is an `exact` seed, so un-hiding a type is a
**variant** decision and never a local one — a repository that edits its own copy fails
conformance.

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

**The caller pins an exact tag**, never a branch or a moving alias. A branch name is never unequal
to itself, so every staleness comparison passes and the reference silently follows whatever lands
on that branch.

```
validate → install → lint → analyse → test → coverage floor → scan → mutation floor → gate
```

**The required check is `ci / gate`**, and both halves of that name are conventions: the
caller's job is `ci`, the reusable workflow's last job is `gate`. Per-matrix checks exist and
are never required by name — they are version-dependent and break at the next bump.

**Both floors are enforced inside the job**, from files in the repository, so the required check
never waits on a third party. Coverage reporting (Codecov) is reporting only.

**The `scan` step is three ordered steps, and the order is the rule**: scan, capturing the exit
code and never failing; publish the findings, never deciding; then enforce the captured code in a
step of its own. Collapsing them is how a scanner keeps reporting and stops blocking — an exit code
captured and never acted on disarms the gate while every step stays green.

## The shared task vocabulary

Eight verbs, one per pipeline step, bound natively (`composer <verb>` / `npm run <verb>`). A
repository's manifest declares every verb **the package manager does not already provide**; CI
asserts their presence, not their bodies — Layer 1 owns the vocabulary, Layer 2 owns what each
word does.

**The exception is `validate`, and it is a hard one.** Composer ships a native `validate`
command and **refuses to run** any script of that name: `composer validate` and even
`composer run-script validate` both print *"A script named validate would override a Composer
command and has been skipped"* and fall through to the native command. Declaring the verb there
would be configuration that can never execute — so in PHP the verb is the native command, and the
manifest must **not** declare it. CI asserts that absence as strictly as it asserts the others'
presence: a script that cannot run is worse than a missing one, because it reads as covered.

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
- **Mutation runs over the changed lines on a pull request, and in full off that path.** A full
  run is tens of minutes on a real library, and a required check that slow is one people learn to
  route around. The threshold is identical in both; only *what* is mutated differs. The full run
  is the safety net the diff structurally cannot be — a change in one file can stop a test from
  killing a mutant in a file the diff never touched — and is triggered manually before a
  significant release. The vocabulary still holds one mutation verb: Layer 1 owns the word, the
  pipeline owns when and over what it runs.
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

## Proposals

The process — what a proposal is for, its steps, its statuses, its template — is
`.rak200/proposals/README.md`. Only **where a proposal lives** is here, because that is decided
with a repository open and the process document closed.

- **Per repository**, in that repository's own `docs/proposals/`, with its own `README.md` index
  and its own repo-scoped `NNNN` numbering. There is no central aggregating index; discovery is
  per-repo, and cross-repo relationships are carried by **mother↔daughter links** — a proposal
  that spawns work in another repository links to the offspring, and the offspring links back.
- **A subject a repository owns belongs to that repository**, even when a related proposal lives
  elsewhere. Age is not ownership: a proposal that predates the repository it created stays where it
  was written, and the new repository starts its own numbering at `0001`, joined to its parent by
  those links. Where a proposal with *no* owning repository goes is internal routing, and stays out
  of this file.
- **The directory is created on demand.** A repository with no proposal carries no
  `docs/proposals/`, and nothing asserts otherwise.

## Support files

| File | Holds |
| --- | --- |
| `README.md` | overview, installation, badges, links |
| `docs/` | the reference — index plus one page per unit |
| `docs/proposals/` | this repository's proposals, if it has any — index plus one file each |
| `CLAUDE.md` | agent routing — imports this file and its Layer 2 counterpart; states no rule of its own |
| `ROADMAP.md` | pending work, ordered; each entry references its issue |
| `CHANGELOG.md` | released history, generated |
| `ARCHITECTURE.md` | design decisions, in public — the consumer-facing half of what a proposal decided |
| `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md` | propagate account-wide from `rak200/.github` |

**A delivered roadmap entry is pruned by the PR that delivers it** — removed, not annotated as
done. `CHANGELOG.md` is the historical record; `ROADMAP.md` is only what is still pending. CI
enforces it against the PR's `Closes #N`.

**Three of those rows are checked, and none of the checks asserts presence.** The mirror-badge,
`docs/` symbol-coverage and roadmap-pruning steps each open with a guard that passes when the file
is absent — *no README.md*, *no src/ or no docs/*, *no ROADMAP.md*. They verify content where the
file exists, never that it exists. Onboarding writes `README.md` and `CLAUDE.md`; every other row
appears when someone writes it, and its absence is caught by a reader or not at all.

**`CLAUDE.md` states no rule that is not written somewhere a human reads.** Its job is to deliver,
to an agent, context that is spread across the other files — so a rule that lives only there binds
nobody, because the human operator never opens it. A repository's own design decisions go in
`ARCHITECTURE.md`; ecosystem rules go here or in the Layer 2 standard.

**That binds rules, and only rules.** Two other things belong in a `CLAUDE.md` and stay there:
**routing** — where a decision is written, so the agent can go and read it — and **operating
instructions**, which are the steps that make the context load and the commands that exercise one
part of the repository. A recovery step for a failed import has no human procedure to belong to;
moving it out would leave a file that says the right things and cannot reach them.

**The reason for a configured decision goes at the configuration**, as a comment beside the line it
explains. A reader who is about to change a threshold, disable a fixer or flip a compiler flag is
looking at that file, not at a document — and a reason that travels with the value cannot fall
out of step with it.

## Repository hygiene

- **Public documentation never depends on a private repository.** The estate is deliberately mixed,
  so a public `README.md`, `docs/` page, `ROADMAP.md` or `CLAUDE.md` neither links nor names one — a
  reader outside the account finds a 404 where the reasoning should be. **What a consumer needs in
  order to understand a decision goes in that repository's own public `ARCHITECTURE.md`**; the
  proposal behind it stays internal history, cited by number alone — `RFC 0016`, no URL and no
  repository name.
- **It binds the whole public surface**, not only the documents: badges, workflow comments, issue
  templates, and the bodies of issues and pull requests. **`CHANGELOG.md` is the one exemption**,
  being generated from released commits — the control point there is the pull request that feeds it.
- **Line endings are LF everywhere** — `.gitattributes` sets `* text=auto eol=lf`, working tree
  included. Development happens on Windows and CI on Linux; without it the tree is
  platform-dependent and fixers rewrite lines for their endings.
- **The distribution tarball carries consumption, not development.** `export-ignore` on tests,
  docs, CI configuration, tool configs and the `.rak200` gitlink. `.gitattributes` is therefore a
  **per-variant** seed, not a shared one: the list names one language's tool configs, and a
  package whose product *is* configuration must export the very files a library hides. The
  conformance check compares that seed byte for byte, so the list cannot drift; that the list still
  *matches the tree* is one manual step — `LIFECYCLE.md` §8.2 — on the existing-repository path
  only. A repository created by the onboarding script never runs it.
- **Bulk reformatting commits are recorded in `.git-blame-ignore-revs`** so `git blame` skips
  them. GitHub honours the file automatically; enable it locally with
  `git config blame.ignoreRevsFile .git-blame-ignore-revs`.
- **Lockfiles follow the artifact, not the language.** An *application* commits its lockfile; a
  *library* does not, and resolves fresh against its constraints. (PHP libraries omit
  `composer.lock`; JS/TS libraries commit `package-lock.json` — the taxonomy is Layer 1, the
  convention that follows from it is Layer 2.) **The library half is enforced in both languages**:
  the seeded `.gitignore` keeps `composer.lock` out of a PHP tree, and `npm ci` fails outright
  without a `package-lock.json`. The application half is enforced by nothing — no scaffold variant
  produces an application, so that half of the taxonomy has never been exercised.
- **Configuration ships as a committed `.dist` template** where the tool supports a local
  override, and the override is ignored. The seeded `.gitignore` is what ignores it, so the
  override cannot be committed by accident. **Nothing asserts the `.dist` itself exists**, and the
  rule currently has PHP instances only — no seeded TypeScript tool takes a local override.

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

**One badge is required in every repository**, whatever the variant and whether or not the thing
it ships is published anywhere:

```markdown
[![Latest tag](https://img.shields.io/github/v/tag/rak200/<repo>?sort=semver)](https://github.com/rak200/<repo>/tags)
```

The **git tag** is the source, uniformly — not the registry the package happens to be installed
from. Every repository here has tags; only some have a registry, and a rule that changes shape per
variant is a rule that gets applied to some of them. A registry badge may be added alongside it,
never instead of it.

## Security

- **Third-party CI actions are pinned by full commit SHA**, never a floating tag, and the
  platform enforces it.
- **Least privilege for the workflow token**: read-only by default, widened per job only to what
  that job needs.
- **Credentials follow a ladder**: OIDC or an ephemeral credential first; a repo-scoped secret
  only where no OIDC path exists; an environment with a required reviewer for anything genuinely
  powerful. Never `secrets: inherit`, and nothing repo-local that a forked PR could exfiltrate.
- **`pull_request_target` is banned.** It runs the *base* repository's workflow, with a writable
  token and access to secrets, against a fork's code. No use of it is worth the class of exploit it
  opens; where a fork's PR genuinely needs privilege, the work belongs in a second workflow keyed on
  `workflow_run`.
- **Untrusted values** — PR titles, branch names, issue bodies — reach a script through `env:`,
  never through template interpolation.
- **`gitleaks` runs twice**: locally in `.githooks/pre-push` (prevention) and in CI (the
  backstop). A hit in CI means the credential is already in history.
- **The `scan` verb is bound to `semgrep` in every language**, with the ruleset varying by
  language and nothing else. One scanner across the ecosystem beats hunting for a native
  equivalent per language: the findings, the SARIF and the suppression syntax stay one thing to
  learn. It is a Python tool, so a development environment installs it outside the language's own
  package manager, and CI installs it explicitly — nothing in a Composer or npm graph brings it.

## Non-negotiables

These exist because each was violated once and the failure was **silent**.

**These five bind anything anyone writes in any repository** — a workflow, a settings write, a gate.
They are not the whole list: `LIFECYCLE.md` §5 is the operator's, adding the rules that bind only
whoever runs the lifecycle. Everything here appears there; the difference is audience, not drift.

1. **A settings write is verified by reading it back**, never by its response code.
2. **An aggregator carries `if: always()`** and compares for **equality with `success`**. A
   skipped required check counts as satisfied; `!= 'failure'` lets a cancelled run through.
3. **A workflow producing a required check carries no `paths:` filter.** A filtered run
   publishes *no check*, and the PR waits forever.
4. **Audit a pipeline on each step's `outcome`**, never its `conclusion` — `continue-on-error`
   relabels a failure as success.
5. **A gate that has never failed has never been tested.** Make each one fail on purpose once,
   and confirm it blocks.
