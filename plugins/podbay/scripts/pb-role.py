#!/usr/bin/env python3
"""SessionStart hook: add the role file for the current checkout to the session's context.

The role map is a Markdown file with lines like:  - `~/path/to/checkout` = role-name
Its path comes from the env var PB_ROLE_MAP, else from a line `role-map: <path>` in
<checkout>/.podbay/roles.md (an absolute or ~ path only; a map inside the git checkout is ignored, so a repo
cannot bring its own "role"). Map entries must be absolute or start with ~. The role file is <map folder>/<role-name>.md. The longest
matching checkout path wins. A line may end in ` @<machine>`: it then applies only on the machine
that `podbay-dev setup` names (env PB_MACHINE overrides), and wins over a plain line for the same path.
Unknown machine: qualified lines are ignored, never guessed. Any problem (no map, no match, no file, bad input) means
no output and exit 0: the hook never blocks or slows a session start.
"""
import json
import os
import re
import subprocess
import sys

CAP = 8000
LINE = re.compile(r"^- `([^`]+)`\s*=\s*([a-z0-9][a-z0-9-]*)(?:\s+@([A-Za-z0-9][A-Za-z0-9._-]*))?\s*$")


def machine_name():
    """This machine's name as podbay-dev knows it, or None. Never guessed from the hostname."""
    env = os.environ.get("PB_MACHINE", "").strip()
    if env:
        return env
    try:
        out = subprocess.run(["podbay-dev", "setup"], capture_output=True, text=True, timeout=3).stdout
        name = json.loads(out).get("machine")
        return name.strip() if isinstance(name, str) and name.strip() else None
    except Exception:
        return None


def expand(p, base=None):
    p = os.path.expanduser(p.strip())
    if base and not os.path.isabs(p):
        p = os.path.join(base, p)
    return os.path.realpath(p)


def inside(path, folder):
    return path == folder or path.startswith(folder.rstrip(os.sep) + os.sep)


def absolute(p):
    """Only `~/...` or absolute paths: a relative one would depend on the hook's folder."""
    p = p.strip()
    return p.startswith("~") or os.path.isabs(p)


def checkout_root(cwd):
    d = cwd
    while True:
        if os.path.exists(os.path.join(d, ".git")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def map_path(cwd):
    env = os.environ.get("PB_ROLE_MAP", "").strip()
    if env:
        return expand(env) if absolute(env) else None
    # .podbay/roles.md is looked for from cwd up to the checkout root (the first folder
    # with .git), or only in cwd outside git. A map inside that root is ignored.
    root = checkout_root(cwd)
    d = cwd
    while True:
        f = os.path.join(d, ".podbay", "roles.md")
        if os.path.isfile(f):
            with open(f, encoding="utf-8", errors="replace") as fh:
                lines = fh.read(16384).splitlines()
            for line in lines:
                m = re.match(r"^\s*role-map:\s*(\S.*)$", line)
                if m:
                    if not absolute(m.group(1)):
                        return None
                    mp = expand(m.group(1))
                    return None if inside(mp, os.path.realpath(root or d)) else mp
            return None
        if root is None or d == root:
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
    best, role = (-1, 0), None
    with open(mp, encoding="utf-8", errors="replace") as fh:
        map_lines = fh.read(65536).splitlines()
    machine, asked = None, False  # read once, only when a qualified line matches the path
    for line in map_lines:
        m = LINE.match(line)
        if not m or not absolute(m.group(1)):
            continue
        path = expand(m.group(1))
        if not inside(cwd, path):
            continue
        if m.group(3):
            if not asked:
                machine, asked = machine_name(), True
            if machine is None or m.group(3) != machine:
                continue
        rank = (len(path), 1 if m.group(3) else 0)
        if rank > best:
            best, role = rank, m.group(2)
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
