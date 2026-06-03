#!/bin/bash
# Install org git hooks into the current repo's .git/hooks/
# Run from the root of any project repo.

set -e

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
B='\033[1m'
X='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$(git rev-parse --git-dir 2>/dev/null)/hooks"

if [ -z "$HOOKS_DIR" ] || [ "$HOOKS_DIR" = "/hooks" ]; then
    echo -e "${R}❌ Not inside a git repository. Run from project root.${X}"
    exit 1
fi

echo -e "\n${B}${C}Installing org git hooks into${X} ${HOOKS_DIR}\n"

install_hook() {
    local name="$1"
    local src="$SCRIPT_DIR/$name"

    if [ ! -f "$src" ]; then
        echo -e "  ${Y}⚠ $name not found at $src — skipping${X}"
        return
    fi

    local dest="$HOOKS_DIR/$name"

    if [ -f "$dest" ] && [ ! -L "$dest" ]; then
        echo -e "  ${Y}⚠ $name already exists (not a symlink) — backing up to $name.bak${X}"
        mv "$dest" "${dest}.bak"
    fi

    ln -sf "$src" "$dest"
    chmod +x "$src"
    echo -e "  ${G}✔ $name${X} → $dest"
}

install_hook "pre-push"
install_hook "commit-msg"

echo -e "\n${G}${B}✔ Git hooks installed.${X}"
echo -e "  pre-push  — Claude code review + risk score on every push"
echo -e "  commit-msg — conventional commit format validation\n"
echo -e "${C}To uninstall:${X} rm ${HOOKS_DIR}/pre-push ${HOOKS_DIR}/commit-msg\n"
