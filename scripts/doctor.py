#!/usr/bin/env python3
"""Validate org Claude config install health."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run(cmd: list[str], timeout: int = 10) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            cmd,
            cwd=ROOT,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
        return proc.returncode, (proc.stdout + proc.stderr).strip()
    except Exception as exc:
        return 1, str(exc)


def ok(label: str, detail: str = "") -> tuple[str, str, str]:
    return ("OK", label, detail)


def warn(label: str, detail: str = "") -> tuple[str, str, str]:
    return ("WARN", label, detail)


def fail(label: str, detail: str = "") -> tuple[str, str, str]:
    return ("FAIL", label, detail)


def json_check(path: Path) -> tuple[str, str, str]:
    try:
        json.loads(path.read_text(encoding="utf-8"))
        return ok(path.name, "valid JSON")
    except Exception as exc:
        return fail(path.name, str(exc))


def has_crlf(path: Path) -> bool:
    return b"\r\n" in path.read_bytes()


def main() -> int:
    parser = argparse.ArgumentParser(description="Check org Claude config health.")
    parser.add_argument("--deep", action="store_true", help="Run slower external checks.")
    args = parser.parse_args()

    checks: list[tuple[str, str, str]] = []

    checks.append(ok("repo", str(ROOT)))
    checks.append(ok("python", sys.version.split()[0]))

    for name in ("git", "python", "python3", "bash", "claude", "uvx"):
        found = shutil.which(name)
        if found:
            if name == "bash":
                code, out = run([found, "--version"], timeout=5)
                if code == 0:
                    checks.append(ok(name, found))
                else:
                    checks.append(warn(name, f"found but unusable: {out[:120]}"))
            else:
                checks.append(ok(name, found))
        elif name in {"claude", "uvx", "bash", "python3"}:
            checks.append(warn(name, "not on PATH"))
        else:
            checks.append(fail(name, "not on PATH"))

    for rel in ("settings.json", "mcp.json"):
        checks.append(json_check(ROOT / rel))

    settings = json.loads((ROOT / "settings.json").read_text(encoding="utf-8"))
    hooks = settings.get("hooks", {})
    post = hooks.get("PostToolUse", [])
    matchers = [item.get("matcher", "") for item in post if isinstance(item, dict)]
    if any("Bash" in matcher for matcher in matchers):
        checks.append(fail("settings hooks", "PostToolUse updates graph on Bash"))
    else:
        checks.append(ok("settings hooks", "no Bash graph-update hook"))

    attrs = ROOT / ".gitattributes"
    if attrs.exists() and "*.sh text eol=lf" in attrs.read_text(encoding="utf-8"):
        checks.append(ok(".gitattributes", "shell scripts forced LF"))
    else:
        checks.append(fail(".gitattributes", "missing '*.sh text eol=lf'"))

    for rel in ("scripts/pre-push", "scripts/pr-review.sh", "install.sh", "uninstall.sh"):
        path = ROOT / rel
        if not path.exists():
            checks.append(fail(rel, "missing"))
        elif has_crlf(path):
            checks.append(fail(rel, "CRLF line endings"))
        else:
            checks.append(ok(rel, "LF line endings"))

    if (ROOT / "scripts/pre-push").exists() and (ROOT / "scripts/pr-review.sh").exists():
        checks.append(ok("pre-push path", "repo scripts present"))

    if args.deep:
        code, out = run(["git", "rev-parse", "--is-inside-work-tree"])
        checks.append(ok("git repo", out) if code == 0 else fail("git repo", out))

        if shutil.which("uvx"):
            code, out = run(["uvx", "code-review-graph", "--version"], timeout=30)
            checks.append(ok("code-review-graph", out) if code == 0 else warn("code-review-graph", out))
            code, out = run(["uvx", "code-review-graph", "status"], timeout=30)
            checks.append(ok("graph status", out[:300]) if code == 0 else warn("graph status", out[:300]))

    width = max(len(label) for _, label, _ in checks)
    for status, label, detail in checks:
        print(f"{status:4} {label:<{width}} {detail}")

    fails = [item for item in checks if item[0] == "FAIL"]
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
