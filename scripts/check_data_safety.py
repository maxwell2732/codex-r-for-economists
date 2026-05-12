#!/usr/bin/env python3
"""
check_data_safety.py — Block accidental commits of raw / derived datasets.

The R Research Pipeline template guarantees that nothing under
`data/raw/` or `data/derived/` is ever committed. This script enforces that
guarantee at commit time.

Forkers wire this into their git pre-commit hook. The standard install is
documented in README.md and looks like:

    cat > .git/hooks/pre-commit <<'EOF'
    #!/bin/bash
    python scripts/check_data_safety.py --staged $(git diff --cached --name-only)
    EOF
    chmod +x .git/hooks/pre-commit

Usage:
    python scripts/check_data_safety.py --staged FILE [FILE ...]
    python scripts/check_data_safety.py --scan-tree           # walk repo
    python scripts/check_data_safety.py --self-test           # run policy tests

Exit codes:
    0 — all checked paths are safe
    1 — usage error
    2 — at least one unsafe path detected (lists offending paths on stderr)
"""

import argparse
import fnmatch
import os
import sys
from pathlib import Path

# --- Configuration -----------------------------------------------------------

# Paths whose contents are ALWAYS forbidden (except .gitkeep / README.md).
ALWAYS_FORBIDDEN_PREFIXES = (
    "data/raw/",
    "data/derived/",
)

# Files allowed inside the always-forbidden prefixes (markers + docs).
ALLOWED_INSIDE_FORBIDDEN = {".gitkeep", "README.md"}

# Binary data extensions blocked outside whitelisted dirs.
BLOCKED_DATA_EXTS = {".rds", ".RData", ".Rdata",
                     ".dta", ".sav", ".por", ".parquet", ".feather"}

# Text data exports are blocked globally unless they are explicit table outputs
# or small example fixtures.
BLOCKED_TEXT_DATA_EXTS = {".csv", ".json"}

# Spreadsheet extensions: blocked outside whitelisted dirs.
BLOCKED_SHEET_EXTS = {".xls", ".xlsx"}

# Logs are NEVER committed (may echo raw data).
ALWAYS_BLOCKED_EXTS = {".log"}

# Path patterns where committed data-like files are OK. Deliberately do not
# whitelist explorations/**/output for binary data: students often place
# temporary cleaned panels there.
WHITELISTED_CSV_PATTERNS = (
    "output/tables/**",
    "explorations/**/output/tables/**",
    "templates/examples/**",
)
WHITELISTED_JSON_PATTERNS = (
    "templates/examples/**",
)
WHITELISTED_BINARY_PATTERNS = (
    "output/tables/**",
    "templates/examples/**",
)
WHITELISTED_SHEET_PATTERNS = (
    "output/tables/**",
    "templates/examples/**",
)

POLICY_TEST_CASES = (
    ("explorations/test/data/cfps.csv", True),
    ("my_root.csv", True),
    ("anywhere.json", True),
    ("explorations/test/output/cfps_raw.dta", True),
    ("output/tables/main_results.csv", False),
    ("explorations/test/output/tables/main_results.csv", False),
    ("output/tables/api_dump.json", True),
    ("output/tables/main_results.tex", False),
    ("templates/examples/toy_fixture.json", False),
    ("templates/examples/toy_fixture.dta", False),
    ("data/raw/README.md", False),
    ("data/raw/cfps.csv", True),
    ("logs/run.log", True),
)


# --- Core check --------------------------------------------------------------

def normalize(p: str) -> str:
    """Use forward slashes so prefix matching works on Windows too."""
    return p.replace("\\", "/")


def is_whitelisted_data_path(path: str, patterns) -> bool:
    """Return True for explicit, low-risk data-like file locations."""
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)


def whitelist_label(patterns) -> str:
    return ", ".join(patterns)


