#!/usr/bin/env bash
#
# audit-settings.sh — compare the account's platform state with scripts/settings.tsv.
#
#   scripts/audit-settings.sh              # every repository in the account
#   scripts/audit-settings.sh <name>...    # only these
#
# This asks the question a read-back cannot: not *did the write I made take effect*, which
# non-negotiable 1 already covers, but *is there a write nobody made*. The two settings that
# motivated this file were both of the second kind, and both were found by hand — one by using
# the estate until the platform refused a documented command, the other by reading
# `CONVENTIONS.md` §Security against the API. rak200/workflow#78
#
# IT IS A COMMAND SOMEONE RUNS, NOT A GATE. Reading these objects needs admin scope, and nothing
# repo-local should hold that credential — the same reason `LIFECYCLE.md` §3.9 gives for rulesets
# having no scheduled audit. A red pull request is not available here; a maintainer running this
# is.
#
# WHAT IT DOES NOT REACH. Labels and the contents of rulesets, which have canonical sources of
# their own (`labels.yml` here, `rulesets/*.json` in rak200/.github) — the rulesets are checked for
# presence and enforcement, never field by field. Anything set at the account level rather than the
# repository's. And a repository the token cannot see, which is the one failure it reports as a
# repository rather than as a setting.

set -euo pipefail

OWNER=rak200

MANIFEST="$(cd "$(dirname "$0")" && pwd)/settings.tsv"
[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST" >&2; exit 1; }

if [ $# -gt 0 ]; then
  REPOS=$(printf '%s\n' "$@")
else
  # Non-archived and not a fork: the estate's own repositories, private ones included, which is
  # where an unwritten setting hides — a public repository is at least read by strangers.
  REPOS=$(gh repo list "$OWNER" --no-archived --limit 200 \
    --json name,isFork --jq '.[] | select(.isFork | not) | .name' | sort)
fi

MANIFEST="$MANIFEST" OWNER="$OWNER" REPOS="$REPOS" python3 - <<'PY'
import json
import os
import subprocess
import sys

owner = os.environ['OWNER']
repos = [r for r in os.environ['REPOS'].split('\n') if r.strip()]

rows = []
for line in open(os.environ['MANIFEST'], encoding='utf-8'):
    if line.startswith('#') or not line.strip():
        continue
    parts = line.rstrip('\n').split('\t')
    if len(parts) >= 4:
        rows.append(tuple(parts[:4]))

objects = []
for obj, *_ in rows:
    if obj not in objects:
        objects.append(obj)


def api(path):
    """The object, or None when it cannot be read — which is itself a finding."""
    p = subprocess.run(['gh', 'api', path], capture_output=True, text=True)
    if p.returncode != 0:
        return None
    try:
        return json.loads(p.stdout)
    except json.JSONDecodeError:
        return None


def declared(value, kind):
    return value if kind == 'string' else value.lower()


def observed(body, field, kind):
    # An absent field is the shape this whole file exists for: it does not come back `false`,
    # it does not come back at all, and nothing about the response says a decision was skipped.
    if field not in body:
        return '«absent»'
    got = body[field]
    return got if kind == 'string' else str(got).lower()


findings = 0
unreadable = []

for name in repos:
    lines, notes = [], []
    repo_object = api(f'repos/{owner}/{name}')
    private = bool(repo_object and repo_object.get('private'))
    onboarded = api(f'repos/{owner}/{name}/contents/.rak200') is not None

    for obj in objects:
        # Private vulnerability reporting is a public-repository feature, so the endpoint 404s on
        # a private one. Reported as a note rather than a divergence, and reported rather than
        # skipped quietly: a reader cannot tell a silent skip from a passing check.
        if obj == 'private-vulnerability-reporting' and private:
            notes.append(f'    {obj}: not applicable to a private repository')
            continue
        path = f'repos/{owner}/{name}' + ('' if obj == '.' else f'/{obj}')
        body = api(path)
        if body is None:
            lines.append(f'    {obj}: cannot be read')
            continue
        for row_obj, field, kind, value in rows:
            if row_obj != obj:
                continue
            got, want = observed(body, field, kind), declared(value, kind)
            if got != want:
                lines.append(f'    {field}: {got}, declared {want}')

    rulesets = api(f'repos/{owner}/{name}/rulesets')
    if rulesets is None:
        lines.append('    rulesets: cannot be read')
    else:
        for target in ('branch', 'tag'):
            match = [r for r in rulesets if r.get('target') == target]
            if not match:
                lines.append(f'    rulesets: no {target} ruleset')
            elif any(r.get('enforcement') != 'active' for r in match):
                lines.append(f'    rulesets: the {target} ruleset is not active')

    if lines or notes:
        # Whether the repository was ever onboarded is context, never an excuse: the settings
        # below are the account's, and a repository outside the baseline is a repository the
        # decision never reached rather than one it does not bind.
        print(f'  {name}' + ('' if onboarded else '  (no .rak200 — never onboarded)'))
        print('\n'.join(lines + notes))
        findings += len(lines)
        if any(line.endswith('cannot be read') for line in lines):
            unreadable.append(name)

print()
print(f'{len(repos)} repositor{"y" if len(repos) == 1 else "ies"} read against '
      f'{len(rows)} declared setting(s): {findings or "no"} divergence(s)')
if unreadable:
    print(f'unreadable, so unaudited rather than clean: {", ".join(sorted(set(unreadable)))}')
sys.exit(1 if findings else 0)
PY
