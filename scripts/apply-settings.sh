#!/usr/bin/env bash
#
# apply-settings.sh — write the platform state `settings.tsv` declares.
#
#   scripts/apply-settings.sh <repo>...        # rak200/<name>, or a bare <name>
#
# The writing half of the pair `audit-settings.sh` grades. Both read `settings.tsv` beside this
# file, which is the whole point: a hand-maintained list in the onboarding script and a second one
# in the prose is how `allow_auto_merge` could be decided, written down as decided, and left false
# in nine of ten repositories. rak200/workflow#78
#
# It is idempotent — every call writes a declared value, so running it against a repository that
# already matches changes nothing — and it is not an audit: it reports what it wrote, never what
# the repository then holds. Read it back with `audit-settings.sh`, which is what `new-repo.sh`
# step 8 does.

set -euo pipefail

[ $# -gt 0 ] || { echo "usage: $0 <repo>..." >&2; exit 64; }

MANIFEST="$(cd "$(dirname "$0")" && pwd)/settings.tsv"
[ -f "$MANIFEST" ] || { echo "no settings.tsv beside $0" >&2; exit 1; }

for repo in "$@"; do
  case "$repo" in */*) ;; *) repo="rak200/$repo" ;; esac

  while IFS= read -r object; do
    args=()
    while IFS=$'\t' read -r obj field kind value; do
      case "$obj" in ''|'#'*) continue ;; esac
      [ "$obj" = "$object" ] || continue
      # `-F` sends a typed literal and `-f` a string: `true` as a string is not a boolean to the
      # API, and `PR_TITLE` as a literal is not valid JSON. The manifest's `kind` column is what
      # decides, so a new row declares its own type rather than relying on this script to guess.
      case "$kind" in bool) args+=(-F "$field=$value") ;; *) args+=(-f "$field=$value") ;; esac
    done < "$MANIFEST"

    case "$object" in
      .) gh api -X PATCH "repos/$repo" "${args[@]}" >/dev/null ;;
      # The endpoint carries no body: making the call IS the enabling, and a DELETE is the
      # disabling. The manifest still declares the field, because `enabled` is what a GET returns
      # and a row declares what a GET must return.
      private-vulnerability-reporting) gh api -X PUT "repos/$repo/$object" >/dev/null ;;
      # A PUT REPLACES the whole object, so every field of it travels in one call or the ones left
      # out are rewritten to their defaults. Grouping by object is what makes that true here.
      *) gh api -X PUT "repos/$repo/$object" "${args[@]}" >/dev/null ;;
    esac
  done < <(grep -v '^#' "$MANIFEST" | awk -F'\t' 'NF>=4 {print $1}' | awk '!seen[$0]++')

  echo "  $repo: wrote $(grep -cv '^#' "$MANIFEST") declared setting(s)"
done
