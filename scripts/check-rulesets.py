"""Compare live rulesets against their canonical declaration. See check-rulesets.sh."""
import json, sys

import pathlib
repo, branch_path, tag_path, live_dir = sys.argv[1:5]
live = [json.loads(f.read_text()) for f in sorted(pathlib.Path(live_dir).glob('*.json'))]
canon = {}
for p in (branch_path, tag_path):
    d = json.load(open(p))
    canon[d['name']] = d

fail = 0
def say(msg):
    global fail
    print(f"{repo}: {msg}")
    fail = 1

for name, want in canon.items():
    got = next((r for r in live if r.get('name') == name), None)
    if got is None:
        say(f"ruleset '{name}' is absent")
        continue
    if got.get('enforcement') != want.get('enforcement'):
        say(f"{name}: enforcement is {got.get('enforcement')!r}, declared {want.get('enforcement')!r}")
    key = lambda a: (a.get('actor_id'), a.get('actor_type'), a.get('bypass_mode'))
    wb = sorted(map(str, map(key, want.get('bypass_actors', []))))
    gb = sorted(map(str, map(key, got.get('bypass_actors', []))))
    if wb != gb:
        say(f"{name}: bypass_actors are {gb}, declared {wb}")
    wr = {r['type']: (r.get('parameters') or {}) for r in want.get('rules', [])}
    gr = {r['type']: (r.get('parameters') or {}) for r in got.get('rules', [])}
    for t in sorted(set(wr) - set(gr)):
        say(f"{name}: rule '{t}' is declared and absent")
    for t in sorted(set(gr) - set(wr)):
        say(f"{name}: rule '{t}' is applied and not declared")
    for t in sorted(set(wr) & set(gr)):
        for k, v in sorted(wr[t].items()):
            if k not in gr[t]:
                say(f"{name}/{t}: '{k}' is declared and absent")
            elif gr[t][k] != v:
                say(f"{name}/{t}: '{k}' is {json.dumps(gr[t][k])}, declared {json.dumps(v)}")
        for k in sorted(set(gr[t]) - set(wr[t])):
            say(f"{name}/{t}: '{k}' = {json.dumps(gr[t][k])} is applied and NOT DECLARED")

if not fail:
    print(f"{repo}: rulesets match the canonical declaration")
sys.exit(fail)
