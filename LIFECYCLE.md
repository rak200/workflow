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

Where a rule exists because a mechanism behaves in a non-obvious way, the reason is stated inline.
Those reasons are not commentary — they were established empirically, and removing the rule
reintroduces the failure.

**What that licence does not cover is a log.** This file holds the consolidated workflow: what to
do, and the reason a step is shaped the way it is. It does not hold the trials that arrived at
that shape, the alternatives weighed and discarded, the dated measurements, or the corrections
made along the way. Those belong to the design proposal, whose job is exactly that history. The
test: if a sentence would still be here after the reader forgot how the rule was discovered, keep
it — otherwise it is narrative, and narrative is what makes a reference stop being read.

**Two copies of this document exist and they are not the same.** The `CONTRIBUTING.md` propagated
from `rak200/.github` links to the **current** version in `rak200/workflow` — right for a
drive-by reader. The copy at `.rak200/LIFECYCLE.md` inside a repository is the version **that
repository pinned**, and it is the one that governs work done there. When they disagree, the
pinned one wins locally, and the disagreement is closed by bumping the submodule.

---

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
platform cannot tell them apart, so the separation is procedural. See §6.

---

## 2. Before you start

A conformant repository already has all of this. If any is missing, the repo has not been
onboarded — see §8.

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
> history — see §4.4.

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
still cuts a superseding release (see §4.11).

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
> on **any** unflagged API call, so a raw-endpoint merge would cross a red gate silently (§5,
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
No `extra-files` entry exists in any repository and none should — see §8.2.

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
conformance began failing on an obsolete pin (§4.7), the baseline is the only dependency whose
staleness **blocks a merge** rather than merely lagging: between a baseline release and the next
Dependabot pass, every pull request in an affected repository opens red, and the only way through
is a hand-written bump. Weekly made that window seven days wide, against a baseline that has cut
seven tags in a single day. An outdated library is outdated; an outdated baseline stops the work.

**The submodule updater resolves *latest* to a tagged commit.** It enumerates candidates from the
default branch's history, but an untagged commit is not a version to it — so a bump PR always pins
a tag, which is what §4.7 requires and what makes the daily schedule safe on a branch that moves
between releases.

**The baseline is exempt from cooldown, and without the exemption it never bumps at all.** A
cooldown is applied whether or not a `dependabot.yml` asks for one, and a baseline cutting several
releases a day never leaves the window. The seeds carry `cooldown: { exclude: ["*"] }`;
`default-days: 0` is not expressible, since the schema sets `minimum: 1` on every `*-days` field
but `semver-patch-days`.

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
the defaults rather than extending them, so the seed spells out all twelve types.

**One pin Dependabot does not move: the CI caller's reusable-workflow reference.** Measured
(round 3): the updater ignores `jobs.<id>.uses`, tag or Release, even though the dependency graph
parses it. After a `rak200/.github` release, the pin is bumped **manually** in each consumer — an
ordinary PR the maintainer or an agent opens:

```bash
git switch -c build/bump-ci-pipeline
sed -i -E 's#(uses: rak200/\.github/\.github/workflows/[a-z0-9-]+\.yml)@[0-9.]+#\1@1.10.0#' \
  .github/workflows/*.yml
git commit -am "build: bump the pipeline to 1.10.0" && git push -u origin HEAD
gh pr create --title "build: bump the pipeline to 1.10.0"
```

The PR runs that repo's own CI against the new pipeline before it lands — the property that makes
the exact pin worth its manual cost.

**Since `rak200/.github` 1.10.0 this bump is enforced, not remembered.** Conformance fails on a
stale pipeline pin the way it fails on a stale submodule pin, and for the same reason: with no
Dependabot pass to lean on, *manual* had meant *forgotten* — four distinct pins across five
repositories, the scaffold's own source six releases behind. `every workflow in .github/workflows/`
is the scope, not just `ci.yml`: `release.yml` pins one or two of its own. See §4.8.

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
`gh api`, then **read back** (§5, rule 9). No scheduled audit exists — that would need a stored
admin credential.

---

## 4. Contingencies

### 4.1 `ci / gate` is red

Read the failing job, not the summary.

```bash
gh run view --log-failed
gh run view <run-id> --json jobs \
  --jq '.jobs[].steps[] | "\(.name)\t\(.outcome)"'
```

> **Read `outcome`, never `conclusion`.** A step marked `continue-on-error` reports its
> `conclusion` as `success` even when it failed; only `outcome` holds the truth. A summary that
> looks green can contain a failed step.

Fix on the branch and push. The gate re-runs; the previous approval, if any, is dismissed.

### 4.2 `ci / gate` never appears and the PR waits forever

This is the **absent check** deadlock, and it is the most dangerous state in this system because
it looks like patience rather than failure. Two known causes:

1. **The workflow did not start at all** — `startup_failure` with zero checks. Usually an invalid
   workflow file or a repository Actions policy refusing it.
2. **The workflow was filtered out** — a `paths:` filter excluded every file the PR touched. A
   workflow producing a required check must carry **no** `paths:` filter; if you find one, that is
   the bug.

```bash
gh pr view <n> --json mergeStateStatus,statusCheckRollup \
  --jq '"\(.mergeStateStatus)  checks=\(.statusCheckRollup|length)"'
gh run list --branch <branch> --limit 5
```

`checks=0` with `BLOCKED` is the signature.

A **third cause produces the identical signature** and has an entirely different fix, so read this
before concluding either of the two above:

3. **The run is held for approval.** GitHub created the run and is waiting for a maintainer to
   start it. The required check is genuinely *not reported* — the PR page shows
   `ci / gate  Expected — Waiting for status to be reported`, character for character what an
   absent check shows — and the only thing distinguishing it sits in a **separate** banner:
   *1 workflow awaiting approval*, with an **Approve workflows to run** button. Counting checks
   cannot tell these apart, because in all three cases the count is zero. Look for the run:

   ```bash
   gh run list --branch <branch> --limit 5 --json conclusion,event,databaseId \
     --jq '.[] | select(.conclusion=="action_required")'
   ```

   A hit means approve and wait, not diagnose. The Release PR is the routine case (§3.8) — its run
   is held on every release, by design rather than by fault.

An earlier version of this section called that state "a check that exists and is held". It does
not exist: the *run* is held, and the check it would publish is missing exactly as if the run had
never been created. The distinction matters because it is the one the diagnosis turns on.

### 4.3 A gate is green and should not be

Suspect this whenever a change to the pipeline, the ruleset, or a platform setting has landed.
Verify by **making the gate fail on purpose**:

| Gate | Canary |
| --- | --- |
| aggregator | a matrix job forced to fail |
| SHA pinning | a step using `actions/setup-node@v4` — refused at `Set up job` |
| PR title check | a PR titled `wip` |
| scanner | a fixture with `eval($_POST[…])` |
| `gitleaks` | a planted credential |
| coverage floor | a deliberate coverage drop — and, for the ratchet, a gain left unrecorded |
| badge conformance | a mirrored source moved with its badge left behind |
| docs coverage | a new public class documented nowhere |
| roadmap pruning | a PR closing an issue whose roadmap entry it left behind |

A gate that has never failed has never been tested. Three of the five defects this rule exists to
catch were invisible in the GitHub UI.

### 4.4 A credential leaked

**Rotate. Do not revert.** A revert removes the credential from the tip, not from history, and
not from anywhere the history has already been fetched. Reverting and moving on leaves a live
credential in a public place.

1. Revoke the credential at its source, immediately.
2. Issue a replacement.
3. Then clean the repository if you wish — this is cleanup, not remediation.

`gitleaks` runs in every repo for exactly this reason: GitHub's own secret scanning covers only
validated provider patterns, and misses private keys and generic secrets entirely.

### 4.5 A merge landed with the wrong commit message

If a squash commit reaches `master` with a non-conventional message, the release tooling cannot
parse it and the damage is **permanent** — nothing short of a history rewrite removes it. The
release will simply skip that change.

Check the repository settings that cause this before assuming it was human error:

```bash
gh api repos/:owner/:repo \
  --jq '{title: .squash_merge_commit_title, message: .squash_merge_commit_message}'
# expected: {"title": "PR_TITLE", "message": "PR_BODY"}
```

The GitHub default (`COMMIT_OR_PR_TITLE`) uses the *branch commit's* message whenever the branch
holds a single commit — the most common shape there is.

### 4.6 A Dependabot PR fails CI

Treat it as a real failure — it is telling you the dependency broke something.

```bash
gh pr comment <n> --body "@dependabot rebase"     # branch is behind master
gh pr comment <n> --body "@dependabot recreate"   # rebuild the PR from scratch
```

Do not push commits to a Dependabot branch: it stops managing the PR from then on.

### 4.7 The submodule pin is obsolete

Symptom: `ci / conformance` fails on **The pinned scaffold is not obsolete**, naming the seeds
that moved. Fix:

```bash
git -C .rak200 fetch --tags
git -C .rak200 checkout <latest tag>
# then re-copy the seeds it named, from .rak200/scaffold/, and commit both together
git add .rak200 <the seeds> && git commit -m "build: bump .rak200 to <tag>"
```

**A stale pin used to be safe and is not any more.** This page said so for as long as `.rak200/`
held prose and labels: *an old pin can fail to add something, never remove it.* That stopped being
true the moment the submodule started carrying `scaffold/`, the seeds CI grades against. A
repository grades itself against **its own pinned copy**, so an old pin does not merely miss an
addition — it makes the repository judge itself by an obsolete rulebook **and pass**. The check
built to detect drift was the thing concealing it.

Measured on `rak200/utils`: pinned eight releases behind, `release-please-config.json` changed
underneath it, gate green, and its next release would have been tagged `utils-4.6.0` — which
Composer does not read as a version, making the release invisible to every consumer. The
conformance step above now catches this, and it fails only when a seed **this variant consumes**
actually changed, so an old pin with nothing moving under it stays quiet.

Two properties follow, and anything added to `.rak200/` must preserve both: the pin is a **tag**,
never a bare commit (a commit has no version to reason about, and the step rejects it); and
whatever the submodule carries must be comparable between two tags, or staleness becomes
undetectable again.

### 4.8 The pipeline pin is obsolete

Symptom: `ci / conformance` fails on **The pinned pipeline is not obsolete**, naming the workflow
and what moved underneath it:

```
::error::php.yml is pinned at 1.7.0 and php.yml base.yml changed between 1.7.0 and 1.10.0
        — this repository is running an obsolete pipeline
```

Fix — bump every `rak200/.github` reference in `.github/workflows/`, not only the one it named:

```bash
git switch -c build/bump-ci-pipeline
sed -i -E 's#(uses: rak200/\.github/\.github/workflows/[a-z0-9-]+\.yml)@[0-9.]+#\1@1.10.0#' \
  .github/workflows/*.yml
git commit -am "build: bump the pipeline to 1.10.0" && git push -u origin HEAD
```

**This is §4.7 one level up, and it stayed open longer because the mask that keeps §4.7 quiet is
what hid it.** A seed's pin line is graded `masked:` — deliberately, so bumping it in the scaffold
does not redden every repository at once — and that mask was the only thing in the estate that
ever looked at a pin. Measured on 2026-08-03, before the check existed: four distinct pins across
five repositories, and `rak200/workflow`, which distributes the seed, was **six releases behind
the version its own seed named**.

The rule is §4.7's rule: it fails when something the repository **actually runs** moved, following
the closure — `js.yml` and `php.yml` both delegate to `base.yml`, so a change there reaches a
caller whose own file never moved. A pin behind by a release that touched another language stays
quiet.

**A pin that is not a release tag fails outright**, separately from staleness. A branch name would
otherwise pass every comparison, being never unequal to itself, so *pin an exact tag, never a
moving alias* had nothing enforcing it (§5, rule 11).

Two related failures from the same step, both in `rak200/.github` alone:

- **`the scaffold tells repositories to call <name>.yml, and it does not exist here`** — or *it
  declares no `workflow_call` trigger*. The reusable workflows are whatever the seeds pin, and one
  of them was overwritten by a seed for four releases. See §5, rule 12.
- The check reads `uses:` directives, not the string. Prose that quotes a pin —
  `` `…/release.yml@<tag>` `` — is not a pin, and an earlier version of the step read it as one.

### 4.9 The branch is behind `master`

Required checks are **strict**: the gate must be green against the actual merge result, not
against a stale base.

```bash
gh pr update-branch          # or: git rebase master && git push --force-with-lease
```

### 4.10 The release was cut and the publish failed — TS repos

Symptom: the tag and the GitHub Release exist, `npm view <pkg> version` is behind them, and the
`publish` job in the release run is red. The release happened; only the registry does not know.

This is **not** §4.11's situation. Nothing is wrong with the released code, so a superseding
version would burn a version number to route around a CI failure and write that failure into the
changelog permanently. The tag is immutable and correct — republish it:

```bash
gh workflow run release.yml -f republish=<tag>
gh run watch          # then confirm the registry, never the exit code
npm view <pkg> version
```

Fix the cause first, or the republish reproduces it. Every plausible cause reports the same
misleading `404 Not Found - PUT` (npm masking 401/403, upstream `npm/cli#9088`), which is why the
publish job asserts its preconditions **before** publishing and names the one that failed:

| what it asserts | what breaks it |
|---|---|
| `npm >= 11.5.1` | Node 22 ships npm 10, which cannot do the OIDC exchange |
| an OIDC endpoint in the environment | `id-token: write` missing from **either** side of the `workflow_call` |
| no `_authToken` in any npmrc | `setup-node`'s `registry-url`, which writes an empty one |

A fourth cause it cannot assert from inside the job: the **trusted publisher must be registered**
on npmjs.com, against the repository and the workflow filename `release.yml` — the caller, since
npm validates the workflow that *started* the run. npm does not validate that configuration when
it is saved, so a wrong or missing one surfaces only here, as the same 404.

### 4.11 A bad release shipped

Tags are immutable (§3.8) — rollback does not exist. The path is **forward**: a new version that
supersedes the bad one, plus marking so nobody keeps resolving it meanwhile. If a credential is
involved, §4.4 comes first — rotate before anything here.

1. **Supersede.** Open a `revert:` PR reverting the bad squash commit(s):

   ```bash
   git switch master && git pull && git switch -c fix/revert-bad-release
   git revert <bad-squash-sha> --no-edit
   git push -u origin HEAD
   gh pr create --title "revert: <original PR title>" --body "This reverts commit <bad-squash-sha>."
   ```

   Merging it opens a **patch** Release PR (measured — `revert` is a releasable type; the
   changelog lists it under `### Reverts`); merging that cuts the superseding tag. A `fix:` PR
   does the same where a surgical fix beats a revert; a `Release-As: x.y.z` footer in the PR
   **body** forces a specific version when neither type fits.

   > **A revert never subtracts.** If the bad commit is still *unreleased* — sitting in an open
   > Release PR — reverting it does **not** cancel the pending bump or remove its entry: the
   > release ships with the pair listed and a nil net diff. Cosmetic; merge anyway.

2. **Mark the bad release** — this changes what GitHub answers (humans, the API's `latest`, the
   UI badge), **not** what Composer resolves:

   ```bash
   gh release edit <bad-tag> --notes "⚠️ Defective — use <good-tag>. See #<issue>." --prerelease
   # the latest pointer is eventually consistent — re-read after a few seconds, not immediately
   gh api repos/:owner/:repo/releases/latest --jq .tag_name
   ```

   Optionally, once the superseding release exists, set it explicitly:
   `gh api -X PATCH repos/:owner/:repo/releases/<id> -f make_latest=true`.

3. **Registry layer — asymmetric, and stated rather than implied.** TS packages:
   `npm deprecate <pkg>@<bad-version> "Defective — upgrade to <good-version>"` (per-version,
   shown on every install). PHP: **Packagist has no per-version yank** — the bad version stays
   installable forever; the release-note warning and the superseding tag are the only signals a
   pinned consumer gets.

4. **Consumers.** Ecosystem repos receive the superseding tag as an ordinary Dependabot bump PR
   (§3.9) — nothing extra to do. If the defect is a **vulnerability**, additionally publish a
   GitHub Security Advisory: that is the only channel that alerts dependents beyond this
   ecosystem.

### 4.12 A branch was renamed and its protection stayed behind

Renaming a branch (`POST /repos/:owner/:repo/branches/:branch/rename`) moves what you expect and
one thing you do not:

- Open PRs **retarget themselves** to the new name and stay open.
- A ruleset whose condition is **`~DEFAULT_BRANCH`** follows the role — nothing to do.
- A ruleset whose condition names the branch — `["refs/heads/main"]` — **does not follow.** It
  stays `enforcement: active`, reports no error, and now protects a ref that does not exist.

So after any rename, list every ruleset and read its condition, not its status:

```bash
for id in $(gh api repos/:owner/:repo/rulesets --jq '.[].id'); do
  gh api repos/:owner/:repo/rulesets/$id --jq '{name, include: .conditions.ref_name.include}'
done
```

Then `PATCH` the stale condition to the new ref and read it back. This is why the seeded branch
ruleset targets `~DEFAULT_BRANCH`; name-targeted rulesets are for branches that have no role to
target — a maintenance branch such as `release/1.x` — and they are exactly the ones that fail
quietly here. The rename API also **404s on a repository with no commits**, so it is a remedy for
an existing repo and never part of scaffolding (§8.1 step 4).

---

## 5. Rules that are not negotiable

These exist because each was violated once and the failure was silent.

**This is the operator's list, and all but two of it are Layer 1** — the same rules appear in
`CONVENTIONS.md`, which every repository imports, in wording that binds a repository author rather
than whoever runs this lifecycle. The two exceptions are **10** and **12**: a merge is a procedure,
and a seed destination binds only whoever authors the scaffold. Nothing here is a rule
`CONVENTIONS.md` disagrees with; where the two differ it is audience, not drift.

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
    relabels a failure as success, so a summary that looks green can contain a failed step (§4.1).
14. **A gate that has never failed has never been tested.** Make each one fail on purpose once and
    confirm it blocks; §4.3 holds the canary per gate.

---

## 6. What actually keeps a human in the loop

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

---

## 7. Quick reference

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

## 8. Onboarding a repository

### 8.1 A new repository

Run top to bottom. Every step that writes is followed by a step that reads it back — a response
code is not evidence (rule 9). Substitute `<repo>`, `<variant>` (`php` or `ts`) and `<tag>` (the
`rak200/workflow` version to pin).

**1. Create it empty.**

```bash
gh repo create rak200/<repo> --public --description "<one line>"
```

> **Never pass `--add-readme`, `--license` or `--gitignore`.** Each forces an initial commit that
> is not the scaffold commit, on whatever branch name the account is configured for — and the last
> two write **GitHub's** templates, which are not the seeds: its MIT text carries a year and
> copyright line the seed deliberately omits. The repo would be born drifted and red its own gate
> on the first PR. `LICENSE` and `.gitignore` arrive in step 3.

The empty repository reports a `default_branch` while having **no branches at all** — a name for
something that does not exist, taken from an account-level setting that **no endpoint reads or
writes**. Read nothing into it either way: it is not evidence that the repo is on `master`, and the
only way to observe that setting at all is to create a repository and ask *it*. Step 4 settles the
branch, and step 4 is the one that gets verified.

**2. Build the tree locally, on `master`.**

```bash
git init -b master
```

`README.md` is per-repo content and therefore **not a seed**, which means no conformance check
ever looks at it. One line in it is still mandatory, in every variant, published or not:

```markdown
[![Latest tag](https://img.shields.io/github/v/tag/rak200/<repo>?sort=semver)](https://github.com/rak200/<repo>/tags)
```

It is the *live* badge class from `CONVENTIONS.md` — driven by a service, never hand-edited, and
nothing in the release path touches it (§3.8). It appears here as a checklist item precisely
because it cannot appear as a gate: six of ten repositories had gone without it, every one of them
onboarded after the convention was written, and no mechanism in this document could have noticed.

**3. Pin the conventions, then copy the seeds out of them.**

```bash
git submodule add https://github.com/rak200/workflow.git .rak200
git -C .rak200 checkout <tag>

mkdir -p .github/workflows .githooks

# scaffold/seeds.tsv IS the list — never a hand-written one here. It names the
# variant, the check form, the seed and its destination, and the same file drives
# the CI conformance check, so a copy loop that reads it cannot disagree with the
# check that grades it. `scripts/new-repo.sh` is this loop, executable.
while IFS=$'\t' read -r v form seed dest; do
  case "$v" in ''|'#'*) continue ;; esac
  [ "$v" = all ] || [ "$v" = "<variant>" ] || continue
  mkdir -p "$(dirname "$dest")"
  cp -a ".rak200/scaffold/$seed" "$dest"
done < .rak200/scaffold/seeds.tsv
chmod +x .githooks/pre-push

printf '# %s\n\n<one line>\n' "<repo>" > README.md   # not a seed: per-repo content
```

> **Copy per row, never with a glob.** `cp <dir>/*` skips dotfiles, and the language variants are
> mostly dotfiles — `.release-please-manifest.json` above all. It copies nothing, says nothing,
> and the repo is born without the file `release-please` bootstraps from.

The scaffold is **flat**: `scaffold/php/ci.yml`, not
`scaffold/php/.github/workflows/ci.yml`. Seeds live under one directory per variant — `all`,
`none`, `github`, `php`, `php-config`, `ts`, `ts-config` — and each row carries its own
destination, so mirroring the destination tree inside the scaffold would imply a correspondence
that does not exist. `all` is not a variant a repository declares; it is the row marker for seeds
that apply everywhere.

**Which pipeline a variant calls.** `none` and `github` call `base.yml`, the language-agnostic
half: they have no package to install. Every other variant calls its language pipeline —
**including `php-config` and `ts-config`**. A configuration package is a package: it ships
executable code, and a package whose CI never installs it has no CI. Both `-config` variants
called `base.yml` for a while, on the reasoning that a config package has no source. That was
true when it was written and stopped being true without anything re-examining it, leaving two
repositories green for weeks that had never run a test, an analyser or a mutant — while shipping
the binary that enforces everyone else's coverage floor. **A pipeline that is never asked the
question gives no wrong answers.** The language pipelines take a `variant:` input for exactly
this: a `-config` package must be graded against its own seed set, which *exports* the tool
configs the library variants hide.

> **A seed destination is a claim that the repository owns that path.** It is not a filename.
> The `github` variant's release caller was seeded to `.github/workflows/release.yml` — free in
> every other repository, and in `rak200/.github` the path holding the **reusable release
> workflow the whole estate pins**. The seed did not sit beside it; it overwrote it, and every
> tag from `1.8.1` shipped an `on: push` caller under the name everyone calls. Four releases,
> unnoticed, because the only repository that could break was pinning `@1.8.0` — past its own
> breakage. When adding a seed, check the destination against what the *target* repository
> already keeps there, not against what the other variants happen to leave free.

`.gitmodules` needs **no `branch =` line**: Dependabot falls back to the source repository's
default branch, and it bumps to the latest **tag** reachable there, skipping untagged commits.

**The caller pins arrive at the seed's version, and the seed is not kept current — bump them
now.** Nothing grades the seed's pin: the `ci.yml` and `release.yml` rows are `masked:` on
`@<tag>`, deliberately, so that bumping a pin in the scaffold does not redden every repository at
once (§4.7, §4.8). And nothing updates it either — Dependabot's `github-actions` ecosystem reads
`<directory>/.github/workflows/`, and the seeds live at `scaffold/<variant>/ci.yml`, outside it.
The seed's value is therefore whatever it was the last time a human changed it, which on
2026-08-20 was `1.10.0` against a current `1.13.1`.

```bash
latest=$(gh api repos/rak200/.github/tags --jq '.[0].name')
sed -i -E "s#(uses: rak200/\.github/\.github/workflows/[a-z0-9-]+\.yml)@[0-9.]+#\1@$latest#" \
  .github/workflows/*.yml
grep -hoE 'workflows/[a-z0-9-]+\.yml@[0-9.]+' .github/workflows/*.yml   # read it back
```

Skip it and the repository's **first pull request fails §4.8** — for a line its author did not
write. Dependabot would clear it on the weekly `github-actions` pass, so the cost of forgetting is
bounded; the cost of remembering is one command.

**Left as a step rather than fixed in the scaffold, knowingly.** Two structural fixes were
designed and measured — a marker in the seed that the onboarding script substitutes, and restructuring so
Dependabot can see the seeds — and both were rejected as disproportionate to one red pull request
in a repository that self-heals within a week. RFC 0017 `E.28` carries the argument and the
measurements, so the question does not have to be reopened from scratch.

**4. Commit, and push `master` first. This is the step that sets the default branch.**

```bash
git add -A
git commit -m "feat: scaffold the repository from the rak200 baseline"
git remote add origin https://github.com/rak200/<repo>.git
git push -u origin master

gh api repos/rak200/<repo> --jq '.default_branch'   # expect: master
```

**The first branch pushed into an empty repository becomes its default.** Nothing else in this
procedure puts the repo on `master`, and no second push moves it afterwards. If the read-back says
anything but `master`, stop — do not continue and rename later; delete the repo and start again
from step 1, because a rename leaves name-targeted rules pointing at the old name (§4.12).

**5. Platform settings, then read them back.**

```bash
gh api -X PATCH repos/rak200/<repo> \
  -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY \
  -F allow_auto_merge=true \
  -F delete_branch_on_merge=true
gh api -X PUT repos/rak200/<repo>/actions/permissions/workflow \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
gh api -X PUT repos/rak200/<repo>/actions/permissions \
  -F enabled=true -f allowed_actions=all -F sha_pinning_required=true
gh api -X PUT repos/rak200/<repo>/private-vulnerability-reporting

gh api repos/rak200/<repo> --jq '{allow_squash_merge,allow_merge_commit,allow_rebase_merge,squash_merge_commit_title,squash_merge_commit_message,allow_auto_merge,delete_branch_on_merge}'
gh api repos/rak200/<repo>/actions/permissions/workflow
gh api repos/rak200/<repo>/actions/permissions
gh api repos/rak200/<repo>/private-vulnerability-reporting
```

**`allow_auto_merge` is not optional.** It defaults to off, and `--auto` — the merge command §3.6
and §7 both prescribe — needs it: `gh pr merge --auto` enables auto-merge through a mutation the
platform refuses outright when the repository has the feature disabled.

**`sha_pinning_required` lives one path segment above the token defaults**, on the repository's
Actions *policy* rather than its token settings, and the two endpoints are easy to mistake for one.
It is what makes rule 6 — third-party actions pinned by full commit SHA — a platform rule instead of
a review habit, and the Actions allowlist was dropped in exchange for it. Two properties matter when
writing it:

- **The PUT replaces the whole policy object.** Send `enabled` and `allowed_actions` with it or they
  are rewritten to defaults. The read-back above is what proves they were not.
- **It does not reach reusable-workflow references.** `uses: rak200/.github/…@<tag>` is untouched,
  so rule 11 — exact tag, never a moving alias — stands beside it rather than against it.

A floating tag then fails at `Set up job`, with the platform's own message and as a **red check
rather than an absent one**:

```
The action actions/setup-node@v4 is not allowed in rak200/<repo> because all actions must be
pinned to a full-length commit SHA.
```

The squash message sources are not cosmetic: on GitHub's defaults the squash commit takes the
*branch's* message rather than the PR title, which breaks `release-please` silently (§4.5).
`can_approve_pull_request_reviews` is `release-please`'s prerequisite — without it the Release PR
is never opened, and the failure arrives late and dirty.

**6. Labels — additively, then the one-shot deletion.**

Apply `.rak200/labels.yml` with the label-sync action or by hand; **never prune**, because labels
outside the canonical set belong to automations (Dependabot creates `dependencies` and
`github_actions` on its own within minutes). GitHub's stock labels (`bug`, `enhancement`,
`good first issue`, …) are deleted **once, by hand, now** — this is the only moment the repo has no
history to lose. Three of them (`bug`, `duplicate`, `wontfix`) are canonical too, so the sweep is
followed by re-applying `labels.yml`, which puts those three back with the ecosystem's colours and
descriptions.

