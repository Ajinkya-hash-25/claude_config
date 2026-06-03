#!/bin/bash
# Org Claude Config — Uninstall Script
# Removes symlinks created by install.sh
# Does NOT touch ~/.claude/CLAUDE.md or ~/.claude/settings.json

set -e

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
B='\033[1m'
X='\033[0m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo -e "\n${B}${C}── Uninstalling Org Claude Config ──────────${X}\n"

removed=0

remove_symlink() {
    local path="$1"
    local label="$2"
    if [ -L "$path" ]; then
        rm "$path"
        echo -e "  ${G}✔ removed${X} $label"
        removed=$((removed + 1))
    fi
}

# Remove skill symlinks
for skill_dir in "$REPO_DIR/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    remove_symlink "$CLAUDE_DIR/skills/$skill_name" "skills/$skill_name"
done

# Remove agent symlinks
for agent_file in "$REPO_DIR/agents"/*.md; do
    agent_name=$(basename "$agent_file")
    remove_symlink "$CLAUDE_DIR/agents/$agent_name" "agents/$agent_name"
done

# Remove command symlinks
for cmd_file in "$REPO_DIR/commands"/*.md; do
    cmd_name=$(basename "$cmd_file")
    remove_symlink "$CLAUDE_DIR/commands/$cmd_name" "commands/$cmd_name"
done

echo -e "\n${G}${B}✔ Uninstalled $removed symlinks.${X}"
echo -e "  ${Y}~/.claude/CLAUDE.md and settings.json untouched.${X}\n"
