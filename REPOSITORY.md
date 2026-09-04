# The life of a repository

Onboarding a repository into the estate, reconfiguring one, and retiring one — read twice a year if
that, which is why it is not in `LIFECYCLE.md`. That page carries the daily cycle;
`CONTINGENCIES.md` carries what to do when a step goes wrong. How a rule here is written is
`CONVENTIONS.md` §How to read a rule here. rak200/workflow#126

## 1. Onboarding a repository

### 1.1 A new repository

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
nothing in the release path touches it (`LIFECYCLE.md` §3.8). It appears here as a checklist item
precisely because it cannot appear as a gate: six of ten repositories had gone without it, every
one of them onboarded after the convention was written, and no mechanism in this document could
have noticed.

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

# `cp -a` carries the seed's mode, but git records it only where the filesystem has
# the bit for it to read — NTFS has none, so a repository scaffolded on Windows lands
# a 100644 hook and git skips it in silence, no error, push succeeds. Set it in the
# INDEX, which does not depend on the filesystem or on `core.fileMode`. `chmod` here
# is the wrong instrument for the same reason: on a clone with `core.fileMode=false`
# it changes the disk and registers nothing.
git add .githooks/pre-push
git update-index --chmod=+x .githooks/pre-push

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
The language pipelines take a `variant:` input for exactly this: a `-config` package must be
graded against its own seed set, which *exports* the tool configs the library variants hide.
rak200/workflow#28

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
once (`CONTINGENCIES.md` §7, `CONTINGENCIES.md` §8). And nothing updates it either — Dependabot's
`github-actions` ecosystem reads `<directory>/.github/workflows/`, and the seeds live at
`scaffold/<variant>/ci.yml`, outside it. The seed's value is therefore whatever it was the last
time a human changed it. rak200/workflow#98

```bash
latest=$(gh api repos/rak200/.github/tags --jq '.[0].name')
sed -i -E "s#(uses: rak200/\.github/\.github/workflows/[a-z0-9-]+\.yml)@[0-9.]+#\1@$latest#" \
  .github/workflows/*.yml
grep -hoE 'workflows/[a-z0-9-]+\.yml@[0-9.]+' .github/workflows/*.yml   # read it back
```

Skip it and the repository's **first pull request fails `CONTINGENCIES.md` §8** — for a line its
author did not write. Dependabot would clear it on the weekly `github-actions` pass, so the cost
of forgetting is bounded; the cost of remembering is one command.

**Left as a step rather than fixed in the scaffold, knowingly.** The structural fixes were designed
and rejected as disproportionate to one red pull request in a repository that self-heals within a
week. RFC 0017 `E.28`

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
from step 1, because a rename leaves name-targeted rules pointing at the old name
(`CONTINGENCIES.md` §12).

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

**`allow_auto_merge` is not optional.** It defaults to off, and `--auto` — the merge command
`LIFECYCLE.md` §3.6 and `LIFECYCLE.md` §6 both prescribe — needs it: `gh pr merge --auto` enables
auto-merge through a mutation the platform refuses outright when the repository has the feature
disabled.

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
*branch's* message rather than the PR title, which breaks `release-please` silently
(`CONTINGENCIES.md` §5). `can_approve_pull_request_reviews` is `release-please`'s prerequisite —
without it the Release PR is never opened, and the failure arrives late and dirty.

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
# read it back by COMPARISON — the script lives beside the JSON, in rak200/.github
gh api repos/rak200/.github/contents/scripts/check-rulesets.sh -H "Accept: application/vnd.github.raw" \
  > /tmp/check-rulesets.sh && chmod +x /tmp/check-rulesets.sh
gh api repos/rak200/.github/contents/scripts/check-rulesets.py -H "Accept: application/vnd.github.raw" \
  > /tmp/check-rulesets.py
