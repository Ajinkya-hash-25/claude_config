#!/bin/bash
# PR review guardrail.
# Modes:
#   PR_REVIEW_MODE=block  hard-block on bugs/high risk/no verdict (default)
#   PR_REVIEW_MODE=warn   never block; print findings
#   PR_REVIEW_MODE=off    skip review
# Providers:
#   PR_REVIEW_LLM=auto    use codex if installed, else claude (default)
#   PR_REVIEW_LLM=codex   use Codex CLI
#   PR_REVIEW_LLM=claude  use Claude CLI

set -euo pipefail

MODE="${PR_REVIEW_MODE:-block}"
LLM="${PR_REVIEW_LLM:-auto}"
MAX_DIFF_LINES="${PR_REVIEW_MAX_DIFF_LINES:-500}"
MAX_FILES="${PR_REVIEW_MAX_FILES:-30}"
CHANGES_FILE="${PR_REVIEW_LOG:-changes.md}"

if [ "$MODE" = "off" ]; then
    echo "PR review disabled (PR_REVIEW_MODE=off)."
    exit 0
fi

if [ -t 2 ]; then
    read -r -p "Run PR review? [Y/n] " _REPLY < /dev/tty || true
    _REPLY="${_REPLY:-Y}"
    if [[ "$_REPLY" =~ ^[Nn] ]]; then
        echo "PR review skipped. Pushing."
        exit 0
    fi
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

pick_llm() {
    case "${1:-auto}" in
        auto)
            if command -v codex >/dev/null 2>&1; then
                echo "codex"
                return
            fi
            if command -v claude >/dev/null 2>&1; then
                echo "claude"
                return
            fi
            echo "none"
            ;;
        codex|claude)
            if command -v "$1" >/dev/null 2>&1; then
                echo "$1"
            else
                echo "none"
            fi
            ;;
        *)
            echo "invalid"
            ;;
    esac
}

run_review() {
    local provider="$1"
    local prompt="$2"
    local diff="$3"
    local tmp_err
    tmp_err="$(mktemp)"

    _start_spin
    case "$provider" in
        codex)
            RESULT="$(printf '%s\n\n%s' "$prompt" "$diff" | codex exec --sandbox read-only - 2>"$tmp_err" || true)"
            ;;
        claude)
            RESULT="$(claude -p "${prompt}"$'\n\n'"${diff}" --output-format json --allowedTools none --model claude-haiku-4-5-20251001 2>"$tmp_err" || true)"
            ;;
    esac
    _stop_spin

    if [ -z "$RESULT" ] && [ -s "$tmp_err" ]; then
        echo -e "${R}${provider} error:${X}" >&2
        cat "$tmp_err" >&2
    fi
    rm -f "$tmp_err"
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

_SPIN_PID=""
_start_spin() {
    [ -t 2 ] || return 0
    local chars='|/-\' i=0
    while true; do
        printf "\r  \033[0;36mReviewing... %s\033[0m" "${chars:$((i % 4)):1}" >&2
        i=$((i + 1))
        sleep 0.12
    done &
    _SPIN_PID=$!
}
_stop_spin() {
    [ -n "$_SPIN_PID" ] || return 0
    kill "$_SPIN_PID" 2>/dev/null || true
    wait "$_SPIN_PID" 2>/dev/null || true
    printf "\r%-40s\r" "" >&2
    _SPIN_PID=""
}

PROVIDER="$(pick_llm "$LLM")"
if [ "$PROVIDER" = "invalid" ]; then
    echo -e "${R}Invalid PR_REVIEW_LLM=$LLM. Use auto, codex, or claude.${X}"
    exit 1
fi

echo -e "\n${B}${C}PR REVIEW SYSTEM${X}"
echo -e "${C}branch:${X} $BRANCH ${C}base:${X} $BASE ${C}mode:${X} $MODE ${C}llm:${X} $LLM\n"

CHANGED="$(git diff "$BASE"...HEAD --name-only --diff-filter=ACMRT 2>/dev/null || true)"
if [ "$CHANGED" = "" ]; then
    echo -e "${G}No changes. Nothing to review.${X}\n"
    exit 0
fi

