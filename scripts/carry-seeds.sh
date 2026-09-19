#!/usr/bin/env bash
#
# carry-seeds.sh — carry a baseline release into consumer repositories.
#
#   scripts/carry-seeds.sh [--tag <tag>] [--push] --all [<repo-dir>...]
#   scripts/carry-seeds.sh [--tag <tag>] [--push] <repo-dir> [<repo-dir>...]
#
# This is the executable form of CONTINGENCIES.md section 7. Dependabot moves the
# `.rak200` gitlink and nothing else; the seeds the new tag changed have to travel with
# it, or conformance grades the repository against a scaffold it no longer pins and
# reddens every open pull request until someone copies files by hand.
#
# Measured 2026-09-03 over the 48 releases this baseline has cut: 31 of them (65%)
# changed at least one seed. At six consumers that is a manual carry most days.
#
# `scaffold/seeds.tsv` IS the list — never a hand-written one here, and never only the
# `exact` rows. The three check forms are not interchangeable and copying verbatim is
# wrong for two of them:
#
#   exact       byte-identical; copy it
#   prefix:N    the first N lines are the seed and the rest is per-repo history —
#               copying verbatim deletes that history
#   masked:RE   identical after RE is blanked on both sides; the masked text is the
#               repository's own (a pipeline pin), and copying verbatim would roll it
#               back to whatever the seed happens to name
#
# Every carry is verified before it is committed: the same comparison base.yml runs.
#
# It is safe to run while you are working in a consumer: the carry happens in a worktree
# of its own and the repository's checkout is never entered. See the comment on the
# worktree below for what that replaced and why.
#
# THE REACH IS THE ACCOUNT, NOT THE COMMAND LINE. Every run lists the repositories in
# the baseline's account whose .gitmodules names the baseline, and ends by naming each
# one it did not reach, with a non-zero exit. A consumer left off the line used to be
# one the run had nothing to say about, so it finished green — and a Dependabot bump
# reddened two hours later. `--all` carries every consumer with a clone beside this
# one. Directories stay valid input: they are the only way to reach a consumer outside
# the account, or one the token cannot see. rak200/workflow#147

set -euo pipefail

TAG=''
PUSH=0
ALL=0
REPOS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --tag)  TAG=$2; shift 2 ;;
    --push) PUSH=1; shift ;;
    --all)  ALL=1; shift ;;
    -*)     echo "unknown option: $1" >&2; exit 2 ;;
    *)      REPOS+=("$1"); shift ;;
  esac
