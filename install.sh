#!/bin/bash
# Org Claude Config — Install Script
# Usage: ./install.sh

set -e

G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
B='\033[1m'
X='\033[0m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
GIT_HOOKS_DIR="$HOME/.git-hooks"

symlink_dir() {
    local src_dir="$1" dest_dir="$2" label="$3"
    echo -e "\n  ${B}${label}:${X}"
    for item in "$src_dir"/*/; do
        [ -e "$item" ] || continue
        name=$(basename "$item")
        target="$dest_dir/$name"
        if [ -L "$target" ]; then rm "$target"
        elif [ -e "$target" ]; then echo -e "  ${Y}⚠ $label/$name exists — skipping${X}"; continue; fi
        ln -sf "$item" "$target"
        echo -e "  ${G}✔${X} $label/$name"
    done
}

symlink_files() {
    local src_dir="$1" dest_dir="$2" label="$3" pattern="$4"
    echo -e "\n  ${B}${label}:${X}"
    for f in "$src_dir"/$pattern; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        target="$dest_dir/$name"
        if [ -L "$target" ]; then
            rm "$target"
        elif [ -e "$target" ]; then
            read -r -p "  ${Y}⚠${X} $label/$name exists. Overwrite? [y/N] " _reply < /dev/tty || true
            case "${_reply:-N}" in
                [yY]) rm "$target" ;;
                *) echo -e "  ${Y}skip${X} $label/$name — not modified"; continue ;;
            esac
        fi
        ln -sf "$f" "$target"
        echo -e "  ${G}✔${X} $label/$name"
    done
}

force_symlink() {
    local src="$1" target="$2" label="$3"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -e "$target" ]; then
        read -r -p "  ${Y}⚠${X} $label already exists. Overwrite? [y/N] " reply < /dev/tty || true
        case "${reply:-N}" in   
            [yY]) mv "$target" "${target}.bak"
                  echo -e "  ${Y}↩${X} backed up existing → ${label}.bak" ;;
            *) echo -e "  ${Y}skip${X} $label — not modified"; return ;;
        esac
    fi
    ln -sf "$src" "$target"
    echo -e "  ${G}✔${X} symlinked $label"
}

print_deps() {
    echo -e "${B}${C}── Dependencies (install manually if missing) ──${X}\n"
    echo -e "  caveman        curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash"
    echo -e "  uvx (uv)       win:  irm https://astral.sh/uv/install.ps1 | iex"
    echo -e "                 unix: curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo -e "  code-review-graph  pip install code-review-graph\n"
}

install_claude() {
    echo -e "${B}${C}── Claude Config (~/.claude/) ──────────────${X}"
    mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/standards"

    symlink_dir   "$REPO_DIR/skills"     "$CLAUDE_DIR/skills"     "skills"
    symlink_files "$REPO_DIR/agents"     "$CLAUDE_DIR/agents"     "agents"    "*.md"
    symlink_files "$REPO_DIR/commands"   "$CLAUDE_DIR/commands"   "commands"  "*.md"
    symlink_files "$REPO_DIR/standards"  "$CLAUDE_DIR/standards"  "standards" "*.md"

    echo -e "\n  ${B}CLAUDE.md:${X}"
    force_symlink "$REPO_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md" "CLAUDE.md"

    echo -e "\n  ${B}settings.json:${X}"
    force_symlink "$REPO_DIR/settings.json" "$CLAUDE_DIR/settings.json" "settings.json"

    echo -e "\n${G}${B}✔ Claude config installed.${X} (git pull auto-reflects via symlinks)\n"
}

install_git_hooks() {
    echo -e "${B}${C}── Git Hooks (~/.git-hooks/) ────────────────${X}\n"

    mkdir -p "$GIT_HOOKS_DIR"
    git config --global core.hooksPath "$GIT_HOOKS_DIR"

    for hook in pre-push pr-review.sh; do
        src="$REPO_DIR/skills/git-hooks/$hook"
        target="$GIT_HOOKS_DIR/$hook"
        if [ ! -f "$src" ]; then
            echo -e "  ${Y}⚠${X} skills/git-hooks/$hook not found — skipping"
            continue
        fi
        [ -L "$target" ] && rm "$target"
        ln -sf "$src" "$target"
        chmod +x "$src"
        echo -e "  ${G}✔${X} $hook"
    done

    echo -e "\n${G}${B}✔ Git hooks active globally.${X} (all repos pick up via core.hooksPath)\n"
}

print_deps
install_claude
install_git_hooks
