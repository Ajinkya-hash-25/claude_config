#!/bin/bash
BASE=${1:-$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)}
if [ -z "$BASE" ]; then BASE="origin/master"; fi
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Colors
R='\033[0;31m'  # red
Y='\033[1;33m'  # yellow
G='\033[0;32m'  # green
C='\033[0;36m'  # cyan
B='\033[1m'     # bold
X='\033[0m'     # reset

sep()  { echo -e "${C}──────────────────────────────────────────${X}"; }
section_head() { echo -e "\n${B}${C}  $1${X}"; sep; }

echo -e "\n${B}${C}╔══════════════════════════════════════════╗${X}"
echo -e "${B}${C}║           PR REVIEW SYSTEM               ║${X}"
echo -e "${B}${C}║  ${Y}branch:${X}${B} $BRANCH ${C}→ ${Y}base:${X}${B} $BASE${X}"
echo -e "${B}${C}╚══════════════════════════════════════════╝${X}\n"

# Check for committed unpushed changes
CHANGED=$(git diff "$BASE"...HEAD --name-only 2>/dev/null)
if [ -z "$CHANGED" ]; then
    echo -e "${G}  ✔ No unpushed changes. Nothing to review.${X}\n"
    exit 0
fi

BLOCK=0

# ── Risk Analysis ──────────────────────────────────────────
section_head "RISK ANALYSIS"
if command -v uvx >/dev/null 2>&1 && uvx code-review-graph --version >/dev/null 2>&1; then
    echo -e "${Y}  Updating graph...${X}"
    uvx code-review-graph build --repo . >/dev/null 2>&1
    GRAPH=$(uvx code-review-graph detect-changes --base "$BASE" 2>&1)
    RISK=$(echo "$GRAPH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('risk_score',0))" 2>/dev/null)
    echo -e "  Risk score: ${RISK:-unknown}"
    if awk "BEGIN{exit !(${RISK:-0} >= 0.7)}"; then
        echo -e "\n${R}  ⚠ HIGH risk score: $RISK — push blocked${X}"
        BLOCK=1
    fi
else
    echo -e "${Y}  uvx code-review-graph not found, skipping.${X}"
    GRAPH="Not available."
fi

# ── Claude Review ──────────────────────────────────────────
section_head "CLAUDE REVIEW"

# Combine graph analysis + actual diff of changed functions only
DIFF=$(git diff "$BASE"...HEAD 2>/dev/null)

CONTEXT=$(cat <<CTXEOF
=== GRAPH ANALYSIS (risk, blast radius, affected flows, test gaps) ===
$GRAPH

=== GIT DIFF (changed lines only) ===
$DIFF
CTXEOF
)

# Inlined caveman-review skill body — portable across machines (no external path)
SKILL_BODY=$(cat <<'SKILLEOF'
Write code review comments terse and actionable. One line per finding. Location, problem, fix. No throat-clearing.

## Rules

**Format:** `L<line>: <problem>. <fix>.` — or `<file>:L<line>: ...` when reviewing multi-file diffs.

**Severity prefix (optional, when mixed):**
- `🔴 bug:` — broken behavior, will cause incident
- `🟡 risk:` — works but fragile (race, missing null check, swallowed error)
- `🔵 nit:` — style, naming, micro-optim. Author can ignore
- `❓ q:` — genuine question, not a suggestion

**Drop:**
- "I noticed that...", "It seems like...", "You might want to consider..."
- "This is just a suggestion but..." — use `nit:` instead
- "Great work!", "Looks good overall but..." — say it once at the top, not per comment
- Restating what the line does — the reviewer can read the diff
- Hedging ("perhaps", "maybe", "I think") — if unsure use `q:`

**Keep:**
- Exact line numbers
- Exact symbol/function/variable names in backticks
- Concrete fix, not "consider refactoring this"
- The *why* if the fix isn't obvious from the problem statement

## Examples

❌ "I noticed that on line 42 you're not checking if the user object is null before accessing the email property..."
✅ `L42: 🔴 bug: user can be null after .find(). Add guard before .email.`

❌ "It looks like this function is doing a lot of things..."
✅ `L88-140: 🔵 nit: 50-line fn does 4 things. Extract validate/normalize/persist.`

❌ "Have you considered what happens if the API returns a 429?"
✅ `L23: 🟡 risk: no retry on 429. Wrap in withBackoff(3).`

## Auto-Clarity

Drop terse mode for: security findings (CVE-class bugs need full explanation + reference), architectural disagreements (need rationale), and onboarding contexts. In those cases write a normal paragraph, then resume terse.

## Boundaries

Reviews only — does not write code fix, does not approve/request-changes, does not run linters. Output comments ready to paste into PR.
SKILLEOF
)

PROMPT=$(cat <<EOF
Input: graph analysis (risk, blast radius, affected flows, test gaps) + git diff. Review ONLY changed lines. Java, SQL, config, YAML — all file types.

${SKILL_BODY}

End with one of:
APPROVE
REQUEST CHANGES - one line why.
EOF
)

RESULT=$(echo "$CONTEXT" | claude -p "$PROMPT" --output-format json --allowedTools none 2>&1)
REVIEW=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',''))" 2>/dev/null)
TOKENS_IN=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('usage',{}).get('input_tokens','?'))" 2>/dev/null)
TOKENS_OUT=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('usage',{}).get('output_tokens','?'))" 2>/dev/null)

echo -e "$REVIEW"
echo -e "  ${C}Tokens — in: ${TOKENS_IN} out: ${TOKENS_OUT}${X}"
sep

# ── Dump to changes.md ─────────────────────────────────────
CHANGES_FILE="changes.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
cat >> "$CHANGES_FILE" <<MDEOF

---

## PR Review — $TIMESTAMP
**Branch:** \`$BRANCH\` → \`$BASE\`
**Risk Score:** ${RISK:-unknown}
**Tokens:** in=${TOKENS_IN} out=${TOKENS_OUT}

### Changed Files
\`\`\`
$CHANGED
\`\`\`

### Review
$REVIEW

MDEOF
echo -e "  ${G}Review saved to $CHANGES_FILE${X}"

# ── Decision ───────────────────────────────────────────────
# caveman-review uses 🔴 bug: (not [CRITICAL]) — block on red bugs
if echo "$REVIEW" | grep -qE '🔴 bug:'; then
    echo -e "\n${R}  🚫 Bug found — push blocked.${X}\n"
    BLOCK=1
fi

if [ $BLOCK -eq 1 ]; then
    echo -e "${R}  ❌ Fix issues above and retry push.${X}\n"
    exit 1
fi

# caveman-review verdict is last line: "APPROVE" or "REQUEST CHANGES - ..."
VERDICT=$(echo "$REVIEW" | tail -3 | grep -iE 'APPROVE|REQUEST CHANGES')
if [ -z "$VERDICT" ]; then
    echo -e "\n${R}  ⚠ No verdict detected — blocking push as safety default.${X}\n"
    exit 1
elif echo "$VERDICT" | grep -qi "REQUEST CHANGES"; then
    echo -e "\n${Y}  ⚠ Claude requested changes.${X}"
    echo -e "${B}  Push anyway? (y/n): ${X}\c"
    read -r REPLY </dev/tty
    [[ "$REPLY" =~ ^[Yy]$ ]] && echo -e "${G}  Pushing...${X}\n" || { echo -e "${R}  Aborted.${X}\n"; exit 1; }
elif echo "$VERDICT" | grep -qi "APPROVE"; then
    echo -e "\n${G}  ✔ Approved — pushing.${X}\n"
fi

exit 0
