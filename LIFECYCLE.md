# Development lifecycle

> **This document is self-contained, and that is a rule rather than a courtesy.** It was drafted
> inside a design proposal and moved here when `rak200/workflow` was built; the proposal recorded
> what was *decided*, this file records what is *true*. The two parted company the moment the
> first pilot ran, because building the thing found what no amount of reasoning about it had.
> Nothing here points at the proposal for a procedure. When a decision recorded there turns out
> to be wrong in practice, the correction lands here — and the proposal keeps the reasoning as
> history, not as instructions anyone is meant to follow.
>
> Consumers read this at `.rak200/LIFECYCLE.md`, pinned to the conventions tag their repository
> chose.

This is the **primary reference** for how work moves through any `rak200` repository, from an idea
to a released tag. It is written to be followed by a human reading it once, by an **agent**
executing it as instructions, and by a **new contributor** who has never seen this ecosystem.

How a rule here is written — result and reason inline, log in the change that decided it — is
`CONVENTIONS.md` §How to read a rule here.

**Two copies of this document exist and they are not the same.** The `CONTRIBUTING.md` propagated
from `rak200/.github` links to the **current** version in `rak200/workflow` — right for a
drive-by reader. The copy at `.rak200/LIFECYCLE.md` inside a repository is the version **that
repository pinned**, and it is the one that governs work done there. When they disagree, the
pinned one wins locally, and the disagreement is closed by bumping the submodule.

---

Two companion documents sit beside this one in the same submodule, split out of it because a page
read every day should not carry what is read twice a year. **`CONTINGENCIES.md`** — a step went
wrong: the gate is red, the required check never appears, a bad release shipped. **`REPOSITORY.md`**
— onboarding a repository, reconfiguring one, retiring one. rak200/workflow#126
## 1. Cast

| Actor | Who | GitHub identity | What it may do alone |
| --- | --- | --- | --- |
| **Maintainer** | the human | `@rak200` | everything, including bypass |
| **Agent** | AI working the code | **`@rak200`** — the same account | open branches and PRs; never merge |
| **Dependabot** | dependency bot | `dependabot` | open update PRs |
| **release-please** | release bot | `github-actions[bot]` | open and maintain the Release PR |
| **CI** | the reusable workflow | repo `GITHUB_TOKEN` | run gates, report `ci / gate` |
| **Platform** | rulesets, Actions policy, repo settings | — | refuse anything that violates them |

**The agent and the maintainer share one identity.** Everything downstream follows from this: the
platform cannot tell them apart, so the separation is procedural. See §5.

---

## 2. Before you start

A conformant repository already has all of this. If any is missing, the repo has not been
onboarded — see `REPOSITORY.md` §1.

| Concern | Where it lives | How it arrives |
| --- | --- | --- |
| Ecosystem conventions | `.rak200/CONVENTIONS.md` | git submodule, tag-pinned |
| This document | `.rak200/LIFECYCLE.md` | same submodule |
| RFC template | `.rak200/proposals/TEMPLATE.md` | same submodule |
| Canonical labels | `.rak200/labels.yml` | same submodule, applied additively |
| Editor settings | `.editorconfig` | copied from the scaffold |
| Agent instructions | `CLAUDE.md` | per-repo; imports `@.rak200/CONVENTIONS.md` |
| PHP lint/analysis config | `rak200/coding-standard-php` | Composer dev dependency |
| TS lint/analysis config | `@rak200/coding-standard-ts` | npm dev dependency |
| CI pipeline | `rak200/.github/.github/workflows/{base,php,js}.yml` | referenced by the caller, at an exact tag |
| CI caller | `.github/workflows/ci.yml` | per-repo, thin |
| Dependency automation | `.github/dependabot.yml` | per-repo, committed |
| Code owners | `.github/CODEOWNERS` | per-repo — **does not propagate** |
| PR template, issue templates | `rak200/.github` | GitHub-native propagation |
| Branch and tag rules | per-repo rulesets | canonical JSON in `rak200/.github`, applied by API at onboarding, verified by read-back |
| Local secret gate | `.githooks/pre-push` (`gitleaks`) | seeded from the scaffold; `core.hooksPath` and the pinned `gitleaks` version set per clone at onboarding |
| Secret-scanning allowlist | `.gitleaks.toml` | copied from the scaffold; seeded empty, extends the default ruleset, read by both halves |
| Line endings & dist surface | `.gitattributes` (`text=auto eol=lf`, `export-ignore`) | copied from the scaffold |
| License | `LICENSE` (MIT) | copied from the scaffold — **does not propagate** |
| Blame noise | `.git-blame-ignore-revs` | header seeded (prefix-checked); entries appended by bot PR; `blame.ignoreRevsFile` set per clone |

