#!/bin/bash
# Org Claude Config — Uninstall Script
# Removes symlinks created by install.sh
# Removes all symlinks and .bak files created by install.sh

set -e

G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
B='\033[1m'
X='\033[0m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
GIT_HOOKS_DIR="$HOME/.git-hooks"

removed=0

remove_entry() {
    local path="$1" label="$2"
    if [ -L "$path" ]; then
        rm "$path"
        echo -e "  ${G}✔ removed symlink${X} $label"
        removed=$((removed + 1))
    elif [ -d "$path" ]; then
        rm -rf "$path"
        echo -e "  ${G}✔ removed dir${X} $label"
        removed=$((removed + 1))
    elif [ -f "$path" ]; then
        rm "$path"
        echo -e "  ${G}✔ removed file${X} $label"
        removed=$((removed + 1))
    fi
}

echo -e "${B}${C}── Claude Config ────────────────────────────${X}\n"

for skill_dir in "$REPO_DIR/skills"/*/; do
    name=$(basename "${skill_dir%/}")
    remove_entry "$CLAUDE_DIR/skills/$name" "skills/$name"
done

for agent_file in "$REPO_DIR/agents"/*.md; do
    remove_entry "$CLAUDE_DIR/agents/$(basename "$agent_file")" "agents/$(basename "$agent_file")"
done

for cmd_file in "$REPO_DIR/commands"/*.md; do
    remove_entry "$CLAUDE_DIR/commands/$(basename "$cmd_file")" "commands/$(basename "$cmd_file")"
done

echo -e "\n${B}${C}── Git Hooks ────────────────────────────────${X}\n"

for hook in pre-push pr-review.sh; do
    remove_entry "$GIT_HOOKS_DIR/$hook" "~/.git-hooks/$hook"
done

_hooks_path="$(git config --global core.hooksPath 2>/dev/null || true)"
if [ "$_hooks_path" = "$GIT_HOOKS_DIR" ]; then
    git config --global --unset core.hooksPath
    echo -e "  ${G}✔ unset${X} core.hooksPath"
fi

remove_entry "$CLAUDE_DIR/CLAUDE.md" "CLAUDE.md"
remove_entry "$CLAUDE_DIR/settings.json" "settings.json"

for std_file in "$REPO_DIR/standards"/*.md; do
    remove_entry "$CLAUDE_DIR/standards/$(basename "$std_file")" "standards/$(basename "$std_file")"
done

echo -e "\n  ${B}Cleaning up .bak files:${X}"
for bak in "$CLAUDE_DIR/CLAUDE.md.bak" "$CLAUDE_DIR/settings.json.bak"; do
    [ -f "$bak" ] && rm "$bak" && echo -e "  ${G}✔ removed${X} $(basename "$bak")" || true
done

echo -e "\n${G}${B}✔ Uninstalled $removed entries.${X}\n"
