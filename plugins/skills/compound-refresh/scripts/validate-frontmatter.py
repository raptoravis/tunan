#!/usr/bin/env python3
"""Validate the YAML block of a compound `yunxing:solution` issue body.

A learning is a GitHub issue labeled `yunxing:solution`. Its body starts with a
fenced ```yaml block holding the frontmatter described in `references/schema.yaml`.
This script extracts that block and checks it for parser-safety issues.

Usage:
    python3 validate-frontmatter.py <issue-body-path>   # read body from a file
    python3 validate-frontmatter.py -                    # read body from stdin
    cat body.md | python3 validate-frontmatter.py        # read body from stdin

Exit codes:
    0 — the YAML block passes all checks
    1 — validation failure (diagnostics on stderr)
    2 — usage error (bad arguments, missing file, no YAML block found)

Scope: this script catches *parser-safety* issues — YAML that strict parsers
will silently misread. It does NOT validate against the schema's required-field
or enum-value rules; that's a separate concern. The intent is to prevent the
silent-data-loss bug class where YAML's quoting rules truncate or reframe scalar
values without raising.

Block extraction: the YAML lives in the first fenced block opened by a line
whose stripped content is ```yaml (or ``` immediately followed by a `key: value`
line). For backward compatibility the script also accepts a raw `---`/`---`
frontmatter pair at the very top of the input.

Checks (regex-based, no YAML parser dependency):
    1. A YAML block is present and properly closed
    2. No top-level scalar value contains ` #` unquoted (silent comment
       truncation — what Codex caught on PR #695)
    3. No top-level scalar value contains `: ` unquoted (mapping confusion —
       what surfaced in a 2026-04-16 plan doc's `title:` field)

The script does NOT flag values starting with YAML reserved indicators
(`` ` ``, `*`, `&`, `!`, etc.) because those produce loud parser errors
downstream rather than silent corruption — they're already caught by whatever
consumes the doc. This validator's purpose is silent-corruption prevention,
not lint.

Pure-stdlib (no PyYAML or other third-party deps). Runs in <50ms typical.
"""
import os
import re
import sys


def usage_fail(msg: str) -> "NoReturn":
    sys.stderr.write(f"validate-frontmatter: {msg}\n")
    sys.exit(2)


def extract_yaml_block(text: str, source: str) -> str:
    """Return the YAML block from an issue body, or exit(2) if none found.

    Accepts two shapes:
      1. A fenced ```yaml (or bare ```) block — the preferred issue-body form.
      2. A leading `---` / `---` frontmatter pair — backward compatibility.
    """
    lines = text.split("\n")

    # Shape 1: fenced ```yaml block (allow leading blank lines before it).
    fence_open = re.compile(r"^\s*```\s*ya?ml\s*$", re.IGNORECASE)
    plain_fence = re.compile(r"^\s*```\s*$")
    for i, line in enumerate(lines):
        if fence_open.match(line):
            for j in range(i + 1, len(lines)):
                if plain_fence.match(lines[j]):
                    return "\n".join(lines[i + 1 : j])
            usage_fail(f"{source}: yaml fence opened but never closed with ```")
        if line.strip():
            # First non-blank line is not a yaml fence — stop scanning for one
            # and fall through to the frontmatter shape.
            break

    # Shape 2: leading `---` / `---` frontmatter (backward compatibility).
    first = next((idx for idx, l in enumerate(lines) if l.strip()), None)
    if first is not None and lines[first].rstrip() == "---":
        for j in range(first + 1, len(lines)):
            if lines[j].rstrip() == "---":
                return "\n".join(lines[first + 1 : j])
        usage_fail(f"{source}: '---' frontmatter opened but never closed")

    usage_fail(
        f"{source}: no YAML block found — expected a fenced ```yaml block at the "
        "top of the issue body"
    )


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        usage_fail(f"usage: {os.path.basename(argv[0])} <issue-body-path>|-")

    arg = argv[1]
    if arg == "-":
        sys.stdin.reconfigure(encoding="utf-8", errors="replace")
        text = sys.stdin.read()
        source = "<stdin>"
    elif not sys.stdin.isatty() and not os.path.exists(arg):
        # Tolerate `cat body.md | validate-frontmatter.py` where the arg was
        # actually meant as stdin sentinel but omitted; prefer explicit file.
        usage_fail(f"file not found: {arg}")
    else:
        if not os.path.isfile(arg):
            usage_fail(f"file not found: {arg}")
        with open(arg, encoding="utf-8") as f:
            text = f.read()
        source = arg

    fm_text = extract_yaml_block(text, source)

    issues: list[str] = []

    # Checks 2 & 3: silent-corruption quoting risks on top-level scalar fields.
    # We scan line-by-line and only flag top-level mapping entries (no leading
    # whitespace) whose value isn't already quoted/structured.
    for lineno, line in enumerate(fm_text.split("\n"), start=1):
        stripped = line.lstrip()
        if not stripped or stripped.startswith("#"):
            continue
        if ":" not in line:
            continue
        # Top-level mapping keys only — skip nested values, array items
        if line.startswith((" ", "\t")):
            continue
        # Skip pure list-marker lines like "- item"
        if stripped.startswith("- "):
            continue

        key, _, val = line.partition(":")
        val_stripped = val.strip()
        if not val_stripped:
            # Key with no value on this line — likely a parent of a nested
            # block (`tags:` followed by `- foo`). Nothing to validate here.
            continue
        # Already quoted or structured (block scalar, flow collection)
        if val_stripped[0] in '"\'[{|>':
            continue

        if re.search(r"\s#", val_stripped):
            issues.append(
                f"line {lineno}: '{key.strip()}' value contains ' #' — quote it. "
                "YAML treats space-then-# as a comment delimiter and silently "
                "drops the rest of the value."
            )
        if re.search(r":\s", val_stripped):
            issues.append(
                f"line {lineno}: '{key.strip()}' value contains ': ' — quote it. "
                "Strict YAML parsers may treat this as a nested mapping."
            )

    if issues:
        sys.stderr.write(f"FAIL: {source}\n")
        for issue in issues:
            sys.stderr.write(f"  {issue}\n")
        return 1

    print(f"OK: {source}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
