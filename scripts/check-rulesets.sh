#!/usr/bin/env bash
# Compare a repository's LIVE rulesets against the canonical JSON in rak200/.github.
#
# The read-back this replaces asserted that two rulesets existed and were active. It could
# not see a parameter whose value differed, and it could not see one that was never
# declared — which is how three GitHub defaults came to sit on the rule that decides who
# may merge, unchosen and unreported.
#
# Measured 2026-08-24 on a throwaway ruleset: a POST of five `pull_request` parameters is
# stored as eight. The extras are injected on create AND re-injected on update, so a
# ruleset cannot be returned to its declaration by re-applying the file. The only lever is
# to declare the value you want, which does stick. That is why this compares in BOTH
# directions and why "applied and not declared" is a finding rather than noise: it is the
# only way a platform default ever announces itself here.
#
#   usage: check-rulesets.sh <owner/repo> [<owner/repo> ...]
set -uo pipefail

BASE_REPO=${BASE_REPO:-rak200/.github}
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

for r in branch tag; do
  gh api "repos/$BASE_REPO/contents/rulesets/$r.json" -H "Accept: application/vnd.github.raw" \
    > "$work/$r.json" || { echo "cannot fetch $r.json from $BASE_REPO" >&2; exit 2; }
done

status=0
for repo in "$@"; do
  if ! ids=$(gh api "repos/$repo/rulesets" --jq '.[].id' 2>/dev/null); then
    echo "$repo: cannot read rulesets"; status=1; continue
  fi
  rm -rf "$work/live"; mkdir -p "$work/live"
  for id in $ids; do
    gh api "repos/$repo/rulesets/$id" > "$work/live/$id.json"
  done
  python3 "$(dirname "$0")/check-rulesets.py" "$repo" "$work/branch.json" "$work/tag.json" "$work/live" || status=1
done
exit $status
