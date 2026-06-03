#!/bin/bash
# Org Claude Config — Install Script
# Symlinks skills, agents, commands into ~/.claude/
# Optionally installs git hooks into current repo
#
# Usage:
#   ./install.sh           # Claude config only (~/.claude/)
#   ./install.sh --git     # git hooks only (current repo)
#   ./install.sh --all     # both

set -e

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
B='\033[1m'
X='\033[0m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
MODE="${1:-}"

echo -e "\n${B}${C}╔══════════════════════════════════════════╗${X}"
echo -e "${B}${C}║       ORG CLAUDE CONFIG INSTALLER        ║${X}"
echo -e "${B}${C}╚══════════════════════════════════════════╝${X}\n"

install_claude() {
    echo -e "${B}${C}── Claude Config (~/.claude/) ──────────────${X}\n"

    mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/commands"

    # Skills — symlink each skill directory
    echo -e "  ${B}Skills:${X}"
    for skill_dir in "$REPO_DIR/skills"/*/; do
        skill_name=$(basename "$skill_dir")
        target="$CLAUDE_DIR/skills/$skill_name"
        if [ -L "$target" ]; then
            rm "$target"
        elif [ -d "$target" ]; then
            echo -e "  ${Y}⚠ skills/$skill_name exists (not symlink) — skipping${X}"
            continue
        fi
        ln -sf "$skill_dir" "$target"
        echo -e "  ${G}✔${X} skills/$skill_name"
    done

    # Agents — symlink each agent file
    echo -e "\n  ${B}Agents:${X}"
    for agent_file in "$REPO_DIR/agents"/*.md; do
        agent_name=$(basename "$agent_file")
        target="$CLAUDE_DIR/agents/$agent_name"
        if [ -L "$target" ]; then rm "$target"; fi
        ln -sf "$agent_file" "$target"
        echo -e "  ${G}✔${X} agents/$agent_name"
    done

    # Commands — symlink each command file
    echo -e "\n  ${B}Commands:${X}"
    for cmd_file in "$REPO_DIR/commands"/*.md; do
        cmd_name=$(basename "$cmd_file")
        target="$CLAUDE_DIR/commands/$cmd_name"
        if [ -L "$target" ]; then rm "$target"; fi
        ln -sf "$cmd_file" "$target"
        echo -e "  ${G}✔${X} commands/$cmd_name"
    done

    # CLAUDE.md — only if not already present (don't overwrite personal config)
    echo -e "\n  ${B}CLAUDE.md:${X}"
    if [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
        cp "$REPO_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
        echo -e "  ${G}✔${X} CLAUDE.md copied"
    else
        echo -e "  ${Y}⚠${X} ~/.claude/CLAUDE.md already exists — not overwriting"
        echo -e "     Manually merge from: $REPO_DIR/CLAUDE.md"
    fi

    # settings.json — merge hooks only if file exists
    echo -e "\n  ${B}settings.json:${X}"
    if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
        cp "$REPO_DIR/settings.json" "$CLAUDE_DIR/settings.json"
        echo -e "  ${G}✔${X} settings.json copied"
    else
        echo -e "  ${Y}⚠${X} ~/.claude/settings.json already exists — not overwriting"
        echo -e "     Manually merge hooks from: $REPO_DIR/settings.json"
    fi

    echo -e "\n${G}${B}✔ Claude config installed.${X}"
    echo -e "  Update anytime: ${C}cd $REPO_DIR && git pull${X}"
    echo -e "  (Symlinks auto-reflect new skills/agents on pull)\n"
}

install_git_hooks() {
    echo -e "${B}${C}── Git Hooks (.git/hooks/) ──────────────────${X}\n"
    bash "$REPO_DIR/scripts/install-git-hooks.sh"
}

case "$MODE" in
    --git)
        install_git_hooks
        ;;
    --all)
        install_claude
        install_git_hooks
        ;;
    *)
        install_claude
        ;;
esac
