# Development lifecycle

> **Seed artifact for `rak200/workflow`.** This file is drafted inside RFC 0017 and moves to the
> root of `rak200/workflow` when that repository is built (Rollout step 2). Consumers then read it
> at `.rak200/LIFECYCLE.md`, pinned to the conventions tag that repo chose.

This is the **primary reference** for how work moves through any `rak200` repository, from an idea
to a released tag. It is written to be followed by a human reading it once, by an **agent**
executing it as instructions, and by a **new contributor** who has never seen this ecosystem.

Where a rule exists because a mechanism behaves in a non-obvious way, the reason is stated inline.
Those reasons are not commentary — they were established empirically, and removing the rule
reintroduces the failure.

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
| Local secret gate | `.githooks/pre-push` (`gitleaks`) | seeded from the scaffold; `core.hooksPath` set per clone at onboarding |
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
`.rak200/proposals/TEMPLATE.md`. Ordinary bugs and features do not need one.

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
still cuts a superseding release (see §4.10).

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
check is still queued. It merges when the gate turns green.

**Requesting changes.** On either path, review comments and `gh pr review --request-changes` work
normally. A new push **dismisses the existing approval** — deliberately, so an approval never
carries over to code it did not see. Conversations must be resolved before merge.

### 3.7 Merge — *maintainer*

Squash only. The result is exactly one Conventional Commit on `master`, titled with the PR title.
The branch is deleted automatically.

### 3.8 Release — *release-please, then the maintainer*

`release-please` watches `master` and maintains an open **Release PR** accumulating every
releasable commit since the last tag, with the derived version bump and generated `CHANGELOG.md`.
It also rewrites the latest-release badge in `README.md`, through the `extra-files` entry and its
`x-release-please-version` annotation — that badge is maintained by this PR, never by hand.
It carries the `autorelease: pending` label, which is **functional state** — never remove it.

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

**`gitsubmodule` runs daily; everything else runs weekly.** The asymmetry is deliberate and it is
recent. Since conformance began failing on an obsolete pin (§4.7), the baseline is the only
dependency whose staleness **blocks a merge** rather than merely lagging: between a baseline
release and the next Dependabot pass, every pull request in an affected repository opens red, and
the only way through is a hand-written bump. Weekly made that window seven days wide, against a
baseline that has cut seven tags in a single day. An outdated library is outdated; an outdated
baseline stops the work.

**Not yet observed in production, and worth watching the first time it fires.** Every repository
declares `gitsubmodule`, and to date the updater has opened bump PRs for `composer`, `npm` and
`github-actions` — and **none** for a submodule. Nothing is known to be wrong: its only pass so
far predated the pins existing. What the first real pass has to confirm is that it targets a
**version tag** and not the branch tip, which is what the design assumes and what a simulation,
not this estate, established. A bump PR pointing at an untagged commit means the tag-pinned
property is fiction, and conformance will say so out loud (§4.7).

**One pin Dependabot does not move: the CI caller's reusable-workflow reference.** Measured
(round 3): the updater ignores `jobs.<id>.uses`, tag or Release, even though the dependency graph
parses it. After a `rak200/.github` release, the pin is bumped **manually** in each consumer — an
ordinary PR the maintainer or an agent opens:

```bash
git switch -c build/bump-ci-pipeline
sed -i 's#\(uses: rak200/.github/.github/workflows/[a-z]*\.yml\)@[v0-9.]*#\1@1.5.0#' .github/workflows/ci.yml
git commit -am "wip" && git push -u origin HEAD
gh pr create --title "build(ci): bump pipeline to 1.5.0"
```

The PR runs that repo's own CI against the new pipeline before it lands — the property that makes
the exact pin worth its manual cost.

