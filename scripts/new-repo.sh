#!/usr/bin/env bash
#
# new-repo.sh — scaffold a conformant rak200 repository.
#
#   scripts/new-repo.sh <name> <variant: php|php-config|ts|ts-config|none|github> <conventions-tag> ["description"]
#
# This is the executable form of REPOSITORY.md section 1.1. The order below is not
# stylistic: archiving aside, two steps in it are load-bearing and were measured.
#
#   * The repository is created EMPTY. --add-readme / --license / --gitignore each force
#     an initial commit on the account's configured default branch name, and the last two
#     write GitHub's templates rather than the seeds.
#   * master is PUSHED FIRST, because the first branch pushed into an empty repository
#     becomes its default. Nothing else here sets it.
#   * Rulesets are applied AFTER that push: the pull_request rule would otherwise reject
#     the very push that establishes the default branch.
#
# Every write is followed by a read-back. A response code is not evidence.

set -euo pipefail

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }
[ $# -ge 3 ] || usage

NAME=$1
VARIANT=$2
PIN=$3
DESC=${4:-"rak200 ecosystem project"}
OWNER=rak200
REPO="$OWNER/$NAME"
WORKFLOW_URL="https://github.com/rak200/workflow.git"
BASE_REPO="rak200/.github"

case "$VARIANT" in php|php-config|ts|ts-config|none|github) ;; *) echo "unknown variant: $VARIANT" >&2; exit 64 ;; esac

say() { printf '\n\033[1m>>> %s\033[0m\n' "$*"; }
die() { printf '\n\033[31m!!! %s\033[0m\n' "$*" >&2; exit 1; }

say "1/9  create $REPO, empty"
gh repo create "$REPO" --public --description "$DESC" >/dev/null

say "2/9  build the tree locally on master"
work=$(mktemp -d)
cd "$work"
git init -b master -q

say "3/9  pin the conventions at $PIN and copy the seeds out of them"
git submodule add -q "$WORKFLOW_URL" .rak200
git -C .rak200 checkout -q "$PIN"
[ -f .rak200/scaffold/seeds.tsv ] || die "$PIN has no scaffold/seeds.tsv"

mkdir -p .github/workflows .githooks
while IFS=$'\t' read -r v _form seed dest; do
  case "$v" in ''|'#'*) continue ;; esac
  [ "$v" = all ] || [ "$v" = "$VARIANT" ] || continue
  mkdir -p "$(dirname "$dest")"
  cp -a ".rak200/scaffold/$seed" "$dest"
done < .rak200/scaffold/seeds.tsv
chmod +x .githooks/pre-push
# The Layer 2 import is language-specific, so the template is too — and a `-config`
# variant has its own, because it IS the standard rather than a consumer of it. Neither
# Composer nor npm installs a package into its own tree, so the vendor/ or node_modules/
# path every consumer imports never exists there; its Layer 2 is the CONVENTIONS.md at
# its root. That import resolves to nothing without an error, which is how both -config
# repositories went without one of their two layers. rak200/workflow#86
case "$VARIANT" in
  php|php-config|ts|ts-config) template=$VARIANT ;;
  *)                           template=none ;;
esac
cp -a ".rak200/scaffold/templates/CLAUDE.$template.md" CLAUDE.md
# The Latest tag badge is mandatory in every README.md, and as a live badge no check asks
# for it — so it is written here, not left to whoever remembers. rak200/workflow#181
printf '# %s\n\n[![Latest tag](https://img.shields.io/github/v/tag/%s?sort=semver)](https://github.com/%s/tags)\n\n%s\n' \
  "$NAME" "$REPO" "$REPO" "$DESC" > README.md
# Driven by what the seeds actually laid down, not by the variant's name: every variant
# now carries release-please-config.json, and the two pieces of per-repo release state
# are bootstrapped from what it says rather than from $VARIANT.
if [ -f release-please-config.json ]; then
  printf '{ ".": "0.0.0" }\n' > .release-please-manifest.json
  # `release-type: simple` keeps the version in version.txt, because a prose repository
  # has no package manifest to keep it in. release-please owns the file from here on —
  # it is derived state that happens to be one line long, not a number anyone types.
  if grep -q '"release-type": "simple"' release-please-config.json; then
    printf '0.0.0\n' > version.txt
  fi
fi

say "4/9  first commit, and push master FIRST — this is what sets the default branch"
git add -A
git commit -q -m "feat: scaffold the repository from the rak200 baseline"
git remote add origin "https://github.com/$REPO.git"
git push -q -u origin master

branch=$(gh api "repos/$REPO" --jq '.default_branch')
[ "$branch" = master ] || die "default branch read back as '$branch', not master — delete the repo and start again; a rename leaves name-targeted rules behind"

say "5/9  platform settings, from the pinned scripts/settings.tsv"
# THE LIST IS NOT THIS SCRIPT'S. `.rak200/scripts/settings.tsv` declares the platform state a
# rak200 repository is configured to, and step 8 reads it back through that same file — one list,
# applied and graded, which is what `scaffold/seeds.tsv` is for files. A setting decided and never
# written here used to appear in NEITHER half of the run, so the read-back reported a clean pass
# over an incomplete configuration: `allow_auto_merge` was false in nine of ten repositories until
# `gh pr merge --auto` was finally run and the platform refused it. rak200/workflow#78
#
# It comes from the pin rather than from the operator's checkout, for the reason the seeds do: a
# repository is onboarded to a tag, not to whatever happens to be on someone's master.
[ -f .rak200/scripts/settings.tsv ] || die "$PIN has no scripts/settings.tsv"
.rak200/scripts/apply-settings.sh "$REPO"

