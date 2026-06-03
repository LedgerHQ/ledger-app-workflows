#!/usr/bin/env python3
"""Write a code-coverage report to the GitHub Actions job summary.

Parses an lcov tracefile (``coverage.info`` in the current working directory)
and appends a Markdown report to ``$GITHUB_STEP_SUMMARY``: total line/function/
branch coverage, the number of files with/without coverage and -- on pull
requests -- the coverage of the source files modified in the PR.

The lcov ``.info`` file is parsed directly (``LF/LH``, ``FNF/FNH``, ``BRF/BRH``)
rather than relying on ``lcov --summary``, whose output format varies across
lcov versions.

Inputs (environment):
  EVENT_NAME             : GitHub event name (PR section runs on ``pull_request``)
  PR_NUMBER              : pull request number (for the Codecov link)
  REPO_SLUG              : repository slug, "owner/repo" (for the Codecov link)
  CHANGED_FILES          : path to the newline-separated list of PR-changed files
  WORKSPACE              : workspace root, to display file paths relative to it
  TEST_DIRECTORY         : unit-test directory, excluded from the PR section
  COVERAGE_EXCLUDE_PATHS : extra exclude globs, excluded from the PR section
  BASE_REF               : PR base branch, for the Codecov explorer link
  DEFAULT_BRANCH         : repo default branch, fallback for the explorer link
"""

import fnmatch
import os
import sys

# Tracefile produced by `lcov ... -o coverage.info`, read from the current dir.
COV_FILE = "coverage.info"

# Extensions considered "source" when reporting the PR-only coverage. Changed
# files outside this set (docs, build files, ...) are ignored.
SRC_EXT = (".c", ".h", ".cpp", ".cc", ".cxx", ".hpp", ".hh")

# Per-file lcov counters we accumulate. For each one, the "<KEY>:<n>" line gives
# a number we sum up across the file's records:
#   LF / LH  : lines found / lines hit
#   FNF / FNH: functions found / hit
#   BRF / BRH: branches found / hit
KEYS = ("LF", "LH", "FNF", "FNH", "BRF", "BRH")


def new_record():
    """Return a fresh per-file record with all counters zeroed."""
    rec = {key: 0 for key in KEYS}
    rec["file"] = None
    return rec


def parse_tracefile(path):
    """Parse an lcov tracefile into a list of per-file records.

    An lcov ``.info`` file is a flat sequence of per-file blocks::

        SF:/abs/path/to/file.c   <- start of record, source file name
        ...                      <- DA/FN/BR/LF/LH/... data lines
        end_of_record

    We only keep the source path (``SF:``) and the aggregate counters in
    ``KEYS``; everything else (per-line ``DA:`` data, etc.) is ignored.

    Returns a list of dicts, one per file, each with the ``KEYS`` counters plus
    a ``"file"`` entry holding the source path.
    """
    records, cur = [], None
    with open(path, errors="replace") as handle:
        for line in handle:
            line = line.strip()
            if line.startswith("SF:"):
                # New file block begins.
                cur = new_record()
                cur["file"] = line[3:]
            elif line == "end_of_record":
                # File block ends; commit it.
                if cur:
                    records.append(cur)
                cur = None
            elif cur is not None:
                # Accumulate the counter lines we care about.
                for key in KEYS:
                    if line.startswith(key + ":"):
                        try:
                            cur[key] += int(line.split(":", 1)[1])
                        except ValueError:
                            pass
                        break
    return records


def pct(hit, found):
    """Return the percentage hit/found, or ``None`` when nothing was found."""
    return (100.0 * hit / found) if found else None


def fmt(hit, found):
    """Format a counter pair as ``"<pct>% (<hit> / <found>)"`` (or ``"n/a"``).

    The covered/total meaning of the parenthesised numbers is documented by the
    table header ("Coverage (covered / total)").
    """
    value = pct(hit, found)
    return f"{value:.2f}% ({hit} / {found})" if value is not None else "n/a"


def exclude_patterns():
    """Return the lcov-style globs excluded from coverage, for the PR section.

    Mirrors the exclusion list applied by generate_coverage.sh so that files
    dropped from coverage.info (the test sources themselves, the SDK, vendored
    submodules, ...) are not mistakenly reported as "not exercised".
    """
    test_dir = os.environ.get("TEST_DIRECTORY", "").strip("/")
    patterns = ["/usr/*", "/opt/*"]
    if test_dir:
        patterns.append(f"*/{test_dir}/*")
    patterns += os.environ.get("COVERAGE_EXCLUDE_PATHS", "").split()
    return patterns


def is_excluded(path, patterns):
    """True if a repo-relative path matches any lcov exclude glob.

    The path is prefixed with "/" so leading-anchored patterns such as
    ``*/tests/unit/*`` match the same way lcov matches absolute paths.
    """
    candidate = "/" + path
    return any(fnmatch.fnmatch(candidate, pattern) for pattern in patterns)


