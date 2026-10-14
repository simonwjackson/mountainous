#!/usr/bin/env python3
"""Count changes to pi's settings read methods through GitHub file history."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import re
import urllib.parse
import urllib.request

REPO = "earendil-works/pi"
FILE = "packages/coding-agent/src/core/settings-manager.ts"
METHODS = {
    "withLock": "FileSettingsStorage",
    "acquireLockSyncWithRetry": "FileSettingsStorage",
    "loadFromStorage": "SettingsManager",
    "tryLoadFromStorage": "SettingsManager",
}


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "mountainous-policy-history"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode()


def regions(source):
    result = {}
    for method, cls in METHODS.items():
        class_match = re.search(rf"^export class {cls}\b", source, re.M)
        if class_match is None:
            result[method] = None
            continue
        class_end = re.search(r"^}", source[class_match.end():], re.M)
        body = source[class_match.end():class_match.end() + class_end.end()]
        start = re.search(rf"^(\s*)(?:private )?(?:static )?{method}\(", body, re.M)
        if start is None:
            result[method] = None
            continue
        indent = start[1].lstrip("\n\r")
        end = re.search(rf"^{re.escape(indent)}}}$", body[start.end():], re.M)
        if end is None:
            raise ValueError(f"Cannot locate {cls}.{method} closing brace")
        result[method] = body[start.start():start.end() + end.end()].strip()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--since", required=True)
    parser.add_argument("--until", required=True)
    args = parser.parse_args()
    commits = []
    page = 1
    while True:
        query = urllib.parse.urlencode({"path": FILE, "since": args.since, "until": args.until, "per_page": 100, "page": page})
        found = json.loads(fetch(f"https://api.github.com/repos/{REPO}/commits?{query}"))
        commits.extend(found)
        if len(found) < 100:
            break
        page += 1
    revisions = sorted({c["sha"] for c in commits} | {c["parents"][0]["sha"] for c in commits})

    def read_revision(revision):
        return revision, regions(fetch(f"https://raw.githubusercontent.com/{REPO}/{revision}/{FILE}"))

    with ThreadPoolExecutor(max_workers=4) as pool:
        sources = dict(pool.map(read_revision, revisions))
    changes = []
    for commit in commits:
        old, new = sources[commit["parents"][0]["sha"]], sources[commit["sha"]]
        changed = [method for method in METHODS if old[method] != new[method]]
        changes.append({"sha": commit["sha"], "date": commit["commit"]["committer"]["date"],
                        "subject": commit["commit"]["message"].splitlines()[0], "methods": changed})
    patched = {"withLock", "loadFromStorage", "tryLoadFromStorage"}
    print(json.dumps({"repository": REPO, "path": FILE, "since": args.since, "until": args.until,
                      "file_commits": len(commits),
                      "method_commits": {m: sum(m in c["methods"] for c in changes) for m in METHODS},
                      "patched_region_commits": sum(bool(patched.intersection(c["methods"])) for c in changes),
                      "all_read_lock_region_commits": sum(bool(c["methods"]) for c in changes),
                      "commits": changes}, indent=2))


if __name__ == "__main__":
    main()