On an **existing** repository the "no history to lose" premise is not free — check it before
deleting, because a label removed here disappears from every issue and pull request that carries it:

```bash
gh api "repos/rak200/<repo>/issues?state=all&per_page=100" \
  --jq '[.[]|select(.labels|length>0)|{n:.number,labels:[.labels[].name]}]'
```

An empty result means the sweep costs nothing. Anything else is a decision, not a step.

**7. Rulesets — after step 4, never before.**

```bash
# the canonical JSON lives in rak200/.github, a different repository — fetch, then apply
for r in branch tag; do
  gh api "repos/rak200/.github/contents/rulesets/$r.json" -H "Accept: application/vnd.github.raw" > "/tmp/$r.json"
  gh api -X POST "repos/rak200/<repo>/rulesets" --input "/tmp/$r.json"
done
.rak200/scripts/check-rulesets.sh rak200/<repo>    # read it back by COMPARISON
```

**The read-back is a comparison, not a listing.** What stood here printed
`{name,target,enforcement}` — it proved two rulesets existed and nothing about what they
contained, which satisfies rule 9 in form and not in substance. `check-rulesets.sh` diffs the live
rulesets against the canonical JSON in both directions: a declared parameter whose value differs,
and **a parameter GitHub applied that the file never declared**.

That second direction is the one that earns its keep. Measured 2026-08-24 on a throwaway ruleset:
a `POST` of five `pull_request` parameters is stored as **eight**, and a `PUT` of the same five
re-injects the extras rather than removing them — **a ruleset cannot be returned to its
declaration by re-applying the file.** Four parameters were arriving undeclared on the rule that
decides who may merge, across all six onboarded repositories, and were found by accident rather
than by any read-back. They are now named in the canonical JSON, so the next platform default
shows up as the only undeclared key rather than hiding among them.

