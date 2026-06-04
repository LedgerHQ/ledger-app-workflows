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
  APP_REPOSITORY         : repository "owner/repo" (for the Codecov/GitHub links)
  CHANGED_FILES          : path to the newline-separated list of PR-changed files
  WORKSPACE              : workspace root, to display file paths relative to it
  TEST_DIRECTORY         : unit-test directory, excluded from the PR section
  COVERAGE_EXCLUDE_PATHS : extra exclude globs, excluded from the PR section
  BASE_REF               : PR base branch, for the Codecov explorer link
  DEFAULT_BRANCH         : repo default branch, fallback for the explorer link
  HEAD_SHA               : PR head commit, to build clickable uncovered-line links
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
    rec["uncovered_lines"] = []  # line numbers with 0 hits (from DA: records)
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
            elif line.startswith("DA:") and cur is not None:
                # DA:<line>,<hits>[,checksum] -- record lines that were never hit.
                parts = line[3:].split(",")
                try:
                    if int(parts[1]) == 0:
                        cur["uncovered_lines"].append(int(parts[0]))
                except (ValueError, IndexError):
                    pass
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

    Used for the inline (prose) coverage figures; tables use the per-cell
    helpers below.
    """
    value = pct(hit, found)
    return f"{value:.2f}% ({hit} / {found})" if value is not None else "n/a"


def pct_cell(hit, found):
    """Percentage cell for a table: ``"<pct>%"`` (or ``"n/a"``)."""
    value = pct(hit, found)
    return f"{value:.2f}%" if value is not None else "n/a"


def ratio_cell(hit, found):
    """Covered/total cell for a table: ``"<hit> / <found>"``."""
    return f"{hit} / {found}"


def to_ranges(numbers):
    """Collapse a list of line numbers into contiguous (start, end) ranges."""
    ranges = []
    for n in sorted(set(numbers)):
        if ranges and n == ranges[-1][1] + 1:
            ranges[-1][1] = n
        else:
            ranges.append([n, n])
    return [(start, end) for start, end in ranges]


def line_links(path, ranges, slug, sha):
    """Render line ranges as a comma-separated list of GitHub line links.

    Falls back to plain numbers when slug/sha are unavailable.
    """
    parts = []
    for start, end in ranges:
        label = f"{start}" if start == end else f"{start}–{end}"
        if slug and sha:
            anchor = f"L{start}" if start == end else f"L{start}-L{end}"
            parts.append(f"[{label}](https://github.com/{slug}/blob/{sha}/{path}#{anchor})")
        else:
            parts.append(label)
    return ", ".join(parts)


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
    out.append("### Overall\n")
    out.append("| Metric | Coverage | Covered / Total |")
    out.append("|---|---|---|")
    out.append(f"| Lines | {pct_cell(tot['LH'], tot['LF'])} | {ratio_cell(tot['LH'], tot['LF'])} |")
    out.append(f"| Functions | {pct_cell(tot['FNH'], tot['FNF'])} | {ratio_cell(tot['FNH'], tot['FNF'])} |")
    out.append(f"| Branches | {pct_cell(tot['BRH'], tot['BRF'])} | {ratio_cell(tot['BRH'], tot['BRF'])} |")
    out.append("")

    # Note: only files compiled into the unit-test binary appear in the
    # tracefile. Source files not built by the unit tests are invisible to
    # gcov/lcov, hence absent from this count -- it is not the project total.
    out.append(f"**Files built into the unit tests:** {len(src_records)}\n")
    out.append(f"- ✅ Exercised (≥ 1 line covered): {len(covered)}")
    out.append(f"- ❌ No line covered: {len(uncovered)}")
    out.append("")
    if uncovered:
        # Collapsible list so a long set of files does not flood the summary.
        out.append(f"<details><summary>Files with no line covered ({len(uncovered)})</summary>\n")
        for rec in sorted(uncovered, key=lambda r: r["file"]):
            out.append(f"- `{rel(rec['file'])}`")
        out.append("\n</details>\n")

    # Pull-request-only coverage: restrict the report to the source files the PR
    # actually touches. The changed-files list is produced by the workflow step.
    changed_path = os.environ.get("CHANGED_FILES", "")
    if os.environ.get("EVENT_NAME") == "pull_request":
        out.append("### Pull request changes\n")

        changed = []
        if os.path.exists(changed_path):
            with open(changed_path, errors="replace") as handle:
                changed = [line.strip() for line in handle if line.strip()]

        if not changed:
            # Missing or empty list: the collection step was skipped or failed
            # (a real PR always changes at least one file). Make it explicit
            # rather than implying that nothing was modified.
            out.append("_Changed-file list unavailable; skipping per-file PR coverage._\n")
        else:
            # Keep source files, dropping those excluded from coverage (test
            # sources, SDK, submodules) so they are not reported as "not
            # exercised".
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
            in_cov = [(c, rec) for c, rec in matched if rec is not None]
            # Changed source files absent from the report were not compiled/run
            # by the unit tests at all.
            not_exercised = [c for c, rec in matched if rec is None]

            if in_cov:
                pr_lf = sum(rec["LF"] for _, rec in in_cov)
                pr_lh = sum(rec["LH"] for _, rec in in_cov)
                # Visible status line: the aggregate *line* coverage of the
                # modified files. Then a collapsible per-file breakdown (lines
                # and branches, each cell is "<pct>% (covered / total)").
                out.append(
                    f"Line coverage of source files modified in this PR: "
                    f"**{fmt(pr_lh, pr_lf)}**\n"
                )
                out.append(
                    f"<details><summary>Coverage of modified source files "
                    f"({len(in_cov)})</summary>\n"
                )
                out.append("| File | Lines | Branches |")
                out.append("|---|---|---|")
                for c, rec in sorted(in_cov):
                    out.append(
                        f"| `{c}` | {fmt(rec['LH'], rec['LF'])} | {fmt(rec['BRH'], rec['BRF'])} |"
                    )
                out.append("\n</details>\n")

                # Clickable uncovered-line ranges for the modified files,
                # collapsed so a long list never inflates the section.
                slug = os.environ.get("APP_REPOSITORY", "")
                sha = os.environ.get("HEAD_SHA", "")
                uncovered_rows = [(c, rec) for c, rec in in_cov if rec["uncovered_lines"]]
                if uncovered_rows:
                    out.append(
                        f"<details><summary>Uncovered lines in modified files "
                        f"({len(uncovered_rows)})</summary>\n"
                    )
                    for c, rec in sorted(uncovered_rows):
                        links = line_links(c, to_ranges(rec["uncovered_lines"]), slug, sha)
                        out.append(f"- `{c}`: {links}")
                    out.append("\n</details>\n")
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
    slug = os.environ.get("APP_REPOSITORY", "")
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