**A conventions bump may red its own PR — by design.** CI conformance-checks every seeded copy
(`.editorconfig`, `dependabot.yml`, the CI caller's shape with its pin line masked, …) against
the **pinned** `.rak200/scaffold/`. A submodule bump whose new tag changed a seed stays red until
the **same PR** re-copies the changed file — the sync is atomic with the bump, and drift cannot
land quietly. (`.release-please-manifest.json` is per-repo state, not a seed; it is never
compared.)

**Rulesets are not files and follow a different path.** After a `rak200/.github` release that
changes the canonical ruleset JSON, run the sweep: re-apply per repo via `gh api`, then **read
back** (§5, rule 9). No scheduled audit exists — that would need a stored admin credential.

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

### 4.8 The branch is behind `master`

Required checks are **strict**: the gate must be green against the actual merge result, not
against a stale base.

```bash
gh pr update-branch          # or: git rebase master && git push --force-with-lease
```

### 4.9 The release was cut and the publish failed — TS repos

Symptom: the tag and the GitHub Release exist, `npm view <pkg> version` is behind them, and the
`publish` job in the release run is red. The release happened; only the registry does not know.

This is **not** §4.10's situation. Nothing is wrong with the released code, so a superseding
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

### 4.10 A bad release shipped

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

### 4.11 A branch was renamed and its protection stayed behind

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
7. Untrusted values — PR titles, branch names, issue bodies — reach a script through `env:` and
   are quoted. Never interpolated into `run:`.
8. `secrets: inherit` is forbidden in reusable-workflow callers.
9. Every API-driven setting is **read back** after writing. A settings write can return `200` and
   change nothing.
10. A merge goes through **`gh pr merge`**, never the raw REST endpoint. The bypass entry in the
    ruleset exempts the maintainer's **every** unflagged API call from the PR rules — measured: a
    plain API merge crossed a red `ci / gate` — and only the `gh` client refuses to do that
    without `--admin`.

---

## 6. What actually keeps a human in the loop

Two different things, and naming them separately is the point.

**The CI gate is mechanical, on every path.** A red `ci / gate` refuses the merge — for the
maintainer, for an agent on the maintainer's identity, for a bot. This is the platform, not
discipline (the review count being 0 is what makes it so: nothing on the common path routes
through the bypass — see the RFC's *Review requirement*).

**The review is real only where the author is a separate identity.** On the common path the
maintainer authors the PR and GitHub requests no code owner — there, what keeps the human in the
loop is that **the human is present while the agent works** and merges deliberately. The review
mechanism is real for bot-authored PRs and for anything arriving from an identity that is not the
maintainer's.

The residual trust is narrow and named: the bypass entry (kept for the Release PR) exempts the
maintainer's unflagged API calls from all PR rules, which is why rule 10 exists; and *who* runs
the merge command is procedural, not enforced. If agents are ever given **distinct identities**,
their PRs move to Path B and code-owner review begins to cover them with no new mechanism.

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

# merge — bot PR
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
`none`, `github`, `php`, `php-config`, `ts` — and each row carries its own destination, so
mirroring the destination tree inside the scaffold would imply a correspondence that does not
exist. `all` is not a variant a repository declares; it is the row marker for seeds that apply
everywhere.

`.gitmodules` needs **no `branch =` line**: Dependabot falls back to the source repository's
default branch, and it bumps to the latest **tag** reachable there, skipping untagged commits.

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
from step 1, because a rename leaves name-targeted rules pointing at the old name (§4.11).

**5. Platform settings, then read them back.**

```bash
gh api -X PATCH repos/rak200/<repo> \
  -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY \
  -F delete_branch_on_merge=true
gh api -X PUT repos/rak200/<repo>/actions/permissions/workflow \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
gh api -X PUT repos/rak200/<repo>/private-vulnerability-reporting

gh api repos/rak200/<repo> --jq '{allow_squash_merge,allow_merge_commit,allow_rebase_merge,squash_merge_commit_title,squash_merge_commit_message,delete_branch_on_merge}'
gh api repos/rak200/<repo>/actions/permissions/workflow
gh api repos/rak200/<repo>/private-vulnerability-reporting
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
gh api repos/rak200/<repo>/rulesets --jq '[.[] | {name,target,enforcement}]'
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

**8. Release bootstrap.** A greenfield repo seeds `.release-please-manifest.json` at
`{".": "0.0.0"}`, and the seeded `release-please-config.json` does the rest — but only because it
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
gitleaks version || winget install --id Gitleaks.Gitleaks --exact   # or the platform's equivalent
```

The hook **refuses to push** when gitleaks is absent rather than skipping the scan, so a missing
install is loud. Two things about the install are worth knowing: winget puts the package directory
on the **user** PATH rather than a shim in `WinGet\Links`, so already-open terminals keep failing
until they are restarted; and `core.hooksPath` pointing at a directory that does not exist is
silent, which buys the appearance of a hook and none of the scanning — so set it only once
`.githooks/pre-push` is actually there.

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

**11. Final read-back.** `default_branch` = `master`; two rulesets `active`; the six merge/permission
fields as written in step 5; the canonical labels present and the stock ones gone; `git submodule
status` clean at `<tag>`; `ci` green on `master`.

### 8.2 An existing repository

Same procedure minus steps 1–4 (the repo and its default branch already exist), plus the
`release-please` bootstrap for a repo that already has tags and a hand-written `CHANGELOG.md` — the
measured procedure is in the RFC's *Release bootstrap*. Verify the dist surface
(`git archive HEAD | tar -t` against the `export-ignore` list).

Four things differ, and every one of them was found by running this section rather than reading it.

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

> **A template repository is not used for either path** — see the RFC's *New-repo creation*. Template
> generation copies files faithfully, submodule gitlink included, but carries **no** rulesets, no
> labels, no secrets and no repo settings, and silently restores GitHub's default merge
> configuration. Steps 5–7 would be owed regardless, which leaves the template a second artifact to
> version and keep conformant in exchange for a file copy step 3 already does.

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
   this ecosystem is one you control (RFC, *Maintaining an old major*).
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
