#!/usr/bin/env bash
#
# carry-seeds.sh — carry a baseline release into consumer repositories.
#
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

set -euo pipefail

TAG=''
PUSH=0
REPOS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --tag)  TAG=$2; shift 2 ;;
    --push) PUSH=1; shift ;;
    -*)     echo "unknown option: $1" >&2; exit 2 ;;
    *)      REPOS+=("$1"); shift ;;
  esac
done
[ ${#REPOS[@]} -gt 0 ] || { echo "usage: $0 [--tag <tag>] [--push] <repo-dir>..." >&2; exit 2; }

BASELINE=$(cd "$(dirname "$0")/.." && pwd)
git -C "$BASELINE" fetch --quiet --tags origin

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
for repo in "${REPOS[@]}"; do
  name=$(basename "$repo")
  [ -d "$repo/.git" ] || { echo "  $name: not a git repository — skipped"; rc=1; continue; }
  [ -f "$repo/.gitmodules" ] || { echo "  $name: no .rak200 submodule — skipped"; continue; }
  [ -z "$(git -C "$repo" status --porcelain)" ] || { echo "  $name: working tree is dirty — skipped"; rc=1; continue; }

  variant=$(variant_of "$repo")
  [ -n "$variant" ] || { echo "  $name: no ci.yml, cannot tell its variant — skipped"; rc=1; continue; }

  git -C "$repo" fetch --quiet origin
  git -C "$repo" checkout --quiet -B "$BRANCH" origin/master
  git -C "$repo" submodule update --init --quiet .rak200
  git -C "$repo" -C .rak200 fetch --quiet --tags origin 2>/dev/null || git -C "$repo/.rak200" fetch --quiet --tags origin
  git -C "$repo/.rak200" checkout --quiet "$SHA"

  changed=$(SEEDS_ROOT="$repo/.rak200/scaffold" REPO="$repo" VARIANT="$variant" python3 - <<'PY'
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
  if ! SEEDS_ROOT="$repo/.rak200/scaffold" REPO="$repo" VARIANT="$variant" python3 - <<'PY'
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
  then echo "  $name: conformance still fails after the carry — left uncommitted"; rc=1; continue; fi

  mapfile -t files < <(printf '%s\n' $changed | grep -c . >/dev/null 2>&1 && printf '%s\n' $changed || true)
  git -C "$repo" add -- .rak200 "${files[@]}"
  if git -C "$repo" diff --cached --quiet; then
    echo "  $name ($variant): already at $TAG"
    git -C "$repo" checkout --quiet -
    git -C "$repo" branch -D --quiet "$BRANCH"
    continue
  fi
  n=$(printf '%s\n' $changed | grep -c . || true)
  if ! git -C "$repo" commit --quiet -m "build: carry the baseline to $TAG" \
    -m "Dependabot moves the \`.rak200\` gitlink alone. $TAG changed $n seed(s) this variant consumes, so conformance grades the repository against a scaffold it no longer pins until they travel with it." \
    -m "Carried by \`scripts/carry-seeds.sh\`, which reads \`seeds.tsv\` and honours each row's check form."
  then
    echo "  $name: the commit failed — carried but uncommitted"; rc=1; continue
  fi
  echo "  $name ($variant): $TAG, $n seed(s) — $(git -C "$repo" rev-parse --short HEAD)"
  if [ "$PUSH" = 1 ]; then
    git -C "$repo" push --quiet -u origin "$BRANCH"
    gh pr create --repo "$(git -C "$repo" remote get-url origin | sed -E 's#.*github.com[:/]##; s#\.git$##')" \
      --base master --head "$BRANCH" --title "build: carry the baseline to $TAG" \
      --body "Dependabot moves the \`.rak200\` gitlink alone; \`$TAG\` changed $n seed(s) this variant consumes. Carried by \`scripts/carry-seeds.sh\`, verified against \`seeds.tsv\` before commit."
  fi
done
exit $rc