say "6/9  canonical labels, additively — then GitHub's stock set, deleted once"
python - "$REPO" <<'PY'
import json, re, subprocess, sys
repo = sys.argv[1]
raw = open(".rak200/labels.yml", encoding="utf-8").read()
have = json.loads(subprocess.run(["gh","api",f"repos/{repo}/labels","--paginate","--jq","[.[].name]"],
                                 capture_output=True, text=True).stdout or "[]")
cur = {}
def flush():
    if not cur.get("name") or cur["name"] in have:
        return
    subprocess.run(["gh","api","-X","POST",f"repos/{repo}/labels",
                    "-f",f"name={cur['name']}","-f",f"color={cur.get('color','ededed')}",
                    "-f",f"description={cur.get('description','')}"], capture_output=True)
    print(f"    + {cur['name']}")
for line in raw.splitlines():
    if m := re.match(r'\s*-\s*name:\s*"?([^"]+?)"?\s*$', line):
        flush(); cur.clear(); cur["name"] = m.group(1)
    elif m := re.match(r'\s*color:\s*"?([^"]+?)"?\s*$', line):
        cur["color"] = m.group(1)
    elif m := re.match(r'\s*description:\s*"?([^"]+?)"?\s*$', line):
        cur["description"] = m.group(1)
flush()
PY
# One-shot, and only ever here: in steady state the only things producing a label outside
# the canonical set are automations, whose labels must never be deleted.
for stock in bug documentation duplicate enhancement "good first issue" "help wanted" invalid question wontfix; do
  gh api -X DELETE "repos/$REPO/labels/${stock// /%20}" >/dev/null 2>&1 || true
done
# bug / duplicate / wontfix are canonical too — recreate the three the sweep just removed
python - "$REPO" <<'PY'
import subprocess, sys
repo = sys.argv[1]
for name, color, desc in [("bug","d73a4a","Something behaves incorrectly"),
                          ("duplicate","cfd3d7","Already reported elsewhere"),
                          ("wontfix","ffffff","Deliberately not pursued")]:
    subprocess.run(["gh","api","-X","POST",f"repos/{repo}/labels","-f",f"name={name}",
                    "-f",f"color={color}","-f",f"description={desc}"], capture_output=True)
PY

say "7/9  rulesets, from the canonical JSON in $BASE_REPO"
for r in branch tag; do
  gh api "repos/$BASE_REPO/contents/rulesets/$r.json" -H "Accept: application/vnd.github.raw" > "$work/$r.json"
  gh api -X POST "repos/$REPO/rulesets" --input "$work/$r.json" >/dev/null
done

say "8/9  read back every write — rule 9"
# The settings and the presence of the rulesets are read back by the auditor, against the very
# manifest step 5 wrote from: one comparison, so the read-back cannot drift from the write the way
# two hand-maintained lists did. It exits non-zero on any divergence, and `set -e` ends the run
# there. rak200/workflow#78
.rak200/scripts/audit-settings.sh "$NAME"
# Not the auditor's, and read here: the default branch is established by the first push rather
# than written, and the rulesets' bypass mode is a field the auditor deliberately does not compare.
gh api "repos/$REPO" --jq '{default_branch}'
gh api "repos/$REPO/rulesets" --jq '[.[] | {name,target,enforcement}]'
gh api "repos/$REPO/rulesets" --jq '.[].id' | while read -r id; do
  gh api "repos/$REPO/rulesets/$id" --jq '{name, bypass_mode: (.bypass_actors[0].bypass_mode // "NONE")}'
done
gh api "repos/$REPO/labels" --jq '[.[].name] | sort | join(", ")'
git submodule status

say "9/9  what is left, and only you can do it"
cat <<EOF

  Per clone (local git config — no platform can enforce it):

      cd <your clone>
      git config core.hooksPath .githooks
      git config blame.ignoreRevsFile .git-blame-ignore-revs
      # install gitleaks, or the pre-push hook refuses every push

  Bump the pipeline pins before the first PR. They came from the seed, which is NOT kept
  current — nothing grades it (the pin line is masked) and Dependabot never sees it (it
  reads .github/workflows/, and the seeds are not there). Skip this and the first PR
  fails 'The pinned pipeline is not obsolete'. See CONTINGENCIES.md 8, REPOSITORY.md 1.1.

      latest=\$(gh api repos/rak200/.github/tags --jq '.[0].name')
      sed -i -E "s#(uses: rak200/\.github/\.github/workflows/[a-z0-9-]+\.yml)@[0-9.]+#\\1@\$latest#" \\
        .github/workflows/*.yml

  Then fire a canary before calling the repository conformant: open a PR that drifts one
  seed on purpose, confirm 'gate' is FAILURE and the merge is refused, and close it.
  A gate that has never failed has never been tested.
EOF

case "$VARIANT" in ts|ts-config)
cat <<EOF
  This is a TypeScript repo, so one more thing stands between it and a usable release —
  without it every release stops at the git tag and the package installs for nobody:

      1. add  "publishConfig": { "access": "public" }  to package.json
      2. publish the first version by hand (the package must exist to be configured)
      3. npmjs.com -> Packages -> <pkg> -> Settings -> Trusted publishing:
         this repo, workflow filename  release.yml  — the CALLER, not npm-publish.yml.
         npm validates the workflow that STARTED the run, not the one that publishes.

  Every version after the first publishes itself, over OIDC, with no stored token.
EOF
;;
esac

cat <<EOF

  Working tree: $work
EOF
