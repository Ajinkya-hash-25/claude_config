#!/usr/bin/env python3
"""
Statusline token summary for Claude Code.
Reads the current session's JSONL log and prints a single-line summary.

Output format:  [in:18k hit:16.9M out:153k]

Called by Claude Code statusLine command via:
  powershell -Command "... | python statusline_tokens.py"
The session JSON is piped to stdin.
"""

import json
import sys
import os
from pathlib import Path
from collections import defaultdict


def fmt(n: int) -> str:
    """Format a token count as a compact human-readable string."""
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.0f}k"
    return str(n)


def main() -> None:
    # --- Read JSON input from stdin ---
    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw.strip() else {}
    except Exception:
        data = {}

    session_id: str = data.get("session_id", "")

    # --- Locate the JSONL file for this session ---
    # Try cwd-derived project slug first, then fall back to scanning all projects.
    home = Path.home()
    projects_root = home / ".claude" / "projects"

    jsonl_path: Path | None = None

    if session_id:
        # cwd from stdin gives us the active project directory
        cwd = data.get("cwd") or data.get("workspace", {}).get("current_dir", "")
        if cwd:
            # Convert path to Claude slug (replace path separators & colons with -)
            slug = cwd.replace("\\", "/").replace(":", "").replace("/", "-").lstrip("-")
            candidate = projects_root / slug / f"{session_id}.jsonl"
            if candidate.exists():
                jsonl_path = candidate

        # Fallback: search all project directories
        if jsonl_path is None:
            for f in projects_root.rglob(f"{session_id}.jsonl"):
                jsonl_path = f
                break

    # --- Parse the JSONL for token usage ---
    totals: defaultdict[str, int] = defaultdict(int)

    if jsonl_path and jsonl_path.exists():
        try:
            with open(jsonl_path, encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    try:
                        obj = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    usage = obj.get("usage") or obj.get("message", {}).get("usage", {})
                    if usage:
                        totals["input"]        += usage.get("input_tokens", 0)
                        totals["cache_read"]   += usage.get("cache_read_input_tokens", 0)
                        totals["cache_create"] += usage.get("cache_creation_input_tokens", 0)
                        totals["output"]       += usage.get("output_tokens", 0)
        except Exception:
            pass

    # Also use the pre-calculated context_window values from stdin as a cross-check
    # (prefer JSONL totals; only fall back to stdin values when JSONL has nothing)
    if sum(totals.values()) == 0:
        ctx = data.get("context_window", {})
        totals["input"]  = ctx.get("total_input_tokens", 0)
        totals["output"] = ctx.get("total_output_tokens", 0)

    inp   = totals["input"]
    hit   = totals["cache_read"]
    new_  = totals["cache_create"]
    out   = totals["output"]

    # Build the compact summary line
    parts = []
    if inp:
        parts.append(f"in:{fmt(inp)}")
    if hit:
        parts.append(f"hit:{fmt(hit)}")
    if new_:
        parts.append(f"new:{fmt(new_)}")
    if out:
        parts.append(f"out:{fmt(out)}")

    if parts:
        print(f"[{' '.join(parts)}]")
    # Print nothing if no tokens yet — statusline stays clean at session start


if __name__ == "__main__":
    main()
