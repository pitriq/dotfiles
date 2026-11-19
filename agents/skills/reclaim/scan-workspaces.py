#!/usr/bin/env python3
"""Collect cleanup facts about every Git checkout under the given roots, in parallel.

Read-only: runs git, gh, du, and SELECT queries, and changes nothing.
Prints JSON to stdout. Usage: scan-workspaces.py [--no-gh] [ROOT ...] (default ~/Developer)
"""

import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HOME = Path.home()
WORKTREE_ROOTS = [
    HOME / ".supacode/repos",
    HOME / ".t3/worktrees",
    HOME / "Developer/apps/conductor/workspaces",
    HOME / "conductor/workspaces",
]
PRUNE = {"node_modules", ".dart_tool", "Pods", "target", "build", ".fvm", ".next", ".turbo", "dist", ".gradle", "venv", ".venv"}
OUTPUT_DIRS = ["node_modules", ".next", ".turbo", ".expo", "dist", "build", "target", ".dart_tool", "Pods", ".gradle", ".venv", "venv", "coverage", ".cache"]
POOL = ThreadPoolExecutor(max_workers=max(8, (os.cpu_count() or 4) * 2))
# du is bound by filesystem metadata, and more parallel walks than this slow each other down.
DU_POOL = ThreadPoolExecutor(max_workers=int(os.environ.get("RECLAIM_DU_WORKERS", 6)))
errors = []


def run(args, cwd=None, timeout=120):
    try:
        p = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout
    except (subprocess.TimeoutExpired, OSError) as e:
        errors.append(f"{' '.join(map(str, args))} (in {cwd}): {e}")
        return -1, ""


def git(cwd, *args, timeout=60):
    # --no-optional-locks keeps `git status` from rewriting the index, so its mtime still means "last touched".
    return run(["git", "--no-optional-locks", "-C", str(cwd), *args], timeout=timeout)


def du_gb(path):
    code, out = run(["du", "-sk", str(path)], timeout=300)
    if not out:
        return None
    return round(int(out.split()[0]) / 1048576, 2)


def du_tree(path):
    _, out = run(["du", "-k", "-d", "5", str(path)], timeout=300)
    sizes = {}
    for line in out.splitlines():
        kb, _, p = line.partition("\t")
        sizes[p] = round(int(kb) / 1048576, 2)
    return sizes


def find_git_markers(roots):
    out = []
    for root in roots:
        for dirpath, dirnames, filenames in os.walk(root):
            depth = len(Path(dirpath).relative_to(root).parts)
            if ".git" in dirnames or ".git" in filenames:
                out.append(Path(dirpath))
            dirnames[:] = [d for d in dirnames if d not in PRUNE and d != ".git" and depth < 5]
    return out


def common_dir(checkout):
    code, out = git(checkout, "rev-parse", "--path-format=absolute", "--git-common-dir")
    if code != 0:
        return None
    d = Path(out.strip()).resolve()
    return d.parent if d.name == ".git" else d


def worktrees(repo):
    code, out = git(repo, "worktree", "list", "--porcelain")
    items, cur = [], None
    for line in out.splitlines():
        if line.startswith("worktree "):
            cur = {"path": line[9:], "branch": None, "locked": False, "prunable": False}
            items.append(cur)
        elif cur is not None:
            if line.startswith("branch "):
                cur["branch"] = line[7:].removeprefix("refs/heads/")
            elif line.startswith("locked"):
                cur["locked"] = True
            elif line.startswith("prunable"):
                cur["prunable"] = True
    return items


