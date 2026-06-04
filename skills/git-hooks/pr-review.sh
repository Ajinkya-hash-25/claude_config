#!/bin/bash
# PR review guardrail.
# Modes:
#   PR_REVIEW_MODE=block  hard-block on bugs/high risk/no verdict (default)
#   PR_REVIEW_MODE=warn   never block; print findings
#   PR_REVIEW_MODE=off    skip review

set -euo pipefail

MODE="${PR_REVIEW_MODE:-block}"
MAX_DIFF_LINES="${PR_REVIEW_MAX_DIFF_LINES:-500}"
MAX_FILES="${PR_REVIEW_MAX_FILES:-30}"
CHANGES_FILE="${PR_REVIEW_LOG:-changes.md}"

if [ "$MODE" = "off" ]; then
    echo "PR review disabled (PR_REVIEW_MODE=off)."
    exit 0
fi

pick_base() {
    if [ "${1:-}" != "" ]; then
        echo "$1"
        return
    fi

    local upstream
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
    if [ "$upstream" != "" ]; then
        echo "$upstream"
        return
    fi

    if git rev-parse --verify origin/main >/dev/null 2>&1; then
        echo "origin/main"
        return
    fi

    if git rev-parse --verify origin/master >/dev/null 2>&1; then
        echo "origin/master"
        return
    fi

    echo "HEAD~1"
}

redact_secrets() {
    sed -E \
        -e 's/((api[_-]?key|token|secret|password|passwd|pwd)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig' \
        -e 's/(Bearer )[A-Za-z0-9._~+\/=-]+/\1[REDACTED]/g' \
        -e 's/(-----BEGIN [^-]+PRIVATE KEY-----).*(-----END [^-]+PRIVATE KEY-----)/\1[REDACTED]\2/g'
}

truncate_lines() {
    local limit="$1"
    awk -v max="$limit" 'NR <= max { print } END { if (NR > max) print "\n[TRUNCATED: " NR-max " lines omitted]" }'
}

json_field() {
    python3 -c 'import json,sys
cur=json.load(sys.stdin)
for k in sys.argv[1].split("."):
    cur = cur.get(k, {}) if isinstance(cur, dict) else {}
print("" if cur in ({}, None) else cur)' "$1" 2>/dev/null || true
}

BASE="$(pick_base "${1:-}")"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

R='\033[0;31m'
Y='\033[1;33m'
G='\033[0;32m'
C='\033[0;36m'
B='\033[1m'
X='\033[0m'

sep() { echo -e "${C}------------------------------------------${X}"; }
section_head() { echo -e "\n${B}${C}  $1${X}"; sep; }

echo -e "\n${B}${C}PR REVIEW SYSTEM${X}"
echo -e "${C}branch:${X} $BRANCH ${C}base:${X} $BASE ${C}mode:${X} $MODE\n"

CHANGED="$(git diff "$BASE"...HEAD --name-only --diff-filter=ACMRT 2>/dev/null || true)"
if [ "$CHANGED" = "" ]; then
    echo -e "${G}No changes. Nothing to review.${X}\n"
    exit 0
fi

FILE_COUNT="$(echo "$CHANGED" | sed '/^$/d' | wc -l | tr -d ' ')"
if [ "$FILE_COUNT" -gt "$MAX_FILES" ]; then
    echo -e "${Y}Changed files: $FILE_COUNT. Reviewing first $MAX_FILES by diff order.${X}"
    CHANGED="$(echo "$CHANGED" | head -n "$MAX_FILES")"
fi

BLOCK=0
RISK="unknown"

