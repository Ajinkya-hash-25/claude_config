#!/usr/bin/env python3
"""Small prompt benchmark for org Claude config."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class Task:
    name: str
    kind: str
    prompt: str
    expected: str


TASKS = [
    Task("explore service", "explore", "Find auth login flow and key dependencies.", "graph first, file refs"),
    Task("reuse check", "reuse", "Before adding CSV export, find existing export helpers.", "reuse verdict"),
    Task("bug debug", "debug", "Trace why payment retry can double charge.", "call chain + risk"),
    Task("code review", "review", "Review current branch for bugs only.", "findings + verdict"),
    Task("test cases", "test", "Generate test cases for report generation service.", "case matrix"),
    Task("spring scaffold", "scaffold", "Scaffold Spring Boot CRUD for Invoice.", "compile-safe skeleton"),
    Task("go scaffold", "scaffold", "Scaffold Go handler/service/model for invoice.", "compile-safe skeleton"),
    Task("security audit", "security", "Audit new webhook endpoint for OWASP risks.", "ranked findings"),
    Task("pr gen", "docs", "Generate PR title and description from branch diff.", "PR markdown"),
    Task("flow diagram", "diagram", "Create flowchart for refund processing function.", "board/mermaid output"),
]


def est_tokens(text: str) -> int:
    return max(1, round(len(text) / 4))


def load_context() -> str:
    parts = []
    for rel in ("AGENTS.md", "CLAUDE.md", "settings.json", "mcp.json"):
        path = ROOT / rel
        if path.exists():
            parts.append(path.read_text(encoding="utf-8", errors="ignore"))
    return "\n".join(parts)


def run_claude(prompt: str, timeout: int) -> dict[str, object]:
    if not shutil.which("claude"):
        return {"error": "claude not on PATH"}
    proc = subprocess.run(
        ["claude", "-p", prompt, "--output-format", "json", "--allowedTools", "none"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )
    raw = proc.stdout or proc.stderr
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        data = {"error": raw.strip()[:500]}
    data["returncode"] = proc.returncode
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark prompt/context token footprint.")
    parser.add_argument("--run", action="store_true", help="Call claude for each task.")
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--out", default="prompt-bench.md")
    args = parser.parse_args()

    context = load_context()
    rows = []
    total_prompt_tokens = 0

    for task in TASKS:
        prompt = f"{context}\n\nTask: {task.prompt}\nReturn best next action only."
        prompt_tokens = est_tokens(prompt)
        total_prompt_tokens += prompt_tokens
        result = {}
        if args.run:
            result = run_claude(prompt, args.timeout)
        usage = result.get("usage", {}) if isinstance(result, dict) else {}
        rows.append(
            {
                "name": task.name,
                "kind": task.kind,
                "est_tokens": prompt_tokens,
                "input_tokens": usage.get("input_tokens", ""),
                "output_tokens": usage.get("output_tokens", ""),
                "expected": task.expected,
                "error": result.get("error", "") if isinstance(result, dict) else "",
            }
        )

    report = [
        "# Prompt Bench",
        "",
        f"- Tasks: {len(TASKS)}",
        f"- Estimated prompt tokens: {total_prompt_tokens}",
        f"- Mode: {'run' if args.run else 'dry-run'}",
        "",
        "| Task | Kind | Est Tokens | Input | Output | Expected | Error |",
        "|---|---:|---:|---:|---:|---|---|",
    ]
    for row in rows:
        report.append(
            "| {name} | {kind} | {est_tokens} | {input_tokens} | {output_tokens} | {expected} | {error} |".format(
                **row
            )
        )
    report.append("")
    report.append("Use this before/after prompt changes. Lower est/input tokens with same expected output = better.")

    out = ROOT / args.out
    out.write_text("\n".join(report) + "\n", encoding="utf-8")
    print(f"Wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