# Filter out files that should never be reviewed:
# - gitignored files that are tracked (lock files, generated assets, etc.)
# - known secret/credential file patterns
# - dependency trees
CHANGED="$(echo "$CHANGED" | grep -vE \
    -e '^node_modules/' \
    -e '^vendor/' \
    -e '^\.yarn/' \
    -e '^dist/' \
    -e '^build/' \
    -e '^\.next/' \
    -e '^coverage/' \
    -e 'package-lock\.json$' \
    -e 'yarn\.lock$' \
    -e 'pnpm-lock\.yaml$' \
    -e 'go\.sum$' \
    -e 'Gemfile\.lock$' \
    -e 'composer\.lock$' \
    -e '\.min\.(js|css)$' \
    -e '\.(pem|key|p12|pfx|cer|crt)$' \
    -e '(^|/)credentials\.json$' \
    -e '(^|/)service-account.*\.json$' \
    -e '(^|\.)env(\.|$)' \
    || true)"

if [ "$CHANGED" = "" ]; then
    echo -e "${G}No reviewable changes after filtering noise/secret files.${X}\n"
    exit 0
fi

FILE_COUNT="$(echo "$CHANGED" | sed '/^$/d' | wc -l | tr -d ' ')"
if [ "$FILE_COUNT" -gt "$MAX_FILES" ]; then
    echo -e "${Y}Changed files: $FILE_COUNT. Reviewing first $MAX_FILES by diff order.${X}"
    CHANGED="$(echo "$CHANGED" | head -n "$MAX_FILES")"
fi

BLOCK=0

section_head "$(echo "$PROVIDER" | tr '[:lower:]' '[:upper:]') REVIEW"

DIFF="$(
    git diff "$BASE"...HEAD --no-ext-diff --unified=3 -- $CHANGED 2>/dev/null \
        | redact_secrets \
        | truncate_lines "$MAX_DIFF_LINES"
)"

PROMPT="$(cat <<'PROMPTEOF'
You are a code reviewer. Caveman mode: terse fragments, no filler.
Diff below. List ONLY lines that must be fixed before merge.
Skip style, skip praise, skip explanation of what code does.

Format (one line per issue):
file:LINE: [bug|risk|sec]: what breaks. how to fix.

If nothing to fix, output exactly: APPROVE
Else output findings then exactly: REQUEST CHANGES
PROMPTEOF
)"

RESULT=""
TOKENS_IN="?"
TOKENS_OUT="?"
if [ "$PROVIDER" = "none" ]; then
    echo -e "${Y}No supported LLM CLI found; install codex or claude, or set PR_REVIEW_LLM.${X}"
    REVIEW="REQUEST CHANGES - no supported LLM CLI found; review skipped."
    TOKENS_IN="?"
    TOKENS_OUT="?"
else
    run_review "$PROVIDER" "$PROMPT" "$DIFF"
    if [ "$PROVIDER" = "claude" ]; then
        REVIEW="$(echo "$RESULT" | json_field "result")"
        TOKENS_IN="$(echo "$RESULT" | json_field "usage.input_tokens")"
        TOKENS_OUT="$(echo "$RESULT" | json_field "usage.output_tokens")"
    else
        REVIEW="$RESULT"
    fi
    TOKENS_IN="${TOKENS_IN:-?}"
    TOKENS_OUT="${TOKENS_OUT:-?}"
fi

section_head "REVIEW RESULT"
echo -e "$REVIEW"
echo -e "${C}Tokens - in: ${TOKENS_IN} out: ${TOKENS_OUT}${X}"
sep

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
cat >> "$CHANGES_FILE" <<MDEOF

---

## PR Review - $TIMESTAMP
**Branch:** \`$BRANCH\` -> \`$BASE\`
**LLM:** \`$PROVIDER\`
**Tokens:** in=${TOKENS_IN} out=${TOKENS_OUT}

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
    echo -e "${Y}$PROVIDER requested changes.${X}"
    BLOCK=1
fi

if [ "$MODE" = "warn" ]; then
    echo -e "${Y}Warn mode: push not blocked.${X}"
    exit 0
fi

if [ "$BLOCK" -eq 1 ]; then
    echo -e "${R}Push blocked.${X}"
else
    echo -e "${G}Approved.${X}"
fi

if [ "$BLOCK" -eq 1 ] && [ -t 2 ]; then
    read -r -p "$(echo -e "Push anyway? [y/N] ")" _FORCE < /dev/tty || true
    if [[ "${_FORCE:-N}" =~ ^[yY] ]]; then
        echo -e "${Y}Force push confirmed — pushing.${X}"
        exit 0
    fi
fi

if [ "$BLOCK" -eq 1 ]; then
    echo -e "${R}Aborted. Fix issues or set PR_REVIEW_MODE=warn/off.${X}"
    exit 1
fi

echo -e "${G}Pushing.${X}"
exit 0