done
[ ${#REPOS[@]} -gt 0 ] || [ "$ALL" = 1 ] \
  || { echo "usage: $0 [--tag <tag>] [--push] {--all | <repo-dir>...}" >&2; exit 2; }

slug_of() {   # owner/name from a GitHub remote URL, https or ssh
  sed -E 's#^.*github\.com[:/]##; s#\.git$##; s#/$##' <<<"$1"
}

BASELINE=$(cd "$(dirname "$0")/.." && pwd)
BASELINE_SLUG=$(slug_of "$(git -C "$BASELINE" remote get-url origin)")
git -C "$BASELINE" fetch --quiet --tags origin

# One GraphQL call, no local clone involved. A consumer is a repository whose default
# branch's .gitmodules names the baseline; a fork or an archived repository is not one.
consumers() {
  gh api graphql --paginate -F owner="${BASELINE_SLUG%%/*}" -f query='
    query($owner: String!, $endCursor: String) {
      repositoryOwner(login: $owner) {
        repositories(first: 100, after: $endCursor, isFork: false, ownerAffiliations: OWNER) {
          pageInfo { hasNextPage endCursor }
          nodes {
            nameWithOwner isArchived
            gitmodules: object(expression: "HEAD:.gitmodules") { ... on Blob { text } }
          }
        }
      }
    }' --jq '.data.repositoryOwner.repositories.nodes[] | select(.isArchived | not)
      | .nameWithOwner as $r | (.gitmodules.text // "")
      | [scan("(?m)^\\s*url\\s*=\\s*(\\S+)")] | .[] | "\($r) \(.[0])"' \
  | while read -r r url; do
      if [ "$(slug_of "$url")" = "$BASELINE_SLUG" ]; then echo "$r"; fi
    done | sort -u
}
# A failed listing is not an empty one: it leaves the reach unknown, and the run says
# so at the end rather than reporting that it missed nothing.
KNOWN=1
CONSUMERS=()
if listed=$(consumers); then
  mapfile -t CONSUMERS < <(printf '%s\n' "$listed" | grep . || true)
else
  KNOWN=0
  [ "$ALL" = 0 ] || { echo "cannot list the consumers of $BASELINE_SLUG — --all has nothing to carry" >&2; exit 1; }
fi

declare -A REACHED=()   # consumer slug -> the directory this run takes it from
for repo in "${REPOS[@]}"; do
  url=$(git -C "$repo" remote get-url origin 2>/dev/null) || continue
  REACHED[$(slug_of "$url")]=$repo
done

if [ "$ALL" = 1 ]; then
  # Every directory beside this clone, hidden ones included — `*/` does not match a
  # dotted name, and a clone of rak200/.github is dotted by default. A clone is known by
  # its origin, never by its directory name.
  parent=$(dirname "$BASELINE")
  declare -A WANTED=()
  for c in "${CONSUMERS[@]}"; do WANTED[$c]=1; done
  while IFS= read -r d; do
    [ -d "$d/.git" ] || continue
    url=$(git -C "$d" remote get-url origin 2>/dev/null) || continue
    s=$(slug_of "$url")
    [ -n "${WANTED[$s]:-}" ] || continue
    if [ -n "${REACHED[$s]:-}" ]; then
      [ "$(cd "${REACHED[$s]}" && pwd)" = "$d" ] \
        || echo "  $(basename "$d"): a second clone of $s — carrying ${REACHED[$s]} only"
      continue
    fi
    REACHED[$s]=$d
    REPOS+=("$d")
  done < <(find "$parent" -mindepth 1 -maxdepth 1 -type d | sort)
fi

if [ -z "$TAG" ]; then
  TAG=$(git -C "$BASELINE" tag --list --sort=-creatordate | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
fi
# The pin is a tag, never a bare commit — CONTINGENCIES.md section 7.
git -C "$BASELINE" rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
  || { echo "not a tag in $BASELINE: $TAG" >&2; exit 1; }
SHA=$(git -C "$BASELINE" rev-parse "refs/tags/$TAG^{commit}")
BRANCH="build/carry-the-baseline-to-${TAG//./-}"
echo "carrying $TAG ($(echo "$SHA" | cut -c1-7)) into ${#REPOS[@]} repositor$([ ${#REPOS[@]} = 1 ] && echo y || echo ies)"

variant_of() {   # the variant a repository declares, or its pipeline's default
  local ci=$1/.github/workflows/ci.yml v
  [ -f "$ci" ] || { echo ''; return; }
  v=$(sed -n '/^jobs:/,$p' "$ci" | sed -nE 's/^ +variant: *"?([a-z-]+)"?/\1/p' | head -1)
  if [ -n "$v" ]; then echo "$v"; return; fi
  case "$(sed -n '/^jobs:/,$p' "$ci" | sed -nE 's#.*workflows/([a-z-]+)\.yml@.*#\1#p' | head -1)" in
    php) echo php ;; js) echo ts ;; *) echo none ;;
  esac
}

rc=0
# `set -e` aborts mid-repository on any git failure, and an abandoned worktree is worse
# than the copy it replaced: it holds a lock on the branch and shows up in every later
# `git worktree list`. The trap fires on that path too. Found by running it — a submodule
# clone failed and left both the tree and the branch behind. rak200/workflow#144
WT='' WT_REPO=''
drop_worktree() {
  [ -n "$WT" ] || return 0
  git -C "$WT_REPO" worktree remove --force "$WT" 2>/dev/null || true
  rmdir "$(dirname "$WT")" 2>/dev/null || true
  WT='' WT_REPO=''
}
trap drop_worktree EXIT

for repo in "${REPOS[@]}"; do
  name=$(basename "$repo")
  [ -d "$repo/.git" ] || { echo "  $name: not a git repository — skipped"; rc=1; continue; }
  [ -f "$repo/.gitmodules" ] || { echo "  $name: no .rak200 submodule — skipped"; continue; }

  variant=$(variant_of "$repo")
  [ -n "$variant" ] || { echo "  $name: no ci.yml, cannot tell its variant — skipped"; rc=1; continue; }

  git -C "$repo" fetch --quiet origin

  # THE CARRY NEVER ENTERS THE REPOSITORY'S WORKING TREE. It happens in a worktree of
  # its own, so whatever the maintainer has checked out — a branch mid-review, a dirty
  # tree, a detached HEAD carrying commits — is neither moved nor read. The earlier
  # shape ran `checkout -B` in the tree itself, guarded only by `status --porcelain`:
  # that guard refuses a modified tracked file, and CANNOT SEE a file the repository
  # ignores, which `checkout` then overwrites silently and unrecoverably. Measured, on
  # a `.gitignore`d file with uncommitted content: status empty, checkout exit 0,
  # content replaced. The `.dist` overrides this convention tells every repository to
  # ignore are exactly the files that were in reach. rak200/workflow#144
  #
  # The submodule is isolated too — measured on git 2.47.3: a worktree keeps its own
  # submodule checkout, so moving `.rak200` to the tag here leaves the main tree's
  # pin where it was.
  wt=$(mktemp -d)/carry
  if ! git -C "$repo" worktree add --quiet -B "$BRANCH" "$wt" origin/master 2>/dev/null; then
    echo "  $name: cannot create the carry worktree — is $BRANCH checked out somewhere?"
    rmdir "$(dirname "$wt")" 2>/dev/null || true; rc=1; continue
  fi
  WT=$wt WT_REPO=$repo   # from here on the trap owns it

  if ! { git -C "$wt" submodule update --init --quiet .rak200 \
      && git -C "$wt/.rak200" fetch --quiet --tags origin \
      && git -C "$wt/.rak200" checkout --quiet "$SHA"; }; then
    echo "  $name: could not put .rak200 at $TAG — skipped"
    drop_worktree; git -C "$repo" branch -D --quiet "$BRANCH" 2>/dev/null || true
    rc=1; continue
  fi

  changed=$(SEEDS_ROOT="$wt/.rak200/scaffold" REPO="$wt" VARIANT="$variant" python3 - <<'PY'
import os, re, pathlib, shutil, sys

root = pathlib.Path(os.environ['SEEDS_ROOT'])
repo = pathlib.Path(os.environ['REPO'])
variant = os.environ['VARIANT']
changed = []

for line in (root / 'seeds.tsv').read_text().splitlines():
    if not line.strip() or line.lstrip().startswith('#'):
        continue
    parts = line.split('\t')
    if len(parts) != 4:
        continue
    v, form, seed, dest = parts
    if v not in ('all', variant):
        continue
    src, dst = root / seed, repo / dest
    if not src.exists():
        print(f'!! scaffold is missing {seed}', file=sys.stderr); continue

    if form == 'exact':
        new = src.read_text()
    elif form.startswith('prefix:'):
        n = int(form.split(':', 1)[1])
        head = src.read_text().splitlines(keepends=True)[:n]
        tail = dst.read_text().splitlines(keepends=True)[n:] if dst.exists() else []
        new = ''.join(head + tail)
    elif form.startswith('masked:'):
        pat = re.compile(form.split(':', 1)[1])
        if not dst.exists():
            new = src.read_text()
        else:
            # the masked text belongs to the repository — carry the seed around it
            mine = pat.findall(dst.read_text())
            theirs = pat.findall(src.read_text())
            if len(mine) != len(theirs):
                print(f'!! {dest}: {len(mine)} masked value(s) here against {len(theirs)} '
                      f'in the seed — carry it by hand', file=sys.stderr)
                continue
            it = iter(mine)
            new = pat.sub(lambda _: next(it), src.read_text())
    else:
        print(f'!! unknown check form {form!r} for {seed}', file=sys.stderr); continue

    if not dst.exists() or dst.read_text() != new:
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(new)
        shutil.copymode(src, dst)
        changed.append(dest)

print('\n'.join(changed))
PY
) || { echo "  $name: carry failed"; rc=1; continue; }

  # verify before committing: the comparison base.yml runs
  if ! SEEDS_ROOT="$wt/.rak200/scaffold" REPO="$wt" VARIANT="$variant" python3 - <<'PY'
import os, re, pathlib, sys
root = pathlib.Path(os.environ['SEEDS_ROOT']); repo = pathlib.Path(os.environ['REPO'])
variant = os.environ['VARIANT']; bad = 0; checked = 0
for line in (root / 'seeds.tsv').read_text().splitlines():
    if not line.strip() or line.lstrip().startswith('#'): continue
    parts = line.split('\t')
    if len(parts) != 4: continue
    v, form, seed, dest = parts
    if v not in ('all', variant): continue
    src, dst = root / seed, repo / dest
    if not src.exists() or not dst.exists():
        print(f'   {dest}: absent', file=sys.stderr); bad += 1; continue
    checked += 1
    a, b = src.read_text(), dst.read_text()
    if form.startswith('prefix:'):
        n = int(form.split(':', 1)[1])
        a, b = '\n'.join(a.split('\n')[:n]), '\n'.join(b.split('\n')[:n])
    elif form.startswith('masked:'):
        pat = re.compile(form.split(':', 1)[1])
        a, b = pat.sub('<masked>', a), pat.sub('<masked>', b)
    if a != b:
        print(f'   {dest}: still drifts', file=sys.stderr); bad += 1
sys.exit(1 if bad or checked == 0 else 0)
PY
  then
    echo "  $name: conformance still fails after the carry — nothing committed"
    drop_worktree; git -C "$repo" branch -D --quiet "$BRANCH" 2>/dev/null || true
    rc=1; continue
  fi

  mapfile -t files < <(printf '%s\n' $changed | grep -c . >/dev/null 2>&1 && printf '%s\n' $changed || true)
  git -C "$wt" add -- .rak200 "${files[@]}"
  if git -C "$wt" diff --cached --quiet; then
    echo "  $name ($variant): already at $TAG"
    drop_worktree
    git -C "$repo" branch -D --quiet "$BRANCH"
    continue
  fi
  n=$(printf '%s\n' $changed | grep -c . || true)
  if ! git -C "$wt" commit --quiet -m "build: carry the baseline to $TAG" \
    -m "Dependabot moves the \`.rak200\` gitlink alone. $TAG changed $n seed(s) this variant consumes, so conformance grades the repository against a scaffold it no longer pins until they travel with it." \
    -m "Carried by \`scripts/carry-seeds.sh\`, which reads \`seeds.tsv\` and honours each row's check form."
  then
    echo "  $name: the commit failed — nothing committed"
    drop_worktree; git -C "$repo" branch -D --quiet "$BRANCH" 2>/dev/null || true
    rc=1; continue
  fi
  echo "  $name ($variant): $TAG, $n seed(s) — $(git -C "$wt" rev-parse --short HEAD)"
  if [ "$PUSH" = 1 ]; then
    git -C "$wt" push --quiet -u origin "$BRANCH"
    gh pr create --repo "$(slug_of "$(git -C "$repo" remote get-url origin)")" \
      --base master --head "$BRANCH" --title "build: carry the baseline to $TAG" \
      --body "Dependabot moves the \`.rak200\` gitlink alone; \`$TAG\` changed $n seed(s) this variant consumes. Carried by \`scripts/carry-seeds.sh\`, verified against \`seeds.tsv\` before commit."
  fi
  drop_worktree
done

if [ "$KNOWN" = 0 ]; then
  echo "could not list the consumers of $BASELINE_SLUG — this run's reach is unknown"; rc=1
else
  missed=()
  for c in "${CONSUMERS[@]}"; do [ -n "${REACHED[$c]:-}" ] || missed+=("$c"); done
  if [ ${#missed[@]} -gt 0 ]; then
    if [ "$ALL" = 1 ]; then why="no clone in $(dirname "$BASELINE")"; else why='not named'; fi
    echo "NOT CARRIED ($why): ${missed[*]}"; rc=1
  fi
fi
exit $rc