def is_unsafe(path: str) -> str:
    """
    Return an empty string if `path` is safe to commit, or a non-empty
    explanation if it is unsafe.
    """
    p = normalize(path)
    base = os.path.basename(p)
    ext = os.path.splitext(base)[1].lower()

    # 1) Anything under an always-forbidden prefix, unless it's a marker file.
    for prefix in ALWAYS_FORBIDDEN_PREFIXES:
        if p.startswith(prefix):
            if base in ALLOWED_INSIDE_FORBIDDEN:
                return ""
            return f"forbidden directory: {prefix} (only .gitkeep/README.md allowed)"

    # 2) Logs are never committed (may echo raw data).
    if ext in ALWAYS_BLOCKED_EXTS:
        return f"forbidden extension: {ext} (logs never commit)"

    # 3) Text data exports are blocked globally unless explicitly whitelisted.
    if ext == ".csv":
        if not is_whitelisted_data_path(p, WHITELISTED_CSV_PATTERNS):
            return (
                f"forbidden text data export: {ext} outside whitelisted paths "
                f"({whitelist_label(WHITELISTED_CSV_PATTERNS)})"
            )

    if ext == ".json":
        if not is_whitelisted_data_path(p, WHITELISTED_JSON_PATTERNS):
            return (
                f"forbidden text data export: {ext} outside whitelisted paths "
                f"({whitelist_label(WHITELISTED_JSON_PATTERNS)})"
            )

    # 4) Binary data extensions outside whitelisted dirs.
    if ext in BLOCKED_DATA_EXTS:
        if not is_whitelisted_data_path(p, WHITELISTED_BINARY_PATTERNS):
            return (
                f"forbidden binary data: {ext} outside whitelisted paths "
                f"({whitelist_label(WHITELISTED_BINARY_PATTERNS)})"
            )

    # 5) Spreadsheets outside whitelisted dirs.
    if ext in BLOCKED_SHEET_EXTS:
        if not is_whitelisted_data_path(p, WHITELISTED_SHEET_PATTERNS):
            return f"forbidden spreadsheet: {ext} outside whitelisted dirs"

    # 6) Lowercase variant of .RData also blocked above via case-insensitive
    #    extension matching is not free in Python — re-check explicitly.
    if base.lower().endswith(".rdata"):
        if not is_whitelisted_data_path(p, WHITELISTED_BINARY_PATTERNS):
            return "forbidden binary data: .RData outside whitelisted dirs"

    return ""


# --- Modes -------------------------------------------------------------------

def check_paths(paths):
    unsafe = []
    for raw in paths:
        if not raw or not raw.strip():
            continue
        reason = is_unsafe(raw.strip())
        if reason:
            unsafe.append((raw.strip(), reason))
    return unsafe


def scan_tree(root: Path):
    """Walk the repo and check every tracked-or-untracked file."""
    paths = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Skip .git
        dirnames[:] = [d for d in dirnames if d not in {".git", ".quarto", "__pycache__"}]
        for f in filenames:
            full = os.path.join(dirpath, f)
            rel = os.path.relpath(full, root)
            paths.append(rel)
    return check_paths(paths)


def run_self_tests() -> bool:
    failures = []
    for path, should_block in POLICY_TEST_CASES:
        reason = is_unsafe(path)
        blocked = bool(reason)
        if blocked != should_block:
            failures.append((path, should_block, blocked, reason))

    if not failures:
        print(f"[check_data_safety] SELF-TEST OK -- {len(POLICY_TEST_CASES)} policy cases passed.")
        return True

    print("[check_data_safety] SELF-TEST FAILED", file=sys.stderr)
    for path, should_block, blocked, reason in failures:
        expected = "BLOCK" if should_block else "ALLOW"
        actual = "BLOCK" if blocked else "ALLOW"
        print(f"  - {path}: expected {expected}, got {actual}", file=sys.stderr)
        if reason:
            print(f"      reason: {reason}", file=sys.stderr)
    return False


# --- CLI ---------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Refuse to commit raw / derived datasets."
    )
    parser.add_argument(
        "--staged",
        nargs="*",
        default=None,
        help="Check these paths (typically `git diff --cached --name-only` output)."
    )
    parser.add_argument(
        "--scan-tree",
        action="store_true",
        help="Walk the entire repo and report any tracked-or-untracked unsafe path."
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Run built-in policy regression tests."
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Project root for --scan-tree (default: cwd)."
    )
    args = parser.parse_args()

    selected_modes = sum([
        args.staged is not None,
        args.scan_tree,
        args.self_test,
    ])
    if selected_modes == 0:
        parser.print_help(sys.stderr)
        return 1

    if selected_modes > 1:
        print("error: pass only one of --staged, --scan-tree, or --self-test", file=sys.stderr)
        return 1

    if args.self_test:
        return 0 if run_self_tests() else 2

    if args.staged is not None:
        unsafe = check_paths(args.staged)
    else:
        unsafe = scan_tree(Path(args.root))

    if not unsafe:
        print("[check_data_safety] OK -- no forbidden paths detected.")
        return 0

    print(
        "[check_data_safety] BLOCKED -- the following paths must not be committed:",
        file=sys.stderr,
    )
    for path, reason in unsafe:
        print(f"  - {path}", file=sys.stderr)
        print(f"      reason: {reason}", file=sys.stderr)
    print("", file=sys.stderr)
    print("To override (after deliberate review): unstage the file with", file=sys.stderr)
    print("  git reset HEAD <file>", file=sys.stderr)
    print("or whitelist its directory in scripts/check_data_safety.py.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