def default_branch(repo):
    code, out = git(repo, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
    return out.strip() if code == 0 else None


def build_outputs(checkout):
    cands = []
    for dirpath, dirnames, _ in os.walk(checkout):
        depth = len(Path(dirpath).relative_to(checkout).parts)
        keep = []
        for d in dirnames:
            if d == ".git":
                continue
            if d in OUTPUT_DIRS:
                cands.append(Path(dirpath) / d)
            elif depth < 3 and d not in PRUNE:
                keep.append(d)
        dirnames[:] = keep
    if not cands:
        return []
    # Only count directories Git ignores, so a source folder named build/ is never reported.
    p = subprocess.run(["git", "-C", str(checkout), "check-ignore", "--stdin"], input="\n".join(map(str, cands)),
                       capture_output=True, text=True)
    return [{"path": line} for line in p.stdout.splitlines() if line]


def checkout_facts(info, base):
    path = Path(info["path"])
    facts = dict(info)
    if not path.exists():
        facts["missing"] = True
        return facts
    _, status = git(path, "status", "--porcelain")
    _, last = git(path, "log", "-1", "--format=%ct")
    _, unpushed = git(path, "rev-list", "--count", "HEAD", "--not", "--remotes")
    facts["dirty_files"] = len(status.splitlines())
    facts["last_commit"] = int(last.strip()) if last.strip() else None
    facts["unpushed_commits"] = int(unpushed.strip() or 0)
    code, gitdir = git(path, "rev-parse", "--absolute-git-dir")
    index = Path(gitdir.strip()) / "index"
    facts["last_index_change"] = int(index.stat().st_mtime) if index.exists() else None
    if base:
        facts["merged_into_" + base.replace("/", "_")] = git(path, "merge-base", "--is-ancestor", "HEAD", base)[0] == 0
    if info["branch"]:
        _, track = git(path, "for-each-ref", "--format=%(upstream:track)", f"refs/heads/{info['branch']}")
        facts["upstream_gone"] = "[gone]" in track
    facts["symlinks"] = [str(l) for l in path.parent.iterdir()
                         if l.is_symlink() and Path(os.readlink(l)) == path] if path.parent.exists() else []
    facts["workspace_db"] = workspace_db(path)
    facts["outputs"] = build_outputs(path)
    return facts


def workspace_db(path):
    ws = path / ".workspace"
    if ws.is_file():
        m = re.search(r"^\s*dbName:\s*(\S+)", ws.read_text(errors="ignore"), re.M)
        if m:
            return m.group(1)
    return None


def prs(repo):
    code, out = run(["gh", "pr", "list", "--state", "all", "--limit", "1000",
                     "--json", "number,state,headRefName,updatedAt"], cwd=repo, timeout=60)
    if code != 0:
        return None
    by_branch = {}
    for pr in json.loads(out or "[]"):
        cur = by_branch.get(pr["headRefName"])
        if not cur or pr["updatedAt"] > cur["updatedAt"]:
            by_branch[pr["headRefName"]] = pr
    return by_branch


def databases(repo_names, live):
    code, out = run(["docker", "ps", "--format", "{{.Names}}"], timeout=20)
    running = set(out.split())
    result = []
    for name in sorted(repo_names):
        container = f"postgres_{name}"
        if container not in running:
            continue
        _, rows = run(["docker", "exec", container, "psql", "-U", "postgres", "-Atc",
                       "SELECT datname, pg_database_size(datname) FROM pg_database WHERE NOT datistemplate"], timeout=60)
        for row in rows.splitlines():
            db, size = row.split("|")
            if db == "postgres":
                continue
            # Companion databases (<workspace db>_console) belong to the workspace whose name prefixes theirs.
            owner = live.get((name, db)) or next(
                (path for (repo, ws_db), path in sorted(live.items(), key=lambda i: -len(i[0][1]))
                 if repo == name and db.startswith(ws_db + "_")), None)
            result.append({"container": container, "db": db, "gb": round(int(size) / 1073741824, 2),
                           "checkout": owner})
    return result


def orphan_dirs(registered):
    reg = {str(Path(p)) for p in registered}
    found = []

    def walk(d, depth):
        for child in sorted(d.iterdir()) if d.is_dir() else []:
            if not child.is_dir() or child.is_symlink():
                continue
            s = str(child)
            if s in reg:
                continue
            if any(r.startswith(s + "/") for r in reg) and depth < 3:
                walk(child, depth + 1)
                continue
            if depth >= 1:
                found.append(child)

    for root in WORKTREE_ROOTS:
        if root.exists():
            walk(root, 0)
    return found


def orphan_facts(d):
    gitfile = d / ".git"
    note = "no .git"
    if gitfile.is_file():
        m = re.match(r"gitdir:\s*(.+)", gitfile.read_text(errors="ignore"))
        note = "gitdir missing" if m and not Path(m.group(1).strip()).exists() else "gitdir exists"
    elif gitfile.is_dir():
        note = "own repo"
    return {"path": str(d), "git": note, "mtime": int(d.stat().st_mtime)}


def main():
    argv = [a for a in sys.argv[1:] if a != "--no-gh"]
    use_gh = "--no-gh" not in sys.argv
    roots = [Path(a).expanduser().resolve() for a in argv] or [HOME / "Developer"]
    started = time.time()
    timings = {}

    markers = find_git_markers(roots + [r for r in WORKTREE_ROOTS if r.exists()])
    repos, broken = {}, []
    for marker, cd in zip(markers, POOL.map(common_dir, markers)):
        if cd:
            repos[str(cd)] = cd
        else:
            broken.append(marker)

    repo_list = sorted(repos.values())
    wt_lists = list(POOL.map(worktrees, repo_list))
    bases = list(POOL.map(default_branch, repo_list))
    pr_maps = list(POOL.map(prs, repo_list)) if use_gh else [None] * len(repo_list)

    jobs, registered = [], []
    for repo, wts, base in zip(repo_list, wt_lists, bases):
        for wt in wts:
            wt["repo"] = str(repo)
            wt["main"] = Path(wt["path"]) == repo
            registered.append(wt["path"])
            jobs.append(POOL.submit(checkout_facts, wt, base))
    checkouts = [j.result() for j in jobs]

    for c in checkouts:
        pr_map = pr_maps[repo_list.index(Path(c["repo"]))]
        if pr_map is not None and c.get("branch"):
            c["pr"] = pr_map.get(c["branch"])

    live = {}
    for c in checkouts:
        name = Path(c["repo"]).name
        if c.get("missing"):
            continue
        db = c.get("workspace_db") or (f"{name}_{name}" if c["main"]
                                       else f"{name}_{Path(c['path']).name.lower().replace('-', '_')}")
        c["workspace_db"] = db
        live[(name, db)] = c["path"]

    orphans = list(POOL.map(orphan_facts, sorted(set(orphan_dirs(registered) + broken))))
    timings["git"] = round(time.time() - started, 1)

    # Sizes last, in one flat pass, so no pooled task ever waits on another.
    # One du walk per checkout also yields its output folders' sizes.
    live_checkouts = [c for c in checkouts if not c.get("missing")]
    for c, tree in zip(live_checkouts, DU_POOL.map(du_tree, [c["path"] for c in live_checkouts])):
        c["gb"] = tree.get(c["path"])
        for o in c["outputs"]:
            o["gb"] = tree.get(o["path"])
    for o, gb in zip(orphans, DU_POOL.map(du_gb, [o["path"] for o in orphans])):
        o["gb"] = gb
    timings["du"] = round(time.time() - started, 1)
    print(json.dumps({
        "scanned_roots": [str(r) for r in roots],
        "worktree_roots": [str(r) for r in WORKTREE_ROOTS if r.exists()],
        "checkouts": checkouts,
        "orphan_dirs": orphans,
        "databases": databases({Path(r).name for r in repos}, live),
        "errors": errors,
        "seconds": {**timings, "total": round(time.time() - started, 1)},
    }, indent=1))


if __name__ == "__main__":
    main()