/tmp/check-rulesets.sh rak200/<repo>
```

**The read-back is a comparison, not a listing.** Printing `{name,target,enforcement}` proves two
rulesets exist and nothing about what they contain, which is rule 9 satisfied in form and not in
substance. `check-rulesets.sh` diffs the live rulesets against the canonical JSON in both
directions: a declared parameter whose value differs, and **a parameter GitHub applied that the
file never declared.** rak200/workflow#101

That second direction is the one that earns its keep. Measured 2026-08-24 on a throwaway ruleset:
a `POST` of five `pull_request` parameters is stored as **eight**, and a `PUT` of the same five
re-injects the extras rather than removing them — **a ruleset cannot be returned to its declaration
by re-applying the file.** Four parameters were arriving undeclared on the rule that decides who
may merge, identically across all six onboarded repositories, and were found by accident rather
than by any read-back. They are named in the canonical JSON now, so the next platform default shows
up as the only undeclared key instead of hiding among them.

**It lives in `rak200/.github`, beside the `rulesets/*.json` it grades**, so the declaration and the
check ship as one thing — and this repository stays prose. The same script is the estate sweep: it
takes any number of repositories, and it is deliberately **not** a required check. A platform
default arrives everywhere at once, and a gate that reddens every repository simultaneously for
something absent from the pull request is the slow, noisy check people learn to route around
(`CONTINGENCIES.md` §7's argument, one layer up).

The JSON is the canonical copy in [`rak200/.github`](https://github.com/rak200/.github/tree/master/rulesets) — clone it or fetch the two files; they are versioned there, not here. Order matters: the branch ruleset's
`pull_request` rule would reject the very push in step 4 that establishes the default branch.

**The branch ruleset** carries a `bypass_actors` entry for the repository admin, in `bypass_mode:
pull_request`. It is there for the blame-registration PR and as a safety net. The mode is the
narrow part
and must be read back as such: `always` would permit a **direct push** to `master`, which this
design does not want. Within the PR path the entry is wide — it exempts every API call the actor
makes — which is why merges go through `gh pr merge` (rule 10) and why an `--admin` merge can cross
a red required check. rak200/workflow#8

**The tag ruleset carries no bypass at all**, and not by choice: GitHub rejects the narrow mode on
a tag ruleset outright — *"bypass mode must not be 'PULL_REQUEST' for tag rulesets"* — which left
`always` or nothing. Nothing is correct here. Its rules block **moving and deleting** a tag, never
creating one, so `release-please` cuts releases untouched, and moving a released tag is exactly
what a bad release procedure does. rak200/workflow#8

**8. Release bootstrap.** **Every variant releases** — including the prose ones. A repository
whose tags are typed by hand is a repository whose version is typed, which the whole versioning
policy exists to prevent, and it matters most in the baseline repositories because their tags are
what every other repository pins. It also matters now in a way it did not before: submodule bumps
arrive daily (`LIFECYCLE.md` §3.9), and a bump PR from a repository with no `CHANGELOG.md` says
nothing about what it changes.

A greenfield repo seeds `.release-please-manifest.json` at `{".": "0.0.0"}` — plus `version.txt`
where the config says `release-type: simple`, since a repository with no package manifest needs
somewhere for the version to live. `release-please` owns that file from the first release on; it
is derived state that happens to be one line long, not a number anyone types. `CHANGELOG.md` is
never seeded: the first Release PR writes it.

The seeded `release-please-config.json` does the rest — but only because it
names three settings that would otherwise default against this design, each found the hard way: the
first two on the first release ever cut here, the third twenty-five days later:

- `initial-version: "0.1.0"`. `bump-minor-pre-major` governs bumps *from* a version and says
  nothing about the first one, which release-please defaults to **`1.0.0`**. Without this line
  every new repository is handed the unchosen `1.0.0` that the versioning policy exists to prevent.
- `include-component-in-tag: false`. `include-v-in-tag: false` controls the `v` and nothing else;
  the component defaults to **on** and prefixes the package name, so the first tag comes out
  `mypackage-0.0.0`.
- `changelog-sections`. Undeclared, the release type picks the list, and the release types do not
  agree: `php` ships one where `chore` is **un-hidden**, so a `chore:` commit cuts a release there
  and nowhere else. Two versions were published for a file-mode change before anyone looked.

None of the three is visible in a diff of a well-formed version. **Read the first Release PR before
merging it** — its title is the only place the first two show, and for the third the tell is the
Release PR *existing at all*, for a commit that was never meant to publish.

An existing repo is a different procedure — §1.2.

**8b. Registry publishing — TS repos only, and only the first time.** Until this is done the
release ends at the git tag and the package is installable by nobody. On npmjs.com, *Packages →
the package → Settings → Trusted publishing*: register this repository and the workflow filename
**`release.yml`** — the caller, never `npm-publish.yml`, because npm validates the workflow that
started the run. The package must exist before it can be configured, so publish the first version
by hand: rak200/workflow#15

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
divergence on installation. rak200/workflow#93

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

### 1.2 An existing repository

Same procedure minus steps **1, 2 and 4** (the repository, its tree and its default branch already
exist). Verify the dist surface (`git archive HEAD | tar -t` against the `export-ignore` list).

> **Step 3 is not skipped**, and this line used to say `1–4`, which read as skipping it. Step 3 is
> where the submodule pin, the seed copy loop and the pipeline-pin bump live — an existing
> repository needs all three, and the cautions further down this section are instructions *for
> performing it*: *"`release-please-config.json` is a seed and arrives with step 3 already
> correct"*, *"the copy loop in step 3 destroys a `prefix:N` seed"*. The section contradicted its
> own opening line. It was a range that stopped being true when `E.28` moved the pipeline-pin bump
> into step 3, and nothing re-read the body — **a cross-reference is a claim about another section,
> and nothing grades it.**

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
rak200/workflow#8

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

### 1.3 A repository that needs different pipeline inputs

**It needs a variant, not an input.** The caller `scaffold/<variant>/ci.yml` is a seed graded
`masked:` on its version pin alone — the whole file is compared, so editing its `with:` block in a
repository fails `Seeded files match the pinned scaffold`, which is a `gate` row and blocks the
merge. That is deliberate: the inputs describe **a kind of repository**, and a kind of repository
is what a variant is. `ts-config` is the worked example — it passes `browser: false` where `ts`
leaves it on, because a package of configuration has no DOM. rak200/workflow#110

An input on `php.yml`/`js.yml` therefore exists only when some variant passes it. Three did not and
were removed on 2026-08-30 (`runs-on`, `extensions`, `mutation`); see RFC 0017 `E.38`.

**Before adding a variant, check whether the difference is per-repo state instead.** Most are, and
this is the cheaper answer by a wide margin. The tool configs are **not seeds** —
`infection.json5.dist`, `phpunit.xml`, `phpstan.neon.dist` and `.php-cs-fixer.dist.php` are all
per-repo, as are `.coverage-floor` and `.release-please-manifest.json`. So: rak200/workflow#110

- **a repository that has not reached the mutation floor sets its own** — `minCoveredMsi` in its
  `infection.json5.dist`, entering at what it has and ratcheting up, exactly as `.coverage-floor`
  works. It does **not** get a variant, and it does **not** get its mutation step switched off:
  `LIFECYCLE.md` §6's vocabulary requires the `mutation` verb of every repository unconditionally,
  so a repository that cannot run it is a repository that cannot be conformant. Declare the verb,
  set the floor you can hold, raise it. - **a repository needing an extra PHP extension** is the
  case with no per-repo route, because `setup-php` runs before any repository file is read. Today
  the literal is `mbstring, bcmath`, the union of what this estate's manifests declare. A
  repository needing more is a variant, and it is the only one of the three removed inputs whose
  case is not already answered.

**Adding a variant, if it is genuinely one.** A variant is a directory under `scaffold/` and a set
of rows in `scaffold/seeds.tsv`. It does **not** have to duplicate the seeds it shares: a row names
the seed *path*, so a new variant reuses another's files by pointing at them —
`php-config` does exactly this for `.gitignore`, `dependabot.yml` and `release-please-config.json`,
carrying its own `ci.yml` and `.gitattributes` only. Copy that shape: one new `ci.yml`, one new
`.gitattributes` if the dist surface differs, and rows pointing at `php/` for everything else.
rak200/workflow#110

---

## 2. Retiring a repository

**Archive. Never delete.** Deleting breaks every pinned consumer, every submodule gitlink and
every tag reference at once, and nothing about it is reversible. Archiving breaks none of them:
an archived repository still **clones**, still serves as a **submodule source**, and its **tags
still resolve**, so consumers are untouched.

**The order below is not a suggestion.** Archiving makes the repository **read-only** — `git push`
answers `403 This repository was archived so it is read-only`, and so does the issues API. Anything
you meant to write afterwards cannot be written. Everything lands first; the flag is last.

### 2.1 Retiring it for good

1. **Decide the replacement**, if there is one. It goes in the marker in step 2 and in the README
   notice.
2. **One final PR**, through the normal flow, carrying all of:
   - `"abandoned": "<replacement>"` (or `true`) in `composer.json` — see 9.3;
   - a notice at the top of `README.md` saying it is retired, since when, and what to use instead;
   - a `CHANGELOG.md` entry;
   - an emptied `ROADMAP.md` (the pruning check has nothing to say about a repository with no
     roadmap, but a stale one outlives the project);
   - `SECURITY.md` stating that **no version is supported**.
3. **Cut a final release** through the standard path (`LIFECYCLE.md` §3.8). This is the step
   people skip: the marker only reaches consumers if it ships **in a tag they resolve**. 4.
   **Close open issues and pull requests deliberately.** Archiving freezes them exactly as they
   are — an open PR on an archived repository is a question nobody can ever answer. 5. **Remove
   the dependency from its consumers** — bump them off it or drop it. Every consumer in this
   ecosystem is one you control: none of these libraries is published to a public registry, and
   they resolve as VCS dependencies from repositories in this account. That is also why there is
   **no maintenance branch** for an old major anywhere here — the consumer is upgraded instead.
   Nine majors have shipped across the estate and not one `release/x.y` has ever existed. What
   happened instead, and nothing recorded it: consumers were left frozen — `sql-builder` requiring
   `utils ^1.0.0` while `utils` was at `4.5.0`, `devr` requiring `caster ^1.0.0` while `caster`
   was at `3.x`. The old major was never patched **and** the consumer was never upgraded; the
   version simply froze. A maintenance branch would not have prevented that. 6. **Archive, then
   read it back.**

```bash
gh api -X PATCH repos/rak200/<repo> -F archived=true
gh api repos/rak200/<repo> --jq '.archived'      # expect: true
```

> **Do not read the workflow list to confirm it.** Workflows on an archived repository still report
> `state: active` although nothing can trigger them. The authoritative field is `archived` on the
> repository itself — read back, per rule 9.

### 2.2 Undoing it

```bash
gh api -X PATCH repos/rak200/<repo> -F archived=false
```

Write access returns immediately (verified). Archiving is a reversible decision, which is the
second reason it is the only one on offer.

### 2.3 Deprecating without retiring

A library that is discouraged but still accepts fixes takes the marker alone — step 2's
`"abandoned"` key, released as a normal patch. **It reaches consumers without a registry:** under
this ecosystem's VCS resolution, a consuming `composer update` prints

```
Package rak200/<repo> is abandoned, you should avoid using it. Use <replacement> instead.
```

so the signal does not wait on publication. Archiving is what makes the state permanent; the marker
is what makes it visible.
