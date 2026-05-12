#!/usr/bin/env python3
"""
Quality Scoring System for the R Research Pipeline (Template)

Calculates objective quality scores (0-100) for R scripts, Quarto reports,
and ancillary Python scripts. Enforces quality gates: 80 (commit), 90 (PR),
95 (excellence) — per `.claude/rules/quality-gates.md`.

Usage:
    python scripts/quality_score.py R/03_analysis/main_regression.R
    python scripts/quality_score.py reports/analysis_report.qmd
    python scripts/quality_score.py R/**/*.R --summary
    python scripts/quality_score.py --json scripts/check_data_safety.py

Design notes:
- Lightweight static checks only. The full review is done by agents
  (r-reviewer, econometric-reviewer, r-log-validator).
- The R-script rubric mirrors the deductions in .claude/rules/quality-gates.md
  exactly. If you change the rubric there, change it here too.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import List

# =============================================================================
# Thresholds — quality-gates.md
# =============================================================================

THRESHOLDS = {"commit": 80, "pr": 90, "excellence": 95}


# =============================================================================
# Data classes
# =============================================================================

@dataclass
class Issue:
    severity: str   # "critical" | "major" | "minor"
    category: str
    line: int
    message: str
    deduction: int


@dataclass
class Score:
    file: str
    kind: str                      # "R" | "qmd" | "py" | "unknown"
    issues: List[Issue] = field(default_factory=list)

    @property
    def total_deduction(self) -> int:
        return sum(i.deduction for i in self.issues)

    @property
    def points(self) -> int:
        return max(0, 100 - self.total_deduction)

    @property
    def gate(self) -> str:
        p = self.points
        if p >= THRESHOLDS["excellence"]:
            return "EXCELLENCE"
        if p >= THRESHOLDS["pr"]:
            return "PR-READY"
        if p >= THRESHOLDS["commit"]:
            return "COMMIT-OK"
        return "BLOCKED"

    def to_dict(self) -> dict:
        return {
            "file": self.file,
            "kind": self.kind,
            "score": self.points,
            "gate": self.gate,
            "issues": [
                {
                    "severity": i.severity,
                    "category": i.category,
                    "line": i.line,
                    "message": i.message,
                    "deduction": i.deduction,
                }
                for i in self.issues
            ],
        }


# =============================================================================
# R script rubric
# =============================================================================
# Mirrors .claude/rules/quality-gates.md § "R Scripts".

class RFileChecker:
    # An absolute path inside a quoted string OR a setwd() call.
    ABS_PATH_RE = re.compile(
        r'(?:setwd\s*\(\s*["\']'
        r'|["\'](?:[A-Za-z]:[\\/]|/(?:home|Users|root|tmp)/))',
        re.IGNORECASE,
    )
    # `setwd(...)` is forbidden regardless of the path argument.
    SETWD_RE = re.compile(r"\bsetwd\s*\(", re.IGNORECASE)
    # Logging: any of start_log(, sink(, log4r:: open / appender.
    LOG_OPEN_RE = re.compile(
        r"\bstart_log\s*\(|\bsink\s*\(|\blog4r::",
        re.IGNORECASE,
    )
    # R version pin: `if (getRversion() < ...) stop(...)`.
    VERSION_RE = re.compile(
        r"getRversion\s*\(\s*\)\s*<",
        re.IGNORECASE,
    )
    SET_SEED_RE = re.compile(r"\bset\.seed\s*\(\s*\d", re.IGNORECASE)
    # Function calls that draw randomness or run a stochastic procedure.
    RANDOM_USE_RE = re.compile(
        r"\b(?:rnorm|runif|rbinom|rpois|rchisq|rt\(|rexp|rgamma|rbeta|"
        r"sample\s*\(|bootstrap\s*\(|boot::boot|simulate\s*\()",
        re.IGNORECASE,
    )
    # Estimation calls that should produce a captured result.
    ESTIMATION_RE = re.compile(
        r"^\s*(?:[\w\.\$\[\]\"']+\s*<-\s*)?"
        r"(?:fixest::|estimatr::|sandwich::)?"
        r"(?:feols|feglm|feNmlm|lm|glm|ivreg|iv_robust|did2s|"
        r"plm|lmer|glmer|rdrobust|rdd_)\s*\(",
        re.IGNORECASE | re.MULTILINE,
    )
    # An estimation result that has been captured into a name.
    EST_STORE_RE = re.compile(
        r"<-\s*(?:fixest::|estimatr::)?"
        r"(?:feols|feglm|feNmlm|lm|glm|ivreg|iv_robust|did2s|"
        r"plm|lmer|glmer|rdrobust|rdd_)\s*\(",
        re.IGNORECASE,
    )
    HEADER_FIELDS = ("File:", "Project:", "Author:", "Purpose:",
                     "Inputs:", "Outputs:", "Log:")
    # Numbered or banner-style section headers.
    SECTION_BANNER_RE = re.compile(
        r"^\s*#\s*(?:[-=*]{3,}|---\s*\d|\d+\.)",
        re.MULTILINE,
    )
    # Commented-out estimation or data-load lines.
    DEAD_CODE_RE = re.compile(
        r"^\s*#\s*(?:library|require|feols|lm|glm|ivreg|read_csv|read_dta|"
        r"readRDS|readr::|haven::|dplyr::|tidyr::)\b",
        re.MULTILINE,
    )
    # 4+ digit literal sitting inside an estimation call.
    MAGIC_NUMBER_RE = re.compile(
        r"\b(?:feols|feglm|lm|glm|ivreg|iv_robust|did2s|rdrobust|rdd_)\s*"
        r"\([^\n)]*\b\d{4,}\b",
        re.IGNORECASE,
    )

    def __init__(self, path: Path):
        self.path = path
        self.text = path.read_text(encoding="utf-8", errors="replace")
        self.lines = self.text.splitlines()
        self.score = Score(file=str(path), kind="R")
        # Files under `_utils/` are sourced helpers, not standalone runnable
        # scripts. Skip the standalone-only checks (header, version pin, log
        # opening, seed). Path / dead-code / magic-number / line-length checks
        # still apply.
        norm_path = str(path).replace("\\", "/")
        self.is_utility = "/_utils/" in norm_path or norm_path.endswith("/_utils")

    def add(self, severity: str, category: str, line: int, msg: str, ded: int):
        self.score.issues.append(Issue(severity, category, line, msg, ded))

    @staticmethod
    def _strip_comment(line: str) -> str:
        """Strip a trailing #-comment, respecting quoted strings.

        Conservative: walks the line tracking single/double quotes and cuts at
        the first unquoted `#`. This is enough to dodge the false positive of
        a regex matching forbidden tokens that appear *inside* a comment.
        """
        in_single = in_double = False
        for i, ch in enumerate(line):
            if ch == "'" and not in_double:
                in_single = not in_single
            elif ch == '"' and not in_single:
                in_double = not in_double
            elif ch == "#" and not (in_single or in_double):
                return line[:i]
        return line

    # --- individual checks --------------------------------------------------

    def check_header(self):
        if self.is_utility:
            return
        head = "\n".join(self.lines[:25])
        missing = [f for f in self.HEADER_FIELDS if f not in head]
        if len(missing) == len(self.HEADER_FIELDS):
            self.add("major", "Header", 1, "Missing file header block entirely", 8)
        elif missing:
            self.add(
                "major", "Header", 1,
                f"Header missing fields: {', '.join(missing)}",
                min(8, 2 * len(missing)),
            )

    def check_version(self):
        if self.is_utility:
            return
        if not self.VERSION_RE.search(self.text):
            self.add(
                "critical", "Boilerplate", 1,
                "No R version pin (e.g., `if (getRversion() < \"4.3.0\") stop(...)`)",
                15,
            )

    def check_log(self):
        if self.is_utility:
            return
        if not self.LOG_OPEN_RE.search(self.text):
            self.add(
                "critical", "Logging", 1,
                "No log opened — script produces no log; reproducibility broken "
                "(use start_log() from R/_utils/logging.R)",
                15,
            )

    def check_seed(self):
        if self.is_utility:
            return
        if self.RANDOM_USE_RE.search(self.text) and not self.SET_SEED_RE.search(self.text):
            self.add(
                "major", "Reproducibility", 1,
                "Randomness used but no `set.seed()`",
                10,
            )

    def check_setwd(self):
        for i, line in enumerate(self.lines, 1):
            code = self._strip_comment(line)
            if self.SETWD_RE.search(code):
                self.add(
                    "critical", "Paths", i,
                    "setwd() is forbidden; use here::here() / proj_path()",
                    25,
                )

    def check_abs_paths(self):
        for i, line in enumerate(self.lines, 1):
            code = self._strip_comment(line)
            if self.SETWD_RE.search(code):
                continue   # already counted by check_setwd
            if self.ABS_PATH_RE.search(code):
                self.add(
                    "critical", "Paths", i,
                    f"Hardcoded absolute path: `{line.strip()[:80]}`",
                    25,
                )

    def check_est_store(self):
        n_est = len(self.ESTIMATION_RE.findall(self.text))
        n_store = len(self.EST_STORE_RE.findall(self.text))
        if n_est >= 1 and n_store == 0:
            self.add(
                "major", "Estimation", 0,
                f"{n_est} estimation call(s) but no result assigned to a name "
                "(modelsummary table assembly will have nothing to combine)",
                5,
            )

    def check_section_banners(self):
        if len(self.lines) >= 50 and len(self.SECTION_BANNER_RE.findall(self.text)) < 3:
            self.add(
                "minor", "Comments", 0,
                "Few or no section banners (numbered `# --- N. ... ---`)",
                2,
            )

    def check_dead_code(self):
        hits = self.DEAD_CODE_RE.findall(self.text)
        if hits:
            self.add(
                "minor", "Comments", 0,
                f"{len(hits)} commented-out estimation/data line(s) — dead code",
                min(8, 2 * len(hits)),
            )

    def check_magic_numbers(self):
        hits = self.MAGIC_NUMBER_RE.findall(self.text)
        if hits:
            self.add(
                "major", "Magic", 0,
                f"{len(hits)} estimation line(s) contain a 4+ digit literal "
                "(extract to a named constant with a comment)",
                min(15, 3 * len(hits)),
            )

    def check_long_lines(self):
        offenders = sum(1 for ln in self.lines if len(ln.rstrip()) > 100)
        if offenders:
            self.add(
                "minor", "Polish", 0,
                f"{offenders} line(s) over 100 chars",
                min(10, offenders),
            )

    # --- run all ------------------------------------------------------------

    def run(self) -> Score:
        self.check_header()
        self.check_version()
        self.check_log()
        self.check_seed()
        self.check_setwd()
        self.check_abs_paths()
        self.check_est_store()
        self.check_section_banners()
        self.check_dead_code()
        self.check_magic_numbers()
        self.check_long_lines()
        return self.score


# =============================================================================
# Quarto report rubric (lightweight)
# =============================================================================

class QmdReportChecker:
    # Analysis (regression / IV / DiD) belongs in R/, not in {r} chunks of
    # the report. Catch the obvious offenders.
    INLINE_ANALYSIS_RE = re.compile(
        r"```\{r[^}]*\}[^`]*?"
        r"\b(?:feols|feglm|lm\s*\(|glm\s*\(|ivreg|iv_robust|did2s|"
        r"fixest::|estimatr::|sandwich::)\b",
        re.IGNORECASE | re.DOTALL,
    )
    CITE_RE = re.compile(r"@([A-Za-z][\w-]*\d{2,4}[a-z]?)")
    CHUNK_RE = re.compile(r"```\{[^}]+\}", re.DOTALL)

    def __init__(self, path: Path):
        self.path = path
        self.text = path.read_text(encoding="utf-8", errors="replace")
        self.score = Score(file=str(path), kind="qmd")

    def add(self, *a, **kw):
        self.score.issues.append(Issue(*a, **kw))

    def check_inline_analysis(self):
        if self.INLINE_ANALYSIS_RE.search(self.text):
            self.add(
                "critical", "Architecture", 0,
                "Report contains an analysis call (feols / lm / glm / ivreg / "
                "did2s) inside an {r} chunk. Analysis must live in R/, not in "
                "reports — the report should `read_csv()` from output/tables/.",
                30,
            )

    def check_citations(self):
        keys = set(self.CITE_RE.findall(self.text))
        bib_path = Path("references.bib")
        if not bib_path.exists():
            if keys:
                self.add("critical", "Citations", 0,
                         f"references.bib not found but {len(keys)} citation key(s) used", 15)
            return
        bib_text = bib_path.read_text(encoding="utf-8", errors="replace")
        bib_keys = set(re.findall(r"@\w+\{([^,]+),", bib_text))
        missing = keys - bib_keys
        for k in sorted(missing):
            self.add("critical", "Citations", 0,
                     f"Citation @{k} not found in references.bib", 15)

    def check_required_sections(self):
        # Accept either a Markdown # heading OR a YAML frontmatter title:.
        has_h1 = any(line.startswith("# ") for line in self.text.splitlines())
        has_yaml_title = bool(re.search(r"^title:\s*\S", self.text, re.MULTILINE))
        if not (has_h1 or has_yaml_title):
            self.add("critical", "Structure", 0,
                     "Report has no top-level title (neither YAML title: nor # heading)", 10)

    def run(self) -> Score:
        self.check_inline_analysis()
        self.check_citations()
        self.check_required_sections()
        return self.score


# =============================================================================
# Python script rubric (very light)
# =============================================================================

class PyChecker:
    ABS_PATH_RE = re.compile(r'["\'](?:[A-Z]:[\\/]|/(?:home|Users|root|tmp)/)')

    def __init__(self, path: Path):
        self.path = path
        self.text = path.read_text(encoding="utf-8", errors="replace")
        self.lines = self.text.splitlines()
        self.score = Score(file=str(path), kind="py")

    def add(self, *a, **kw):
        self.score.issues.append(Issue(*a, **kw))

    def check_syntax(self):
        try:
            compile(self.text, str(self.path), "exec")
        except SyntaxError as e:
            self.add("critical", "Syntax", e.lineno or 1,
                     f"SyntaxError: {e.msg}", 100)

    def check_module_docstring(self):
        # First non-blank, non-import line should be a string for a docstring,
        # OR the file starts with a """..."""
        stripped = self.text.lstrip()
        if not (stripped.startswith('"""') or stripped.startswith("'''")):
            # tolerate shebang
            after_shebang = self.text.split("\n", 1)[1] if self.text.startswith("#!") else self.text
            if not (after_shebang.lstrip().startswith('"""') or after_shebang.lstrip().startswith("'''")):
                self.add("major", "Docs", 1, "Missing module docstring", 5)

    def check_abs_paths(self):
        for i, line in enumerate(self.lines, 1):
            # Ignore comments
            code = line.split("#", 1)[0]
            if self.ABS_PATH_RE.search(code):
                self.add("critical", "Paths", i, f"Hardcoded absolute path: `{line.strip()[:80]}`", 25)

    def check_long_lines(self):
        offenders = sum(1 for ln in self.lines if len(ln.rstrip()) > 100)
        if offenders:
            self.add("minor", "Polish", 0,
                     f"{offenders} line(s) over 100 chars",
                     min(10, offenders))

    def run(self) -> Score:
        self.check_syntax()
        # If syntax failed, don't bother with the rest.
        if any(i.severity == "critical" and i.category == "Syntax" for i in self.score.issues):
            return self.score
        self.check_module_docstring()
        self.check_abs_paths()
        self.check_long_lines()
        return self.score