Seeded copies (the *copied* / *per-repo* rows) are **conformance-checked by CI** against the
pinned `.rak200/scaffold/` — a drifted copy reds the gate. The check compares against the
*pinned* version, so it turns red only when a submodule bump changes a seed (§3.9), never from
standing still.

```bash
# clone a conformant repo with its conventions
git clone --recurse-submodules https://github.com/rak200/<repo>.git

# already cloned without them
git submodule update --init --recursive

# per clone, once — both are local git config, not committed state
git config core.hooksPath .githooks
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

> **The pre-push hook is the preventive half of secret scanning.** It runs `gitleaks` over what
> is about to leave the machine and refuses the push on a hit — loudly, including when
> `gitleaks` is not installed (installing it is an onboarding step). CI's `gitleaks` step is the
> backstop for clones that skipped onboarding; a hit *there* means the credential is already in
> history — see `CONTINGENCIES.md` §4.

> **Why `--recurse-submodules` matters.** Without it `.rak200/` is empty, and anything reading a
> file from it fails. That failure is loud by design — the label sync reports
> `Can't access config file` and the job fails rather than silently syncing nothing.

---

## 3. The cycle

### 3.1 Issue — *maintainer or agent*

Every change traces to an issue. Use the issue templates; they apply the issue-side labels
(`bug`, `feature`, `needs-triage`).

```bash
gh issue create --title "Foo breaks when bar is empty" --label bug
```

An RFC is required only for a change that alters the ecosystem's design — see
`.rak200/proposals/TEMPLATE.md` for the form and `.rak200/proposals/README.md` for the process.
It goes in **this repository's** `docs/proposals/`, not a central one — `CONVENTIONS.md`,
*Proposals*. Ordinary bugs and features do not need one.

**If the work is already on `ROADMAP.md`**, the entry carries its issue number — that reference is
what lets the delivering PR retire the entry (§3.4). If it is not on the roadmap, nothing to do.

### 3.2 Branch — *maintainer or agent*

Short-lived, off the trunk.

```bash
git switch master && git pull
git switch -c fix/empty-bar-crash      # <type>/<slug>, recommended — not enforced
```

**The name is a recommendation, not a rule.** `<type>/<slug>` using the commit types (`feat`, not
`feature`) makes the branch announce the title it will carry, and that is the whole of its value:
squash-only discards the branch's commits, the **PR title** is the enforced unit, and
`delete_branch_on_merge` deletes the branch afterwards. Nothing reads the name. Leave the machine
namespaces alone — `dependabot/*`, `release-please--branches--*`, `claude/*` — and keep
`release/x.y` for maintenance branches.

> **Direct pushes to `master` are refused by the platform**, for every actor including the owner:
> the `bypass_actors` entry is in **`pull_request` mode**, which grants nothing to a push. The
> branch is not a convention you may skip.

### 3.3 Work — *agent, usually*

Follow `.rak200/CONVENTIONS.md` (Layer 1) and the language conventions (Layer 2). Run the gates
locally before pushing — they are the same ones CI runs, and finding a failure here costs seconds
instead of a round trip.