The same script is the estate sweep — it takes any number of repositories, and it is deliberately
**not** a required check. A GitHub default arrives everywhere at once, and a gate that reddens
every repository simultaneously for something absent from the pull request is the slow, noisy
check people learn to route around (§4.7's argument, one layer up):

```bash
.rak200/scripts/check-rulesets.sh rak200/utils rak200/ui rak200/workflow rak200/.github \
  rak200/coding-standard-php rak200/coding-standard-ts
```

The JSON is the canonical copy in [`rak200/.github`](https://github.com/rak200/.github/tree/master/rulesets) — clone it or fetch the two files; they are versioned there, not here. Order matters: the branch ruleset's
`pull_request` rule would reject the very push in step 4 that establishes the default branch.

**The branch ruleset** carries a `bypass_actors` entry for the repository admin, in `bypass_mode:
pull_request`. It was granted for the Release PR's absent-check deadlock, and that deadlock turned
out not to exist — the Release PR's check is held, not absent (§3.8), and approving the run clears
it without any bypass. The entry stays for the blame-registration PR and as a safety net, on
weaker grounds than it was granted. The mode is the narrow part
and must be read back as such: `always` would permit a **direct push** to `master`, which this
design does not want. Within the PR path the entry is wide — it exempts every API call the actor
makes — which is why merges go through `gh pr merge` (rule 10) and why an `--admin` merge can cross
a red required check.

**The tag ruleset carries no bypass at all**, and not by choice: GitHub rejects the narrow mode on
a tag ruleset outright — *"bypass mode must not be 'PULL_REQUEST' for tag rulesets"* — which left
`always` or nothing. Nothing is correct here. Its rules block **moving and deleting** a tag, never
creating one, so `release-please` cuts releases untouched, and moving a released tag is exactly
what a bad release procedure does.

**8. Release bootstrap.** **Every variant releases** — including the prose ones. A repository
whose tags are typed by hand is a repository whose version is typed, which the whole versioning
policy exists to prevent, and it matters most in the baseline repositories because their tags are
what every other repository pins. It also matters now in a way it did not before: submodule bumps
arrive daily (§3.9), and a bump PR from a repository with no `CHANGELOG.md` says nothing about
what it changes.

A greenfield repo seeds `.release-please-manifest.json` at `{".": "0.0.0"}` — plus `version.txt`
where the config says `release-type: simple`, since a repository with no package manifest needs
somewhere for the version to live. `release-please` owns that file from the first release on; it
is derived state that happens to be one line long, not a number anyone types. `CHANGELOG.md` is
never seeded: the first Release PR writes it.

The seeded `release-please-config.json` does the rest — but only because it
names two settings that would otherwise default against this design, and both were found the hard
way on the first release ever cut here:

- `initial-version: "0.1.0"`. `bump-minor-pre-major` governs bumps *from* a version and says
  nothing about the first one, which release-please defaults to **`1.0.0`**. Without this line
  every new repository is handed the unchosen `1.0.0` that the versioning policy exists to prevent.
- `include-component-in-tag: false`. `include-v-in-tag: false` controls the `v` and nothing else;
  the component defaults to **on** and prefixes the package name, so the first tag comes out
  `mypackage-0.0.0`.

Neither is visible in a diff of a well-formed version. **Read the first Release PR's title before
merging it** — it is the only place either mistake shows.

An existing repo is a different procedure — §8.2.

**8b. Registry publishing — TS repos only, and only the first time.** Until this is done the
release ends at the git tag and the package is installable by nobody. On npmjs.com, *Packages →
the package → Settings → Trusted publishing*: register this repository and the workflow filename
**`release.yml`** — the caller, never `npm-publish.yml`, because npm validates the workflow that
started the run. The package must exist before it can be configured, so publish the first version
by hand:

```bash
npm publish            # from a clean checkout of the tag, with publishConfig.access set
```

`package.json` needs `"publishConfig": { "access": "public" }`: a scoped package publishes as
restricted by default and the publish fails on a free plan. PHP repos have nothing to do here —
Packagist resolves from the git tag.

**9. Per-clone local state** — not committed, not inheritable, and therefore owed by every clone:

```bash
git config core.hooksPath .githooks
git config blame.ignoreRevsFile .git-blame-ignore-revs
gitleaks version   # must print exactly the version .githooks/pre-push pins
```

**The version is part of the install, not a detail of it.** The hook refuses the push unless
`gitleaks version` matches the version it pins, which is the same version `base.yml` pins for CI
via `GITLEAKS_VERSION`. Two versions of one scanner are two rule sets: a rule present in one and
absent in the other means a secret caught locally sails through CI, or the reverse, and neither
half reports anything odd. Install that version specifically — a package manager's `latest` is
the thing this pin exists to prevent. `apt` in particular is far behind and would reintroduce the
divergence on installation.

The hook **refuses to push** when gitleaks is absent rather than skipping the scan, so a missing
install is loud. Two things about the install are worth knowing: winget puts the package directory
on the **user** PATH rather than a shim in `WinGet\Links`, so already-open terminals keep failing
until they are restarted; and `core.hooksPath` pointing at a directory that does not exist is
silent, which buys the appearance of a hook and none of the scanning — so set it only once
`.githooks/pre-push` is actually there.

Bumping the pin is a **two-file change, made together**: `scaffold/all/.githooks/pre-push` here and
`GITLEAKS_VERSION` in `rak200/.github`'s `base.yml`. Nothing checks that the two agree — the seed
gate proves every repo matches this seed, and `base.yml` is a different repository — so the pair is
held by this paragraph and by the comment in each file. The seeded `.gitleaks.toml` carries a
`minVersion` recording the same number, but it only warns and exits 0, so it documents the pin and
never enforces it.

**10. Fire a canary before calling it conformant.** Open a PR that drifts one seed on purpose
(append a line to `.gitattributes`). Required: **`ci / gate` FAILURE** — the full name, and it must
have *run* rather than been skipped — `mergeStateStatus` **BLOCKED**, and a plain
`gh pr merge --squash` refused with *"the base branch policy prohibits the merge"*. Then close the
PR and delete the branch.

```bash
gh pr view <n> --json mergeStateStatus,statusCheckRollup \
  --jq '{state:.mergeStateStatus, checks:[.statusCheckRollup[]|{name,conclusion}]}'
```

Branch the canary **from the current tip of `master`**. Under `strict_required_status_checks_policy`
a stale branch is refused for being behind, which looks identical to being refused for the red
gate — and proves nothing.

**11. Final read-back.** `default_branch` = `master`; two rulesets `active`; the seven merge/permission
fields as written in step 5; `sha_pinning_required` **true** with `allowed_actions` still `all`; the
canonical labels present and the stock ones gone; `git submodule status` clean at `<tag>`; `ci` green
on `master`.

### 8.2 An existing repository

Same procedure minus steps 1–4 (the repo and its default branch already exist). Verify the dist
surface (`git archive HEAD | tar -t` against the `export-ignore` list).

#### Bootstrapping `release-please` on a repo that already has tags

**Seed `.release-please-manifest.json` at the last tagged version. Never `bootstrap-sha`.**

```bash
gh api repos/rak200/<repo>/tags --jq '.[0].name'     # e.g. 0.3.0
printf '{ ".": "0.3.0" }\n' > .release-please-manifest.json
```

That seed alone bounds the commit window: the pre-convention history above it is never parsed, so
a repository with years of unstructured messages needs nothing done to them. The bare tag is found
even with **zero GitHub Releases present** — `release-please` looks for Releases first, then falls
back to `looking for tagName`.

The manifest is **per-repo state, not a seed**; conformance never compares it. `new-repo.sh` writes
`0.0.0` for a repository with no history, which is exactly wrong here — a manifest below the real
tags makes the next release re-cut a version that already exists.

`release-please-config.json` *is* a seed and arrives with step 3 already correct: `include-v-in-tag`
and `include-component-in-tag` both `false`, `initial-version` explicit, and for a repo still in
`0.x` both `bump-minor-pre-major` and `bump-patch-for-minor-pre-major` `true`. None of those are
safe to leave defaulted — see the box below.

**No `extra-files` entry, and do not add one.** The design called for one so the Release PR could
rewrite a hard-coded version badge in `README.md`. The badge is dynamic instead —
`shields.io/github/v/tag/rak200/<repo>?sort=semver` reads the tag at render time — so there is
nothing to rewrite, and an `extra-files` rule pointing at a string that no longer exists is a
release step that silently does nothing.

Three things to do in the same onboarding PR, each of them a failure someone already hit:

- **PHP: drop the `"version"` field from `composer.json`.** The version comes from the tag.
  `release-please` honours its absence end-to-end; leaving it means two sources of truth and one of
  them hand-typed. **TypeScript: leave `package.json`'s `version` in place** — npm requires it, and
  `release-please` maintains it. What must be true there is that it **already matches the latest
  tag**: `coding-standard-ts` carried `0.1.0` across four hand-cut tags, and a manual publish would
  have put `0.1.0` on npm immutably, below the real version.
- **Reconcile the hand-written unreleased `CHANGELOG.md` section**, or the first release ships a
  duplicate of it.
- **Expect one-time reserialization noise** in the first Release PR — `composer.json` reformatted,
  `package.json` key order changed. Pre-normalise if the diff would obscure the review.

Bootstrap from **committed state**. A "version ahead of tag" on `utils` turned out to be an
uncommitted working-tree edit, and an in-flight `release/4.5.0` branch was bumping the very pin the
bootstrap drops.

> **The tag format and the first version are what a release automation gets wrong silently**,
> because nothing anywhere rejects a well-formed wrong version. Two defaults, both measured on
> `rak200/ui`, the first release this pipeline cut from zero: a manifest at `0.0.0` plus
> `bump-minor-pre-major` does **not** yield `0.1.0` — those options govern bumps *from* an existing
> version, and the first one is governed by `initial-version`, which defaults to **`1.0.0`**. And
> `include-component-in-tag` defaults to **`true`**, prefixing the tag with the package name
> (`ui-0.0.0`) even with `include-v-in-tag: false` set: one option controls the `v`, another
> controls the component, and setting only the first *looks* like it settled the tag format.
> A component-prefixed tag is not a version Composer reads, which makes the release invisible to
> every consumer while everything reports success.

Four more things differ, and every one of them was found by running this section rather than
reading it.

**The copy loop in step 3 destroys a `prefix:N` seed.** `cp` is right for an `exact` seed and wrong
for a prefix one, where only the header is the seed and everything below it is the repository's own
history. Copying the seed over `.git-blame-ignore-revs` silently erased two recorded style
revisions. Restore the tail after the loop, or skip the row and splice:

```bash
{ head -n 4 .rak200/scaffold/all/.git-blame-ignore-revs
  git show HEAD:.git-blame-ignore-revs | tail -n +5
} > .git-blame-ignore-revs.new && mv .git-blame-ignore-revs.new .git-blame-ignore-revs
```

**The label sweep needs the check in step 6.** A new repository has nothing to lose; this one might.

**Rulesets come after the onboarding PR merges, not before it.** The branch ruleset requires
`ci / gate`, and that check does not exist until the pipeline the PR introduces has run on the
default branch once. Applying the ruleset first deadlocks the very PR that would satisfy it.

**The `eol=lf` normalisation is conditional.** Land it as a `style:` commit *if it changes
anything* — a repository that already carried `* text=auto eol=lf` normalises nothing, and a
`style:` commit recording no revision is noise in `.git-blame-ignore-revs`. Check first:

```bash
git ls-files -z | xargs -0 grep -lIU $'\r'   # empty output: nothing to normalise
```

> **A template repository is not used for either path, and `gh repo create --template` was
> deliberately dropped.** Template generation copies files faithfully, submodule gitlink included,
> but carries **no** rulesets, no labels, no secrets and no repo settings, and silently restores
> GitHub's default merge configuration. Steps 5–7 would be owed regardless, which leaves the
> template a second artifact to version and keep conformant in exchange for a file copy step 3
> already does.
>
> The default branch is settled the same way — **by mechanism, not by a setting**. The
> account-level default branch name was `main` when measured, it is writable **only through the
> UI**, and **no endpoint reads it**: `GET /user` has no such field. An empty repository reports
> that name while `GET /repos/…/branches` returns `[]` — a name for a branch that does not exist.
> Depending on it would have put the very first step outside rule 9 (read back what you write).
> It is not depended on: **the first branch pushed into an empty repository becomes the default**,
> which is why step 4 pushes `master` before anything else.

---

## 9. Retiring a repository

**Archive. Never delete.** Deleting breaks every pinned consumer, every submodule gitlink and
every tag reference at once, and nothing about it is reversible. Archiving breaks none of them:
an archived repository still **clones**, still serves as a **submodule source**, and its **tags
still resolve**, so consumers are untouched.

**The order below is not a suggestion.** Archiving makes the repository **read-only** — `git push`
answers `403 This repository was archived so it is read-only`, and so does the issues API. Anything
you meant to write afterwards cannot be written. Everything lands first; the flag is last.

### 9.1 Retiring it for good

1. **Decide the replacement**, if there is one. It goes in the marker in step 2 and in the README
   notice.
2. **One final PR**, through the normal flow, carrying all of:
   - `"abandoned": "<replacement>"` (or `true`) in `composer.json` — see 9.3;
   - a notice at the top of `README.md` saying it is retired, since when, and what to use instead;
   - a `CHANGELOG.md` entry;
   - an emptied `ROADMAP.md` (the pruning check has nothing to say about a repository with no
     roadmap, but a stale one outlives the project);
   - `SECURITY.md` stating that **no version is supported**.
3. **Cut a final release** through the standard path (§3.8). This is the step people skip: the
   marker only reaches consumers if it ships **in a tag they resolve**.
4. **Close open issues and pull requests deliberately.** Archiving freezes them exactly as they
   are — an open PR on an archived repository is a question nobody can ever answer.
5. **Remove the dependency from its consumers** — bump them off it or drop it. Every consumer in
   this ecosystem is one you control: none of these libraries is published to a public registry,
   and they resolve as VCS dependencies from repositories in this account. That is also why there
   is **no maintenance branch** for an old major anywhere here — the consumer is upgraded instead.
   Nine majors have shipped across the estate and not one `release/x.y` has ever existed. What
   happened instead, and nothing recorded it: consumers were left frozen — `sql-builder` requiring
   `utils ^1.0.0` while `utils` was at `4.5.0`, `devr` requiring `caster ^1.0.0` while `caster` was
   at `3.x`. The old major was never patched **and** the consumer was never upgraded; the version
   simply froze. A maintenance branch would not have prevented that.
6. **Archive, then read it back.**

```bash
gh api -X PATCH repos/rak200/<repo> -F archived=true
gh api repos/rak200/<repo> --jq '.archived'      # expect: true
```

> **Do not read the workflow list to confirm it.** Workflows on an archived repository still report
> `state: active` although nothing can trigger them. The authoritative field is `archived` on the
> repository itself — read back, per rule 9.

### 9.2 Undoing it

```bash
gh api -X PATCH repos/rak200/<repo> -F archived=false
```

Write access returns immediately (verified). Archiving is a reversible decision, which is the
second reason it is the only one on offer.

### 9.3 Deprecating without retiring

A library that is discouraged but still accepts fixes takes the marker alone — step 2's
`"abandoned"` key, released as a normal patch. **It reaches consumers without a registry:** under
this ecosystem's VCS resolution, a consuming `composer update` prints

```
Package rak200/<repo> is abandoned, you should avoid using it. Use <replacement> instead.
```

so the signal does not wait on publication. Archiving is what makes the state permanent; the marker
is what makes it visible.
