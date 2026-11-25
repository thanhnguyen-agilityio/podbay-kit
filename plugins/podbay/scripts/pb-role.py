#!/usr/bin/env python3
"""SessionStart hook: add the role file for the current checkout to the session's context.

The role map is a Markdown file with lines like:  - `~/path/to/checkout` = role-name
Its path comes from the env var PB_ROLE_MAP, else from a line `role-map: <path>` in
<checkout>/.podbay/roles.md (resolved against the checkout; a map inside the checkout is
ignored, so a repo cannot bring its own "role"). The role file is <map folder>/<role-name>.md. The longest
matching checkout path wins. Any problem (no map, no match, no file, bad input) means
no output and exit 0: the hook never blocks or slows a session start.
"""
import json
import os
import re
import sys

CAP = 8000
LINE = re.compile(r"^- `([^`]+)`\s*=\s*([a-z0-9][a-z0-9-]*)\s*$")


def expand(p, base=None):
    p = os.path.expanduser(p.strip())
    if base and not os.path.isabs(p):
        p = os.path.join(base, p)
    return os.path.realpath(p)


def inside(path, folder):
    return path == folder or path.startswith(folder.rstrip(os.sep) + os.sep)


def map_path(cwd):
    env = os.environ.get("PB_ROLE_MAP", "").strip()
    if env:
        return expand(env)
    d = cwd
    while True:
        f = os.path.join(d, ".podbay", "roles.md")
        if os.path.isfile(f):
            for line in open(f, encoding="utf-8", errors="replace"):
                m = re.match(r"^\s*role-map:\s*(\S.*)$", line)
                if m:
                    mp = expand(m.group(1), d)
                    return None if inside(mp, os.path.realpath(d)) else mp
            return None
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def main():
    try:
        data = json.load(sys.stdin)
        cwd = os.path.realpath(data.get("cwd") or os.getcwd())
    except Exception:
        return
    mp = map_path(cwd)
    if not mp or not os.path.isfile(mp):
        return
    best, role = "", None
    for line in open(mp, encoding="utf-8", errors="replace"):
        m = LINE.match(line.rstrip("\n"))
        if not m:
            continue
        path = expand(m.group(1))
        if inside(cwd, path) and len(path) > len(best):
            best, role = path, m.group(2)
    if not role:
        return
    roles_dir = os.path.dirname(mp)
    rf = os.path.realpath(os.path.join(roles_dir, role + ".md"))
    if os.path.dirname(rf) != roles_dir or not os.path.isfile(rf):
        return
    with open(rf, encoding="utf-8", errors="replace") as fh:
        text = fh.read(CAP + 1)
    if len(text) > CAP:
        text = text[:CAP] + "\n[role file cut at %d characters]" % CAP
    ctx = "Your role in this checkout is \"%s\" (from the team's role map). Follow it:\n\n%s" % (role, text)
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ctx}}))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