The verbs are the same in every repo and in every language — only the prefix changes
(`composer <verb>` in PHP, `npm run <verb>` in TS), and they are the pipeline's steps in order:

```bash
composer validate       # manifest
composer lint           # style, read-only  (composer fix writes)
composer analyse        # static analysis
composer test           # suite
composer coverage       # suite + report; compare the total against .coverage-floor
composer scan           # security scanners
composer mutation       # floors live in the config, never on the command line
```

**The coverage floor is the number in `.coverage-floor`.** CI fails below it *and* more than a
point above it — so if your work raised coverage, raise the number **in the same PR**. It never
goes down. The mutation floor is `minCoveredMsi: 100`; a repo at literal-100% coverage may also
set `minMsi: 100`. A surviving mutant is killed by strengthening the test — never by lowering a
threshold.

**In-branch commit messages are unconstrained** — they are squashed away. Only the PR title is
enforced. Commit as often as is useful.

### 3.4 Pull request — *maintainer or agent*

**The PR title is the load-bearing artifact of this whole process.** It becomes the squash commit
on `master`, and that commit is what the release tooling reads to compute the next version and
write the changelog. Everything else in the PR is discarded at merge.

```
type(scope)?: subject
```

with `type` from the fixed set (`feat`, `fix`, `perf`, `refactor`, `style`, `docs`, `test`,
`build`, `ci`, `chore`, `revert`) — the stock `@commitlint/config-conventional` set, no override.
`style` is rare by design: day-to-day formatting is enforced by the lint gate, so its referent is
the bulk reformat that follows a **fixer-config revision** — typed `style` and recorded in
`.git-blame-ignore-revs` **by a bot, after the merge**: the squash SHA does not exist before it,
so a workflow watching `master` opens a follow-up PR appending the SHA. That PR runs no CI (it is
opened with the repo's own `GITHUB_TOKEN`) and merges with `--admin` — since the Release PR turned
out to have a *held* check rather than an absent one (§3.8), it is now the **only** PR that does. A breaking change is either `type!` or a `BREAKING CHANGE:` footer
**in the PR body**. `revert` releases a **patch** — measured, not assumed; a revert-only window
still cuts a superseding release (see `CONTINGENCIES.md` §11).

**Before you type `!`, check whether the break is allowed to be one yet.** From `1.0.0` on, a
rename or a removal must have been **deprecated in an earlier minor** — the alias survives the
whole major and goes in the next one, and deprecating plus removing inside the same major is not
allowed. A *behavioural* change has nothing to alias: it ships as the major, with the
`BREAKING CHANGE:` footer and a changelog entry stating old and new behaviour. Raising the
language floor (`"php"`, Node `engines`) is a breaking change too, even when no API moves. Below
`1.0.0` none of this binds — `0.x` promises nothing, breaking bumps the **minor** there, and
`1.0.0` arrives only when you ask for it with `Release-As: 1.0.0`.

```bash
git push -u origin HEAD
gh pr create --title "fix(bar): guard against an empty bar" --body-file .github/pr.md
```

Fill the Definition of Done in the PR template. It is a checklist, not decoration: the items map
one-to-one onto gates that will run.

**`Closes #N` in the body does two jobs**: it retires the issue on merge, and it tells the gate to
check that you also **removed that item from `ROADMAP.md`**. Delivering a roadmap entry and
leaving it listed is a red check, not a release-day chore.

> **Why the body matters too.** The squash message is the PR **body**, so a `BREAKING CHANGE:`
> footer written there reaches the commit and correctly produces a major bump. Written anywhere
> else it is lost, and a major silently ships as a minor.

### 3.5 CI — *automatic*

Opening or updating the PR runs the pipeline. One check is required: **`ci / gate`**.

```bash
gh pr checks --watch
```

The pipeline is: validate → install → lint → static analysis → tests + coverage → coverage floor →
scanners (Semgrep or CodeQL, plus `gitleaks`) → mutation floor, over a version matrix, with a
final `gate` job aggregating everything. Both floors are enforced **inside the job** — the
coverage floor from `.coverage-floor` and the report, the mutation floor from the Infection
config — so the required check never waits on a third party (Codecov is reporting only).

Four conformance steps ride along in `base.yml`: the seeded files are diffed against
`.rak200/scaffold/`; each **mirror badge** in `README.md` is diffed against the source it
claims to mirror (runtime constraint, analyser level, mutation floor, license field, release
version); every **public symbol** in `src/` is asserted to appear somewhere in `docs/`; and a PR
that closes an issue is asserted to have **removed that issue's `ROADMAP.md` entry**. If you
changed one of those sources, added a public unit, or delivered a roadmap item, update the badge,
the page or the roadmap in the same PR — the check is what remembers.

You will also see per-matrix checks (`ci / matrix (8.4)`) and, on public repos, a code-scanning
check (`Semgrep OSS`). **Neither is required by name** — they are version- and visibility-
dependent. Only `ci / gate` gates the merge.

The matrix runs `fail-fast: false`, so a failure on one version does not cancel the others — read
*which* cells went red before assuming the change is broken everywhere. Jobs carry an explicit
`timeout-minutes` (20; 60 for the full-mutation run), which is a runaway guard: a job that hits it
was hung, not slow, and rerunning it without finding out why will hang again. The OS is
`ubuntu-latest`; a repo may opt in to more through the caller's `runs-on` input, and none does
today.

### 3.6 Review — *maintainer*

**This step branches on who authored the PR.** The difference is not stylistic; it is how GitHub
computes the review requirement.

**Path A — authored by the maintainer or an agent** (the common case, since agents use the
maintainer's identity):

GitHub requests **no** code owner, because the sole code owner is the author — and the required
approval count is **0**, so nothing on the review side blocks. The merge is ordinary, and
**`ci / gate` gates it mechanically**: green merges, red is refused by the platform.

```bash
gh pr merge --squash --auto --delete-branch   # merges when ci / gate turns green
```

> **No `--admin` on this path — if you find yourself typing it, something is wrong.** A red gate
> refusing the merge is the system working; fix the branch instead. The one place `--admin` is
> legitimate is the blame-registration PR (§3.4) — **not** the Release PR, whose check is held
> rather than absent and is cleared by approving the run (§3.8). And merge through `gh` only,
> never the raw REST endpoint — the maintainer is a bypass actor, and the server honours that bypass
> on **any** unflagged API call, so a raw-endpoint merge would cross a red gate silently (§4,
> rule 10).

**Path B — authored by a bot** (Dependabot, release-please):

The author is a separate identity, so code-owner review is genuinely required and the maintainer's
approval satisfies it. No bypass is needed.

```bash
gh pr checks
gh pr review --approve
gh pr merge --squash --auto --delete-branch
```

`--auto` exists because a merge attempted immediately after opening is refused while the required
check is still queued. It merges when the gate turns green. It works **because the approval above
already happened**: auto-merge waits for the requirements to be satisfied, and an approval
satisfies them.

**Requesting changes.** On either path, review comments and `gh pr review --request-changes` work
normally. A new push **dismisses the existing approval** — deliberately, so an approval never
carries over to code it did not see. Conversations must be resolved before merge.

### 3.7 Merge — *maintainer*

Squash only. The result is exactly one Conventional Commit on `master`, titled with the PR title.
The branch is deleted automatically.

### 3.8 Release — *release-please, then the maintainer*

`release-please` watches `master` and maintains an open **Release PR** accumulating every
releasable commit since the last tag, with the derived version bump and generated `CHANGELOG.md`.
It carries the `autorelease: pending` label, which is **functional state** — never remove it.

It does **not** touch the latest-release badge in `README.md`, and nothing does: the badge reads
`shields.io/github/v/tag/rak200/<repo>?sort=semver`, which resolves the tag when the page renders.
No `extra-files` entry exists in any repository and none should — see `REPOSITORY.md` §1.2.

The Release PR's CI is **held for approval**, and this page used to say it never ran at all. The
run is created, actor `github-actions[bot]`, and completes its first attempt with the conclusion
`action_required` without executing a step. On the PR page the required check reads
`Expected — Waiting for status to be reported` — identical to an absent check — while a separate
banner says *1 workflow awaiting approval*. That banner is the whole difference, and the way past
it is to **approve the run**, not to bypass the rule:

```bash
# the held run is the one whose actor is the bot and whose conclusion is action_required
gh run list --branch release-please--branches--master --limit 5 \
  --json databaseId,conclusion,event --jq '.[] | select(.conclusion=="action_required")'
```

Approve it from the PR's checks tab (*Approve and run*), wait for green, then merge it like any
other PR:

```bash
gh pr merge <release-pr> --squash --delete-branch
```

**Do not reach for `--admin` here.** It works, and it skips exactly the verification the approval
was about to buy. Merging cuts the tag and the GitHub Release; the tag is then immutable.

For a TS repo the **publish rides in that same run** — `npm-publish.yml`, gated on
`release-please`'s `release_created` output, publishing over OIDC with provenance and no stored
token. It cannot be an `on: release: published` job: a Release created with the repository's own
`GITHUB_TOKEN` starts no new workflow, so such a job would never fire. A PHP repo has no publish
job at all, because Packagist resolves from the git tag — there the tag *is* the publication.

Publishing has one **per-package, one-time human setup**, and until it is done every release
ends at the tag: on npmjs.com, *Packages → the package → Settings → Trusted publishing*, register
the repository and the workflow filename **`release.yml`**. Register the *caller*, not
`npm-publish.yml` — npm validates the workflow that started the run, not the reusable one that
runs the command. The package must already exist, so the very first version is published by hand
from a maintainer's machine; every version after that is automatic.

> **Nothing is pruned here.** The old manual checklist ended with "remove delivered entries from
> the roadmap"; that step now happens in the PR that delivered them (§3.4), where the knowledge
> is. A release cuts a tag and a changelog — it does not know what a roadmap entry was.

### 3.9 Propagation — *Dependabot, then the maintainer*

A new release reaches consumers as a Dependabot bump PR — `composer`, `npm`, `github-actions`
(for `steps[].uses` action pins) or `gitsubmodule`. These are **Path B** PRs: CI runs, code-owner
review applies, the maintainer approves, merge is normal. A new conventions tag on
`rak200/workflow` arrives the same way.

**`gitsubmodule` runs daily; everything else runs weekly.** The asymmetry is deliberate. Since
conformance began failing on an obsolete pin (`CONTINGENCIES.md` §7), the baseline is the only
dependency whose staleness **blocks a merge** rather than merely lagging: between a baseline
release and the next Dependabot pass, every pull request in an affected repository opens red, and
the only way through is a hand-written bump. Weekly made that window seven days wide, against a
baseline that has cut seven tags in a single day. An outdated library is outdated; an outdated
baseline stops the work.

**The submodule updater resolves *latest* to a tagged commit.** It enumerates candidates from the
default branch's history, but an untagged commit is not a version to it — so a bump PR always pins
a tag, which is what `CONTINGENCIES.md` §7 requires and what makes the daily schedule safe on a
branch that moves between releases.

**The baseline is exempt from cooldown, and without the exemption it never bumps at all.** A
cooldown is applied whether or not a `dependabot.yml` asks for one, and a baseline cutting several
releases a day never leaves the window. The seeds carry `cooldown: { exclude: ["*"] }`;
`default-days: 0` is not expressible, since the schema sets `minimum: 1` on every `*-days` field
but `semver-patch-days`. rak200/workflow#44

**The `none` variant declares no `gitsubmodule` ecosystem.** That variant is `rak200/workflow`
itself, the scaffold source, which has no `.gitmodules`; Dependabot does not read that as *nothing
to do* but as an error, once per scheduled run.

**`docs:` cuts a release in the `none` variant, and nowhere else.** That variant is
`rak200/workflow` itself, where the product **is** prose: `LIFECYCLE.md` and `CONVENTIONS.md`
reach consumers only inside a tag, so a documentation change that never gets one never arrives.
`release-please` releases on `feat:` and `fix:` by default and a `docs:` commit produces nothing —
correct everywhere the product is code, and silently wrong here. It is enabled by listing `docs`
un-hidden in `changelog-sections`; a hidden section neither appears in the changelog nor triggers
a release, and the two properties are the same switch. Note that `changelog-sections` **replaces**
the defaults rather than extending them, so every seed spells out all twelve types.

**All four seeds declare the list, and `docs` is the only line that differs between them.** Leaving
it out does not select a sensible default — it selects *whatever this release type happens to
decide*, and the release types disagree. Measured 2026-08-27, on the first `chore:` commits this
estate ever made: identical message, same hour, and `utils` and `coding-standard-php` each cut a
patch release for a file-mode change while `ui` and `coding-standard-ts` cut none. The `php`
strategy carries its own section list with `chore` **un-hidden**; `node` declares none and falls
through to a default where it is hidden. The rule in the paragraph above was decided, was written
here, and three of the four seeds did not carry it — a policy with no declaration behind it is the
prose-side twin of *looks green, enforces nothing*.

**A bump that changes what a consumer resolves is titled to release; one that does not is not.**
Absent `commit-message`, Dependabot infers its prefix from the repository's history, and it
inferred `build` — hidden in every seed, so a dependency the consumer receives published nothing,
and an empty release window is indistinguishable from a healthy one. rak200/workflow#118

The seeds now declare what was inferred: `prefix: fix`, `prefix-development: build`,
`include: scope`. A production bump arrives as `fix(deps):` and cuts a patch; a development bump
arrives as `build(deps-dev):` and stays hidden. The groups split on `dependency-type` because the
prefix is chosen **once per pull request** — a group holding both kinds cannot be labelled
correctly, and the single `patterns: ["*"]` group this replaces was named `dev` while carrying
production dependencies. In the two `-config` repositories that is nearly all of them:
`coding-standard-ts` declares thirteen runtime `dependencies` and `coding-standard-php` five with
no `require-dev` at all, because there the tooling **is** the product.

`dependency-type` is not the real discriminator and is not claimed to be. What decides whether a
release is owed is whether the declared constraint moved outside its previous range: four of the
five Dependabot pull requests in that window moved only `package-lock.json`, which no consumer of
a library reads. Dependabot cannot see that; it can see production versus development, and the two
coincide often enough that this is right far more often than `build` ever was. **A hand-written
pull request that moves `require` or `dependencies` under a hidden type is still silent** — that
would need a check on the manifest diff, which is a larger decision and is not taken here.

`deps` is a **scope** in this estate and never a type; `CONVENTIONS.md` §Commits closes the type
set at eleven, and `deps` is not among them.

**The CI caller's reusable-workflow pin moves like everything else: Dependabot opens the PR.**
After a `rak200/.github` release, the `github-actions` ecosystem bumps every `jobs.<id>.uses`
reference in `.github/workflows/` — not only `ci.yml`; `release.yml` pins one or two of its own —
and delivers them as **one grouped `build(deps)` pull request**. That PR runs the repository's own
CI against the new pipeline before it lands, which is the property that makes the exact pin worth
pinning exactly. Review it and merge it; there is nothing to do by hand. rak200/workflow#112

> **This page said the opposite until 2026-08-30, and was wrong for three weeks.** Round 3 of the
> RFC 0017 simulation measured the updater ignoring `jobs.<id>.uses` and this section carried a
> `sed` recipe under the heading *"One pin Dependabot does not move"*. The estate's own history
> refutes it six times over — `1.10.0` → `1.11.1` was carried into all five consumers on
> 2026-08-09, eleven pins in one pass. The likeliest cause is that the sandbox pinned `v1.0.0`
> while no tag here carries a `v`, and the prefix was never varied. See RFC 0017 `E.42`; the
> narrower lesson is that **a negative result about a platform is perishable in a way a positive
> one is not**, and nothing in this estate re-asks a closed question.

**The bump is enforced as well as automated.** Conformance fails on a stale pipeline pin the way it
fails on a stale submodule pin — `The pinned pipeline is not obsolete`, `CONTINGENCIES.md` §8.
What it grades is the **window** until the next Dependabot pass, which is why `github-actions` is
scheduled **daily** rather than weekly (`dependabot.yml` carries the measurement).
rak200/workflow#112

**A conventions bump may red its own PR — by design.** CI conformance-checks every seeded copy
(`.editorconfig`, `dependabot.yml`, the CI caller's shape with its pin line masked, …) against
the **pinned** `.rak200/scaffold/`. A submodule bump whose new tag changed a seed stays red until
the **same PR** re-copies the changed file — the sync is atomic with the bump, and drift cannot
land quietly. (`.release-please-manifest.json` is per-repo state, not a seed; it is never
compared.)

**Rulesets are not files and follow a different path.** They are the one part of the baseline no
submodule bump carries: `.rak200` moves, conformance re-checks every seeded file, and a repository
whose protection is three releases stale reports nothing at all. After a `rak200/.github` release
that changes `rulesets/branch.json` or `rulesets/tag.json`, run the sweep: re-apply per repo via
`gh api`, then **read back** (§4, rule 9). No scheduled audit exists — that would need a stored
admin credential.

---

## 4. Rules that are not negotiable

These exist because each was violated once and the failure was silent.

**This is the operator's list, and all but two of it are Layer 1** — the same rules appear in
`CONVENTIONS.md`, which every repository imports, in wording that binds a repository author rather
than whoever runs this lifecycle. The two exceptions are **10** and **12**: a merge is a procedure,
and a seed destination binds only whoever authors the scaffold. Nothing here is a rule
`CONVENTIONS.md` disagrees with; where the two differ it is audience, not drift.
rak200/workflow#80

1. A workflow producing a required check carries **no `paths:` filter**.
2. The aggregator job carries **`if: always()`** — without it a skipped gate counts as *satisfied*
   and a red PR merges.
3. The aggregator asserts **equality with `success`**, never inequality with `failure` — equality
   folds failure, cancelled and skipped alike into a failure.
4. A scanner is **three ordered steps**: scan (never fails) → publish (never decides) → enforce
   (the only step that can fail). Capturing an exit code without acting on it disarms the gate.
5. Only **`ci / gate`** is ever required by name. Never a matrix check, never a code-scanning
   analysis check.
6. Third-party actions are **pinned by full commit SHA** — enforced by the platform, not by
   review.
7. **`pull_request_target` is banned**, and untrusted values — PR titles, branch names, issue
   bodies — reach a script through `env:` and are quoted. Never interpolated into `run:`. The two
   are one rule: the trigger hands a fork's code a writable token, and the interpolation hands a
   fork's text a shell.
8. `secrets: inherit` is forbidden in reusable-workflow callers.
9. Every API-driven setting is **read back** after writing. A settings write can return `200` and
   change nothing.
10. A merge goes through **`gh pr merge`**, never the raw REST endpoint. The bypass entry in the
    ruleset exempts the maintainer's **every** unflagged API call from the PR rules — measured: a
    plain API merge crossed a red `ci / gate` — and only the `gh` client refuses to do that
    without `--admin`.
11. A reusable workflow is referenced by **exact tag**, never a branch or a moving alias. A branch
    name is never unequal to itself, so every staleness comparison passes and the reference
    silently follows whatever lands on that branch.
12. A **seed destination is a claim that the repository owns that path** — checked against what
    the *target* repository already keeps there, not against what the other variants happen to
    leave free. The `github` variant's release caller was seeded to
    `.github/workflows/release.yml`: free everywhere else, and in `rak200/.github` the path
    holding the reusable release workflow the whole estate pins. The seed did not sit beside it,
    it **overwrote** it, and every tag from `1.8.1` shipped an `on: push` caller under the name
    everyone calls. Four releases, unnoticed, because the only repository that could break was
    pinning `@1.8.0` — past its own breakage.
13. Audit a pipeline on each step's **`outcome`**, never its `conclusion` — `continue-on-error`
    relabels a failure as success, so a summary that looks green can contain a failed step
(`CONTINGENCIES.md` §1). 14. **A gate that has never failed has never been tested.** Make each one
fail on purpose once and confirm it blocks; `CONTINGENCIES.md` §3 holds the canary per gate.

---

## 5. What actually keeps a human in the loop

Two different things, and naming them separately is the point.

**The CI gate is mechanical, on every path.** A red `ci / gate` refuses the merge — for the
maintainer, for an agent on the maintainer's identity, for a bot. This is the platform, not
discipline, and **the review count being 0 is what makes it so.**

That number looks like a weakening and is the opposite. GitHub's own authorship logic supplies the
conditionality a ruleset cannot express: with `required_approving_review_count: 0` and
`require_code_owner_review: true`, a PR authored by the sole code owner requests **no** review, so
nothing blocks it but `ci / gate` — it merges on green with **no bypass involved**, and is refused
on red naming the check. A PR from a separate identity (Dependabot, `github-actions[bot]`) still
demands the code owner, with `dismiss_stale` binding on push.

At count 1 the required approval was **unsatisfiable on a self-authored PR** — the path that
carries all human and agent work — so every merge went through the bypass, and the bypass covers
status checks as well as reviews. The stricter-looking setting turned the gate procedural on the
only path that matters.

**The review is real only where the author is a separate identity.** On the common path the
maintainer authors the PR and GitHub requests no code owner — there, what keeps the human in the
loop is that **the human is present while the agent works** and merges deliberately. The review
mechanism is real for bot-authored PRs and for anything arriving from an identity that is not the
maintainer's.

The residual trust is narrow and named: the bypass entry (kept for the Release PR) exempts the
maintainer's unflagged API calls from all PR rules, which is why rule 10 exists; and *who* runs
the merge command is procedural, not enforced. If agents are ever given **distinct identities**,
their PRs move to Path B and code-owner review begins to cover them with no new mechanism.

**Every merge in this estate is a human decision.** Nothing merges itself — not the daily baseline
bump, not a green Dependabot PR, not the Release PR. What the platform guarantees is that no merge
crosses a red `ci / gate`; what a person guarantees is that the merge should happen at all.
rak200/workflow#44

---

## 6. Quick reference

```bash
# start
git switch master && git pull && git switch -c fix/<slug>

# ship
git push -u origin HEAD
gh pr create --title "fix(scope): subject"
gh pr checks --watch

# merge — own PR (mechanically gated by ci / gate; never --admin here)
gh pr merge --squash --auto --delete-branch

# merge — bot PR  (a separate identity, so the code owner's review is requested and required)
gh pr review --approve && gh pr merge --squash --auto --delete-branch

# merge — Release PR (approve the HELD run first, then merge normally; not --admin)
gh pr merge --squash --delete-branch

# merge — blame-registration PR (absent check; the only legitimate --admin)
gh pr merge --squash --admin --delete-branch

# diagnose
gh run view --log-failed
gh pr view --json mergeStateStatus,statusCheckRollup --jq '"\(.mergeStateStatus) checks=\(.statusCheckRollup|length)"'
```

---