def main():
    """Build the Markdown report and append it to ``$GITHUB_STEP_SUMMARY``."""
    if not os.path.exists(COV_FILE):
        # Coverage generation failed or was skipped: nothing to report.
        print(f"{COV_FILE} not found, skipping summary")
        return

    records = parse_tracefile(COV_FILE)

    # lcov stores absolute paths; display them relative to the workspace so the
    # summary stays readable (e.g. "src/foo.c" instead of "/__w/app/app/src/...").
    workspace = os.environ.get("WORKSPACE", "")

    def rel(path):
        """Strip the workspace prefix from an absolute source path, if present."""
        if workspace and path.startswith(workspace + "/"):
            return path[len(workspace) + 1:]
        return path

    # Project-wide totals: sum each counter across every file record.
    tot = {key: sum(rec[key] for rec in records) for key in KEYS}

    # A file with no instrumented lines (LF == 0) carries no coverage signal, so
    # it is excluded from the covered/uncovered counts.
    src_records = [rec for rec in records if rec["LF"] > 0]
    covered = [rec for rec in src_records if rec["LH"] > 0]
    uncovered = [rec for rec in src_records if rec["LH"] == 0]

    # `out` collects Markdown lines that are joined and written at the end.
    out = []
    out.append("## Code coverage\n")
    out.append("| Metric | Coverage (covered / total) |")
    out.append("|---|---|")
    out.append(f"| Lines | {fmt(tot['LH'], tot['LF'])} |")
    out.append(f"| Functions | {fmt(tot['FNH'], tot['FNF'])} |")
    out.append(f"| Branches | {fmt(tot['BRH'], tot['BRF'])} |")
    out.append("")

    # Note: only files compiled into the unit-test binary appear in the
    # tracefile. Source files not built by the unit tests are invisible to
    # gcov/lcov, hence absent from this count -- it is not the project total.
    out.append(
        f"**Files built into the unit tests:** {len(src_records)} "
        f"({len(covered)} exercised, {len(uncovered)} with no line covered)\n"
    )
    if uncovered:
        # Collapsible list so a long set of files does not flood the summary.
        out.append(f"<details><summary>Files with no line covered ({len(uncovered)})</summary>\n")
        for rec in sorted(uncovered, key=lambda r: r["file"]):
            out.append(f"- `{rel(rec['file'])}`")
        out.append("\n</details>\n")

    # Pull-request-only coverage: restrict the report to the source files the PR
    # actually touches. The changed-files list is produced by the workflow step.
    changed_path = os.environ.get("CHANGED_FILES", "")
    if os.environ.get("EVENT_NAME") == "pull_request" and os.path.exists(changed_path):
        with open(changed_path, errors="replace") as handle:
            changed = [line.strip() for line in handle if line.strip()]
        # Keep source files, dropping those excluded from coverage (test sources,
        # SDK, submodules) so they are not reported as "not exercised".
        patterns = exclude_patterns()
        changed_src = [
            c for c in changed if c.endswith(SRC_EXT) and not is_excluded(c, patterns)
        ]

        def match(changed_file):
            """Find the coverage record for a repo-relative changed file.

            The changed file is relative to the repo root (e.g. "src/foo.c")
            while lcov records hold absolute paths, so we match on a path suffix.
            Returns the record, or ``None`` if the file is not in the report.
            """
            for rec in records:
                if rec["file"] == changed_file or rec["file"].endswith("/" + changed_file):
                    return rec
            return None

        matched = [(c, match(c)) for c in changed_src]
        in_cov = [rec for _, rec in matched if rec is not None]
        # Changed source files absent from the report were not compiled/run by
        # the unit tests at all.
        not_exercised = [c for c, rec in matched if rec is None]

        out.append("### Pull request changes\n")
        if in_cov:
            pr_lf = sum(rec["LF"] for rec in in_cov)
            pr_lh = sum(rec["LH"] for rec in in_cov)
            out.append(
                f"Coverage of source files modified in this PR: "
                f"**{fmt(pr_lh, pr_lf)}** across {len(in_cov)} file(s)\n"
            )
        else:
            out.append("No modified source file is part of the coverage report.\n")
        if not_exercised:
            out.append(
                f"<details><summary>Modified source files not exercised by unit tests "
                f"({len(not_exercised)})</summary>\n"
            )
            for c in sorted(not_exercised):
                out.append(f"- `{c}`")
            out.append("\n</details>\n")

    # Codecov links: the full report (PR page when on a PR) and the file
    # explorer of the reference branch (PR base, else the repo default branch)
    # to inspect its current coverage state.
    slug = os.environ.get("REPO_SLUG", "")
    pr = os.environ.get("PR_NUMBER", "")
    if slug:
        links = []
        url = f"https://app.codecov.io/gh/{slug}"
        if os.environ.get("EVENT_NAME") == "pull_request" and pr:
            url += f"/pull/{pr}"
        links.append(f"[View the full report on Codecov]({url})")

        ref = os.environ.get("BASE_REF") or os.environ.get("DEFAULT_BRANCH")
        if ref:
            tree_url = f"https://app.codecov.io/gh/{slug}/tree/{ref}"
            links.append(f"[Browse `{ref}` coverage on Codecov]({tree_url})")

        out.append("")
        out.extend(f"- {link}" for link in links)

    # Append to the job summary file, or print to stdout when run locally.
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    text = "\n".join(out) + "\n"
    if summary:
        with open(summary, "a") as handle:
            handle.write(text)
    else:
        print(text)


if __name__ == "__main__":
    sys.exit(main())
