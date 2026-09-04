# Contingencies

Something in the cycle went wrong. Each heading is a state you can observe rather than a cause you
have to guess: find the one that matches what is in front of you.

`LIFECYCLE.md` carries the cycle itself and `REPOSITORY.md` the onboarding and retirement of a
repository. How a rule here is written is `CONVENTIONS.md` §How to read a rule here.
rak200/workflow#126

## 1. `ci / gate` is red

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

## 2. `ci / gate` never appears and the PR waits forever

This is the **absent check** deadlock, and it is the most dangerous state in this system because
it looks like patience rather than failure. Two known causes:

1. **The workflow did not start at all** — `startup_failure` with zero checks. Usually an invalid
   workflow file or a repository Actions policy refusing it. **One whose run carries no error is
   transient**: re-run the SHA before diagnosing, because a real misconfiguration says what it is.
   rak200/workflow#89
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

   A hit means approve and wait, not diagnose. The Release PR is the routine case
   (`LIFECYCLE.md` §3.8) — its run is held on every release, by design rather than by fault.

An earlier version of this section called that state "a check that exists and is held". It does
not exist: the *run* is held, and the check it would publish is missing exactly as if the run had
never been created. The distinction matters because it is the one the diagnosis turns on.

## 3. A gate is green and should not be

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

## 4. A credential leaked

**Rotate. Do not revert.** A revert removes the credential from the tip, not from history, and
not from anywhere the history has already been fetched. Reverting and moving on leaves a live
credential in a public place.

1. Revoke the credential at its source, immediately.
2. Issue a replacement.
3. Then clean the repository if you wish — this is cleanup, not remediation.

`gitleaks` runs in every repo for exactly this reason: GitHub's own secret scanning covers only
validated provider patterns, and misses private keys and generic secrets entirely.

## 5. A merge landed with the wrong commit message

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

**A message that parses but carries a hidden type is a different case, and it is recoverable.**
The change is on `master` and nothing publishes it; an empty release window is indistinguishable
from a healthy one. `Release-As:` is **not** the recovery — it chooses which version, never whether
the Release PR opens. The recovery is a commit whose type is **visible**: `feat`, `fix`, `perf`,
`revert`, and `docs` in the `none` variant. Once one exists the whole window ships in the same tag,
hidden commits included — they reach the tag without reaching the changelog, which is the right
record of what a consumer received. rak200/workflow#120

## 6. A Dependabot PR fails CI

Treat it as a real failure — it is telling you the dependency broke something.

```bash
gh pr comment <n> --body "@dependabot rebase"     # branch is behind master
gh pr comment <n> --body "@dependabot recreate"   # rebuild the PR from scratch
```

Do not push commits to a Dependabot branch: it stops managing the PR from then on.

## 7. The submodule pin is obsolete

Symptom: `ci / conformance` fails on **The pinned scaffold is not obsolete**, naming the seeds
that moved. Fix:

```bash
git -C .rak200 fetch --tags
git -C .rak200 checkout <latest tag>
# then re-copy the seeds it named, from .rak200/scaffold/, and commit both together
git add .rak200 <the seeds> && git commit -m "build: bump .rak200 to <tag>"
```

**A stale pin is not safe.** The submodule carries `scaffold/`, the seeds CI grades against, and a
repository grades itself against **its own pinned copy**, so an old pin does not merely miss an
addition — it makes the repository judge itself by an obsolete rulebook **and pass**. The check
built to detect drift was the thing concealing it. rak200/workflow#16

Measured on `rak200/utils`: pinned eight releases behind, `release-please-config.json` changed
underneath it, gate green, and its next release would have been tagged `utils-4.6.0` — which
Composer does not read as a version, making the release invisible to every consumer. The
conformance step above now catches this, and it fails only when a seed **this variant consumes**
actually changed, so an old pin with nothing moving under it stays quiet.