# =============================================================================
# Dispatcher
# =============================================================================

def score_file(path: Path) -> Score:
    suffix = path.suffix.lower()
    if suffix in (".r",):
        return RFileChecker(path).run()
    if suffix == ".qmd":
        return QmdReportChecker(path).run()
    if suffix == ".py":
        return PyChecker(path).run()
    s = Score(file=str(path), kind="unknown")
    s.issues.append(
        Issue("major", "Unknown", 0, f"No rubric for {suffix} files", 0)
    )
    return s


# =============================================================================
# Reporting
# =============================================================================

def render_text(s: Score, summary: bool = False) -> str:
    out = []
    out.append("=" * 72)
    out.append(f"File:  {s.file}")
    out.append(f"Kind:  {s.kind}")
    out.append(f"Score: {s.points}/100   Gate: {s.gate}")
    out.append("=" * 72)
    if summary:
        return "\n".join(out)

    # Group by severity for readability
    for sev in ("critical", "major", "minor"):
        sev_issues = [i for i in s.issues if i.severity == sev]
        if not sev_issues:
            continue
        out.append(f"\n[{sev.upper()}] {len(sev_issues)} issue(s)")
        for i in sev_issues:
            line_str = f"L{i.line:>4}" if i.line else "  -- "
            out.append(f"  {line_str}  -{i.deduction:>3}  {i.category:<14} {i.message}")

    if not s.issues:
        out.append("\n[OK] No issues detected.")
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument("files", nargs="+", help="Files to score")
    parser.add_argument("--summary", action="store_true", help="One line per file")
    parser.add_argument("--json", action="store_true", help="JSON output")
    args = parser.parse_args()

    scores = [score_file(Path(f)) for f in args.files]

    if args.json:
        print(json.dumps([s.to_dict() for s in scores], indent=2))
    else:
        for s in scores:
            print(render_text(s, summary=args.summary))

    # Exit non-zero if any file is below commit threshold.
    return 0 if all(s.points >= THRESHOLDS["commit"] for s in scores) else 2


if __name__ == "__main__":
    sys.exit(main())