section_head "RISK ANALYSIS"
if command -v uvx >/dev/null 2>&1 && uvx code-review-graph --version >/dev/null 2>&1; then
    echo -e "${Y}Updating graph...${X}"
    uvx code-review-graph build --repo . >/dev/null 2>&1 || true
    GRAPH="$(uvx code-review-graph detect-changes --base "$BASE" 2>&1 || true)"
    RISK="$(echo "$GRAPH" | json_field "risk_score")"
    RISK="${RISK:-unknown}"
    echo -e "Risk score: $RISK"
    if awk "BEGIN{exit !(\"$RISK\"+0 >= 0.7)}" 2>/dev/null; then
        echo -e "${R}High risk score: $RISK${X}"
        BLOCK=1
    fi
else
    echo -e "${Y}uvx code-review-graph not found; skipping risk.${X}"
    GRAPH="Not available."
fi

section_head "CLAUDE REVIEW"

DIFF="$(
    git diff "$BASE"...HEAD --no-ext-diff --unified=80 -- $CHANGED 2>/dev/null \
        | redact_secrets \
        | truncate_lines "$MAX_DIFF_LINES"
)"

CONTEXT="$(cat <<CTXEOF
=== GRAPH ANALYSIS ===
$GRAPH

=== GIT DIFF (redacted, capped at $MAX_DIFF_LINES lines) ===
$DIFF
CTXEOF
)"

PROMPT="$(cat <<'PROMPTEOF'
Review ONLY changed lines. Output terse actionable findings.
Format: file:Lline: severity: problem. fix.
Severity: bug, risk, nit, q.
Security findings: explain enough to act safely.
End with exactly:
APPROVE
or
REQUEST CHANGES - one line why.
PROMPTEOF
)"

if ! command -v claude >/dev/null 2>&1; then
    echo -e "${Y}claude CLI not found; skipping AI review.${X}"
    REVIEW="REQUEST CHANGES - claude CLI missing; review skipped."
    TOKENS_IN="?"
    TOKENS_OUT="?"
else
    RESULT="$(printf '%s' "$CONTEXT" | claude -p "$PROMPT" --output-format json --allowedTools none 2>&1 || true)"
    REVIEW="$(echo "$RESULT" | json_field "result")"
    TOKENS_IN="$(echo "$RESULT" | json_field "usage.input_tokens")"
    TOKENS_OUT="$(echo "$RESULT" | json_field "usage.output_tokens")"
    TOKENS_IN="${TOKENS_IN:-?}"
    TOKENS_OUT="${TOKENS_OUT:-?}"
fi

echo -e "$REVIEW"
echo -e "${C}Tokens - in: ${TOKENS_IN} out: ${TOKENS_OUT}${X}"
sep

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
cat >> "$CHANGES_FILE" <<MDEOF

---

## PR Review - $TIMESTAMP
**Branch:** \`$BRANCH\` -> \`$BASE\`
**Risk Score:** ${RISK}
**Tokens:** in=${TOKENS_IN} out=${TOKENS_OUT}
**Diff cap:** ${MAX_DIFF_LINES} lines

### Changed Files
\`\`\`
$CHANGED
\`\`\`

### Review
$REVIEW

MDEOF
echo -e "${G}Review saved to $CHANGES_FILE${X}"

if echo "$REVIEW" | grep -qiE '(^|[[:space:]])bug:'; then
    echo -e "${R}Bug found.${X}"
    BLOCK=1
fi

VERDICT="$(echo "$REVIEW" | tail -5 | grep -iE '^(APPROVE|REQUEST CHANGES)' || true)"
if [ "$VERDICT" = "" ]; then
    echo -e "${R}No verdict detected.${X}"
    BLOCK=1
elif echo "$VERDICT" | grep -qi '^REQUEST CHANGES'; then
    echo -e "${Y}Claude requested changes.${X}"
    BLOCK=1
fi

if [ "$MODE" = "warn" ]; then
    echo -e "${Y}Warn mode: push not blocked.${X}"
    exit 0
fi

if [ "$BLOCK" -eq 1 ]; then
    echo -e "${R}Push blocked. Fix issues or set PR_REVIEW_MODE=warn/off.${X}"
    exit 1
fi

echo -e "${G}Approved - pushing.${X}"
exit 0