Two properties follow, and anything added to `.rak200/` must preserve both: the pin is a **tag**,
never a bare commit (a commit has no version to reason about, and the step rejects it); and
whatever the submodule carries must be comparable between two tags, or staleness becomes
undetectable again.

## 8. The pipeline pin is obsolete

Symptom: `ci / conformance` fails on **The pinned pipeline is not obsolete**, naming the workflow
and what moved underneath it:

```
::error::php.yml is pinned at 1.7.0 and php.yml base.yml changed between 1.7.0 and 1.10.0
        — this repository is running an obsolete pipeline
```

Fix — **usually, wait: merge the `build(deps)` pull request Dependabot opens.** It bumps every
`rak200/.github` reference in `.github/workflows/` as a group, and `github-actions` runs daily, so
the red is normally hours old rather than a task (`LIFECYCLE.md` §3.9).

Do it by hand only when the wait is the problem — an urgent pipeline fix, or a release whose
consumers are blocked now. The scope is every reference, not only the one the error named:

```bash
git switch -c build/bump-ci-pipeline
sed -i -E 's#(uses: rak200/\.github/\.github/workflows/[a-z0-9-]+\.yml)@[0-9.]+#\1@1.10.0#' \
  .github/workflows/*.yml
git commit -am "build: bump the pipeline to 1.10.0" && git push -u origin HEAD
```

Beating the bot to it costs a pull request that would have opened on its own; on 2026-08-30 four
were walked by hand eighteen minutes before the first Dependabot pass did the same work.

**This is §7 one level up, and the mask that keeps §7 quiet is what hid it.** A seed's pin line
is graded `masked:` — deliberately, so bumping it in the scaffold does not redden every repository
at once — and that mask was the only thing in the estate that ever looked at a pin.
rak200/workflow#30

The rule is §7's rule: it fails when something the repository **actually runs** moved, following
the closure — `js.yml` and `php.yml` both delegate to `base.yml`, so a change there reaches a
caller whose own file never moved. A pin behind by a release that touched another language stays
quiet.

**A pin that is not a release tag fails outright**, separately from staleness. A branch name would
otherwise pass every comparison, being never unequal to itself, so *pin an exact tag, never a
moving alias* had nothing enforcing it (`LIFECYCLE.md` §4, rule 11). rak200/workflow#30

Two related failures from the same step, both in `rak200/.github` alone:

- **`the scaffold tells repositories to call <name>.yml, and it does not exist here`** — or *it
  declares no `workflow_call` trigger*. The reusable workflows are whatever the seeds pin, and one
  of them was overwritten by a seed for four releases. See `LIFECYCLE.md` §4, rule 12.
- The check reads `uses:` directives, not the string. Prose that quotes a pin —
  `` `…/release.yml@<tag>` `` — is not a pin, and an earlier version of the step read it as one.

## 9. The branch is behind `master`

Required checks are **strict**: the gate must be green against the actual merge result, not
against a stale base.

```bash
gh pr update-branch          # or: git rebase master && git push --force-with-lease
```

## 10. The release was cut and the publish failed — TS repos

Symptom: the tag and the GitHub Release exist, `npm view <pkg> version` is behind them, and the
`publish` job in the release run is red. The release happened; only the registry does not know.

This is **not** §11's situation. Nothing is wrong with the released code, so a superseding
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

## 11. A bad release shipped

Tags are immutable (`LIFECYCLE.md` §3.8) — rollback does not exist. The path is **forward**: a new
version that supersedes the bad one, plus marking so nobody keeps resolving it meanwhile. If a
credential is involved, §4 comes first — rotate before anything here.

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
   (`LIFECYCLE.md` §3.9) — nothing extra to do. If the defect is a **vulnerability**, additionally
   publish a GitHub Security Advisory: that is the only channel that alerts dependents beyond this
   ecosystem.

## 12. A branch was renamed and its protection stayed behind

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
an existing repo and never part of scaffolding (`REPOSITORY.md` §1.1 step 4).

---
